FROM eclipse-temurin:25.0.3_9-jre

ARG SIGNAL_CLI_VERSION=0.14.3

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/signal-cli.tar.gz \
    "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz" \
  && tar -xzf /tmp/signal-cli.tar.gz -C /opt \
  && ln -s "/opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli" /usr/local/bin/signal-cli \
  && rm -f /tmp/signal-cli.tar.gz

RUN useradd --create-home --home-dir /home/signal --uid 10001 --shell /usr/sbin/nologin signal \
  && mkdir -p /var/lib/signal-cli \
  && chown -R 10001:10001 /home/signal /var/lib/signal-cli

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER 10001:10001
WORKDIR /home/signal

ENV HOME=/home/signal
ENV XDG_DATA_HOME=/var/lib/signal-cli

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
