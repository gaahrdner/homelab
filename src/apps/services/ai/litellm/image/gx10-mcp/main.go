package main

import (
	"bytes"
	"context"
	"encoding/json/v2"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

type config struct {
	ListenAddr     string
	LayaURL        string
	LiteLLMURL     string
	LiteLLMAPIKey  string
	ImageModel     string
	GX10ControlURL string
}

func loadConfig() config {
	return config{
		ListenAddr:     envOr("LISTEN_ADDR", ":8080"),
		LayaURL:        strings.TrimRight(envOr("LAYA_URL", "http://freki.internal:8092"), "/"),
		LiteLLMURL:     strings.TrimRight(envOr("LITELLM_URL", "http://litellm.litellm.svc.cluster.local:4000/v1"), "/"),
		LiteLLMAPIKey:  os.Getenv("LITELLM_API_KEY"),
		ImageModel:     envOr("IMAGE_MODEL", "gx10-image"),
		GX10ControlURL: strings.TrimRight(envOr("GX10_CONTROL_URL", "http://freki.internal:8080"), "/"),
	}
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

type metrics struct {
	mu        sync.Mutex
	calls     map[string]uint64
	durations map[string]float64
}

func newMetrics() *metrics {
	return &metrics{
		calls:     make(map[string]uint64),
		durations: make(map[string]float64),
	}
}

func (m *metrics) observe(tool, status string, d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.calls[tool+"\x00"+status]++
	m.durations[tool] += d.Seconds()
}

func (m *metrics) serveHTTP(w http.ResponseWriter, _ *http.Request) {
	m.mu.Lock()
	defer m.mu.Unlock()
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	fmt.Fprintln(w, "# HELP gx10_mcp_tool_calls_total Total MCP tool invocations.")
	fmt.Fprintln(w, "# TYPE gx10_mcp_tool_calls_total counter")
	for k, v := range m.calls {
		parts := strings.SplitN(k, "\x00", 2)
		fmt.Fprintf(w, "gx10_mcp_tool_calls_total{tool=%q,status=%q} %d\n", parts[0], parts[1], v)
	}
	fmt.Fprintln(w, "# HELP gx10_mcp_tool_duration_seconds_sum Cumulative MCP tool execution duration in seconds.")
	fmt.Fprintln(w, "# TYPE gx10_mcp_tool_duration_seconds_sum counter")
	for tool, sum := range m.durations {
		fmt.Fprintf(w, "gx10_mcp_tool_duration_seconds_sum{tool=%q} %.6f\n", tool, sum)
	}
}

// --- Tool input schemas ---

type LayaQuestion struct {
	Type         string `json:"type" jsonschema:"Question type: 'choice' (pick one label), 'score' (ordered scale), or 'noul' (boolean/presence)"`
	Instructions string `json:"instructions" jsonschema:"The question text Laya should answer based on the state"`
	Criteria     any    `json:"criteria,omitzero" jsonschema:"For 'choice': list of label strings or map of label->description. For 'score': list of ordered level descriptions starting at index 0."`
}

type LayaPredictInput struct {
	State     string                  `json:"state" jsonschema:"Context or text for the Laya System 1 classifier to evaluate"`
	Questions map[string]LayaQuestion `json:"questions" jsonschema:"Map of question names to typed Laya question definitions"`
}

type GenerateImageInput struct {
	Prompt            string `json:"prompt" jsonschema:"Detailed text description of the image to generate"`
	NegativePrompt    string `json:"negative_prompt,omitzero" jsonschema:"Optional elements to avoid in the generated image"`
	Size              string `json:"size,omitzero" jsonschema:"Image dimensions in WxH format (e.g. 1024x1024, 768x768, 512x512). Defaults to 1024x1024."`
	NumInferenceSteps int    `json:"num_inference_steps,omitzero" jsonschema:"Number of diffusion steps (defaults to 8 for Qwen-Image-2.1-Turbo)"`
	Seed              *int   `json:"seed,omitzero" jsonschema:"Optional deterministic RNG seed"`
}

type GX10StatusInput struct{}

type imageGenRequest struct {
	Model             string `json:"model"`
	Prompt            string `json:"prompt"`
	NegativePrompt    string `json:"negative_prompt,omitzero"`
	N                 int    `json:"n"`
	Size              string `json:"size"`
	ResponseFormat    string `json:"response_format"`
	NumInferenceSteps int    `json:"num_inference_steps,omitzero"`
	Seed              *int   `json:"seed,omitzero"`
}

type imageGenResponse struct {
	Data []struct {
		B64JSON []byte `json:"b64_json"`
	} `json:"data"`
}

type gx10CompactStatus struct {
	ActivePreset any `json:"active_preset"`
	Nodes        any `json:"nodes"`
	Sidecars     any `json:"sidecars"`
}

type app struct {
	cfg        config
	fastClient *http.Client
	imgClient  *http.Client
	metrics    *metrics
	logger     *slog.Logger
}

func newApp(cfg config, logger *slog.Logger) *app {
	return &app{
		cfg:        cfg,
		fastClient: &http.Client{Timeout: 15 * time.Second},
		imgClient:  &http.Client{Timeout: 300 * time.Second},
		metrics:    newMetrics(),
		logger:     logger,
	}
}

func (a *app) newMCPServer() *mcp.Server {
	s := mcp.NewServer(&mcp.Implementation{
		Name:    "gx10-mcp",
		Version: "1.0.0",
	}, nil)

	mcp.AddTool(s, &mcp.Tool{
		Name:        "laya_predict",
		Description: "Run a fast (~10-20ms) System 1 non-autoregressive classification, triage, or scoring decision using Laya (ModernBERT-large) on the GX10 cluster.",
	}, a.handleLayaPredict)

	mcp.AddTool(s, &mcp.Tool{
		Name:        "generate_image",
		Description: "Generate an image with Qwen-Image-2.1-Turbo on the GX10 cluster via LiteLLM (gx10-image). Returns the generated PNG image.",
	}, a.handleGenerateImage)

	mcp.AddTool(s, &mcp.Tool{
		Name:        "gx10_status",
		Description: "Inspect live GX10 inference cluster status: online nodes (freki, geri), loaded models, GPU temperature/power/utilization, memory usage, and sidecar status (image-gen, laya).",
	}, a.handleGX10Status)

	return s
}

func (a *app) handleLayaPredict(ctx context.Context, _ *mcp.CallToolRequest, in LayaPredictInput) (*mcp.CallToolResult, any, error) {
	start := time.Now()
	if strings.TrimSpace(in.State) == "" {
		a.metrics.observe("laya_predict", "invalid", time.Since(start))
		return nil, nil, errors.New("state must not be empty")
	}
	if len(in.Questions) == 0 {
		a.metrics.observe("laya_predict", "invalid", time.Since(start))
		return nil, nil, errors.New("questions must contain at least one question")
	}

	payload, err := json.Marshal(in)
	if err != nil {
		a.metrics.observe("laya_predict", "error", time.Since(start))
		return nil, nil, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.cfg.LayaURL+"/predict", bytes.NewReader(payload))
	if err != nil {
		a.metrics.observe("laya_predict", "error", time.Since(start))
		return nil, nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.fastClient.Do(req)
	if err != nil {
		a.metrics.observe("laya_predict", "error", time.Since(start))
		return nil, nil, fmt.Errorf("call laya: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		a.metrics.observe("laya_predict", "error", time.Since(start))
		return nil, nil, fmt.Errorf("read laya response: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		a.metrics.observe("laya_predict", "error", time.Since(start))
		return nil, nil, fmt.Errorf("laya returned HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	a.metrics.observe("laya_predict", "ok", time.Since(start))
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: string(body)},
		},
	}, nil, nil
}

func (a *app) handleGenerateImage(ctx context.Context, _ *mcp.CallToolRequest, in GenerateImageInput) (*mcp.CallToolResult, any, error) {
	start := time.Now()
	if strings.TrimSpace(in.Prompt) == "" {
		a.metrics.observe("generate_image", "invalid", time.Since(start))
		return nil, nil, errors.New("prompt must not be empty")
	}

	size := strings.TrimSpace(in.Size)
	if size == "" {
		size = "1024x1024"
	}

	payload, err := json.Marshal(imageGenRequest{
		Model:             a.cfg.ImageModel,
		Prompt:            in.Prompt,
		NegativePrompt:    in.NegativePrompt,
		N:                 1,
		Size:              size,
		ResponseFormat:    "b64_json",
		NumInferenceSteps: in.NumInferenceSteps,
		Seed:              in.Seed,
	})
	if err != nil {
		a.metrics.observe("generate_image", "error", time.Since(start))
		return nil, nil, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.cfg.LiteLLMURL+"/images/generations", bytes.NewReader(payload))
	if err != nil {
		a.metrics.observe("generate_image", "error", time.Since(start))
		return nil, nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if a.cfg.LiteLLMAPIKey != "" {
		req.Header.Set("Authorization", "Bearer "+a.cfg.LiteLLMAPIKey)
	}

	resp, err := a.imgClient.Do(req)
	if err != nil {
		a.metrics.observe("generate_image", "error", time.Since(start))
		return nil, nil, fmt.Errorf("call litellm image generation: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		errBody, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		a.metrics.observe("generate_image", "error", time.Since(start))
		return nil, nil, fmt.Errorf("image generation returned HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(errBody)))
	}

	var parsed imageGenResponse
	if err := json.UnmarshalRead(io.LimitReader(resp.Body, 25<<20), &parsed); err != nil {
		a.metrics.observe("generate_image", "error", time.Since(start))
		return nil, nil, fmt.Errorf("decode image response: %w", err)
	}
	if len(parsed.Data) == 0 || len(parsed.Data[0].B64JSON) == 0 {
		a.metrics.observe("generate_image", "error", time.Since(start))
		return nil, nil, errors.New("image generation returned no image data")
	}

	pngBytes := parsed.Data[0].B64JSON
	elapsed := time.Since(start)
	a.metrics.observe("generate_image", "ok", elapsed)
	summary := fmt.Sprintf("Generated %s PNG image via %s (%d bytes in %.1fs).", size, a.cfg.ImageModel, len(pngBytes), elapsed.Seconds())
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: summary},
			&mcp.ImageContent{
				Data:     pngBytes,
				MIMEType: "image/png",
			},
		},
	}, nil, nil
}

func (a *app) handleGX10Status(ctx context.Context, _ *mcp.CallToolRequest, _ GX10StatusInput) (*mcp.CallToolResult, any, error) {
	start := time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.cfg.GX10ControlURL+"/api/status", nil)
	if err != nil {
		a.metrics.observe("gx10_status", "error", time.Since(start))
		return nil, nil, fmt.Errorf("build request: %w", err)
	}

	resp, err := a.fastClient.Do(req)
	if err != nil {
		a.metrics.observe("gx10_status", "error", time.Since(start))
		return nil, nil, fmt.Errorf("call gx10 control plane: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		errBody, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		a.metrics.observe("gx10_status", "error", time.Since(start))
		return nil, nil, fmt.Errorf("gx10 control returned HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(errBody)))
	}

	// Stream-decode only the high-signal fields, skipping bulky preset/log payloads.
	var compact gx10CompactStatus
	if err := json.UnmarshalRead(io.LimitReader(resp.Body, 2<<20), &compact); err != nil {
		a.metrics.observe("gx10_status", "error", time.Since(start))
		return nil, nil, fmt.Errorf("decode gx10 status: %w", err)
	}
	out, err := json.Marshal(compact)
	if err != nil {
		a.metrics.observe("gx10_status", "error", time.Since(start))
		return nil, nil, fmt.Errorf("marshal gx10 status: %w", err)
	}

	a.metrics.observe("gx10_status", "ok", time.Since(start))
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: string(out)},
		},
	}, nil, nil
}

func (a *app) routes() http.Handler {
	mcpServer := a.newMCPServer()
	mcpHandler := mcp.NewStreamableHTTPHandler(func(*http.Request) *mcp.Server {
		return mcpServer
	}, &mcp.StreamableHTTPOptions{
		JSONResponse:   true,
		SessionTimeout: 15 * time.Minute,
		Logger:         a.logger,
	})

	mux := http.NewServeMux()
	mux.Handle("/mcp", mcpHandler)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	mux.HandleFunc("/metrics", a.metrics.serveHTTP)
	return mux
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	cfg := loadConfig()
	a := newApp(cfg, logger)

	srv := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           a.routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("gx10-mcp listening", "addr", cfg.ListenAddr, "laya", cfg.LayaURL, "litellm", cfg.LiteLLMURL, "control", cfg.GX10ControlURL)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server failed", "err", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}
