FROM golang:1.26-bookworm AS builder

ENV CGO_ENABLED=0

RUN go install github.com/gastownhall/gascity/cmd/gc@v1.1.0

FROM debian:bookworm-slim

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    git \
    jq \
    lsof \
    openssh-client \
    procps \
    tmux \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home-dir /var/lib/gascity/home --uid 1000 --shell /bin/bash gascity

COPY --from=builder /go/bin/gc /usr/local/bin/gc
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh \
  && mkdir -p /var/lib/gascity/city /var/lib/gascity/home \
  && chown -R 1000:1000 /var/lib/gascity

USER 1000:1000
WORKDIR /var/lib/gascity/city

ENV HOME=/var/lib/gascity/home
ENV GC_BEADS=file

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
