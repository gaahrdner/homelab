package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

func TestMCPToolsEndToEnd(t *testing.T) {
	fakePNG := []byte("\x89PNG\r\n\x1a\nfake-png-bytes")

	layaSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/predict" || r.Method != http.MethodPost {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"model":"laya-rl-agent","answers":{"intent":{"type":"choice","choice":"deploy","confidence":0.99}}}`))
	}))
	defer layaSrv.Close()

	litellmSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/images/generations" || r.Method != http.MethodPost {
			http.NotFound(w, r)
			return
		}
		if r.Header.Get("Authorization") != "Bearer test-key" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		resp := map[string]any{
			"created": 123456,
			"data": []map[string]string{
				{"b64_json": base64.StdEncoding.EncodeToString(fakePNG)},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer litellmSrv.Close()

	ctrlSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/status" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"active_preset":"split-default","nodes":{"freki":{"online":true}},"sidecars":{"laya":{"service_active":true}},"presets":{"huge":"omitted"}}`))
	}))
	defer ctrlSrv.Close()

	a := newApp(config{
		LayaURL:        layaSrv.URL,
		LiteLLMURL:     litellmSrv.URL + "/v1",
		LiteLLMAPIKey:  "test-key",
		ImageModel:     "gx10-image",
		GX10ControlURL: ctrlSrv.URL,
	}, slog.New(slog.NewTextHandler(io.Discard, nil)))

	mcpSrv := httptest.NewServer(a.routes())
	defer mcpSrv.Close()

	// Check /healthz
	hr, err := http.Get(mcpSrv.URL + "/healthz")
	if err != nil || hr.StatusCode != http.StatusOK {
		t.Fatalf("healthz failed: err=%v resp=%v", err, hr)
	}
	hr.Body.Close()

	// Connect with official MCP Streamable HTTP client
	ctx := context.Background()
	client := mcp.NewClient(&mcp.Implementation{Name: "test-client", Version: "1.0.0"}, nil)
	session, err := client.Connect(ctx, &mcp.StreamableClientTransport{Endpoint: mcpSrv.URL + "/mcp"}, nil)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer session.Close()

	toolsResp, err := session.ListTools(ctx, nil)
	if err != nil {
		t.Fatalf("list tools: %v", err)
	}
	if len(toolsResp.Tools) != 3 {
		t.Fatalf("expected 3 tools, got %d", len(toolsResp.Tools))
	}

	// Test laya_predict
	layaRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name: "laya_predict",
		Arguments: map[string]any{
			"state": "deploy now",
			"questions": map[string]any{
				"intent": map[string]any{
					"type":         "choice",
					"instructions": "What is the intent?",
					"criteria":     []string{"deploy", "chat"},
				},
			},
		},
	})
	if err != nil || layaRes.IsError {
		t.Fatalf("laya_predict failed: err=%v res=%+v", err, layaRes)
	}
	if tc, ok := layaRes.Content[0].(*mcp.TextContent); !ok || !strings.Contains(tc.Text, `"choice":"deploy"`) {
		t.Fatalf("unexpected laya content: %+v", layaRes.Content)
	}

	// Test generate_image
	imgRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name:      "generate_image",
		Arguments: map[string]any{"prompt": "a tiny homelab rack", "size": "512x512"},
	})
	if err != nil || imgRes.IsError {
		t.Fatalf("generate_image failed: err=%v res=%+v", err, imgRes)
	}
	if len(imgRes.Content) != 2 {
		t.Fatalf("expected 2 content items (text + image), got %d", len(imgRes.Content))
	}
	ic, ok := imgRes.Content[1].(*mcp.ImageContent)
	if !ok || ic.MIMEType != "image/png" || string(ic.Data) != string(fakePNG) {
		t.Fatalf("unexpected image content: %+v", imgRes.Content[1])
	}

	// Test gx10_status
	stRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name:      "gx10_status",
		Arguments: map[string]any{},
	})
	if err != nil || stRes.IsError {
		t.Fatalf("gx10_status failed: err=%v res=%+v", err, stRes)
	}
	if tc, ok := stRes.Content[0].(*mcp.TextContent); !ok || strings.Contains(tc.Text, "omitted") || !strings.Contains(tc.Text, "split-default") {
		t.Fatalf("unexpected status content: %+v", stRes.Content)
	}

	// Check /metrics
	mr, err := http.Get(mcpSrv.URL + "/metrics")
	if err != nil || mr.StatusCode != http.StatusOK {
		t.Fatalf("metrics failed: err=%v resp=%v", err, mr)
	}
	mbody, _ := io.ReadAll(mr.Body)
	mr.Body.Close()
	if !strings.Contains(string(mbody), `gx10_mcp_tool_calls_total{tool="laya_predict",status="ok"} 1`) {
		t.Fatalf("missing laya metric in:\n%s", string(mbody))
	}
}
