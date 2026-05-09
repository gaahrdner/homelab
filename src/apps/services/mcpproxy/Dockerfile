FROM alpine:3.23 AS fetch

ARG MCPPROXY_VERSION=v0.29.3

RUN apk add --no-cache ca-certificates tar wget

WORKDIR /out

RUN wget -O mcpproxy.tgz \
    https://github.com/smart-mcp-proxy/mcpproxy-go/releases/download/${MCPPROXY_VERSION}/mcpproxy-${MCPPROXY_VERSION#v}-linux-amd64.tar.gz \
    && tar -xzf mcpproxy.tgz \
    && chmod 0755 /out/mcpproxy

FROM alpine:3.23

RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -g 65532 nonroot \
    && adduser -D -H -u 65532 -G nonroot nonroot \
    && mkdir -p /data /tmp /config \
    && chown -R 65532:65532 /data /tmp /config

COPY --from=fetch /out/mcpproxy /usr/local/bin/mcpproxy

LABEL org.opencontainers.image.source="https://github.com/gaahrdner/homelab"
LABEL org.opencontainers.image.description="Hermetic MCPProxy runtime image for the norns homelab cluster"

USER 65532:65532

ENTRYPOINT ["/usr/local/bin/mcpproxy"]
