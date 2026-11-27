FROM debian:trixie-slim

ARG GO_VERSION=1.27.4
ARG KUBECTL_VERSION=v1.36.6
ARG HELM_VERSION=v4.3.2
ARG TALOSCTL_VERSION=v1.14.6
ARG YQ_VERSION=v4.54.3
ARG GH_VERSION=2.106.0
ARG UV_VERSION=0.13.10
ARG MISE_VERSION=v2026.11.14

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/go/bin:/usr/local/cargo/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      clang \
      cmake \
      curl \
      dnsutils \
      fd-find \
      fzf \
      git \
      git-lfs \
      gnupg \
      htop \
      iputils-ping \
      jq \
      less \
      libffi-dev \
      libsqlite3-dev \
      libssl-dev \
      lld \
      locales \
      nano \
      netcat-openbsd \
      openssh-client \
      openssh-server \
      pkg-config \
      procps \
      protobuf-compiler \
      python3 \
      python3-dev \
      python3-pip \
      python3-venv \
      ripgrep \
      rsync \
      sqlite3 \
      sudo \
      tar \
      tmux \
      unzip \
      vim \
      wget \
      xz-utils \
      zip \
      zlib1g-dev \
      zsh \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Create non-root dev user (unlocked for pubkey-only SSH with UsePAM no)
RUN groupadd -g 1000 dev \
    && useradd -m -u 1000 -g 1000 -s /bin/zsh dev \
    && usermod -p '*' dev \
    && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev \
    && mkdir -p /run/sshd /etc/ssh/authorized_keys \
    && chmod 0755 /run/sshd /etc/ssh/authorized_keys \
    && rm -f /etc/ssh/ssh_host_*

# Go
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xzf - \
    && go version

# Rust (stable toolchain + rustfmt, clippy, rust-analyzer, rust-src)
RUN curl -fsSL https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile default --default-toolchain stable \
      -c rustfmt -c clippy -c rust-analyzer -c rust-src \
    && chown -R dev:dev /usr/local/rustup /usr/local/cargo \
    && rustc --version && cargo --version

# uv (Python package & virtualenv manager)
RUN curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -C /tmp -xzf - \
    && install -m 0755 /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv \
    && install -m 0755 /tmp/uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/uvx \
    && rm -rf /tmp/uv-x86_64-unknown-linux-gnu \
    && uv --version

# mise (polyglot tool & task runner)
RUN curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-x64.tar.xz" \
    | tar -C /tmp -xJf - \
    && install -m 0755 /tmp/mise/bin/mise /usr/local/bin/mise \
    && rm -rf /tmp/mise \
    && mise --version

# Cluster & Git CLIs: kubectl, helm, talosctl, yq, gh
RUN curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod 0755 /usr/local/bin/kubectl \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
      | tar -C /tmp -xzf - \
    && install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64 \
    && curl -fsSL -o /usr/local/bin/talosctl "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-amd64" \
    && chmod 0755 /usr/local/bin/talosctl \
    && curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    && chmod 0755 /usr/local/bin/yq \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
      | tar -C /tmp -xzf - \
    && install -m 0755 "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
    && rm -rf "/tmp/gh_${GH_VERSION}_linux_amd64"

# Antigravity CLI (agy) — owned by dev so `agy update` works without sudo
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin \
    && chown dev:dev /usr/local/bin/agy \
    && /usr/local/bin/agy --version

COPY sshd_config /etc/ssh/sshd_config.d/99-antigravity.conf
COPY dev-env.sh /etc/profile.d/dev-env.sh
COPY agy-remote /usr/local/bin/agy-remote
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0644 /etc/ssh/sshd_config.d/99-antigravity.conf /etc/profile.d/dev-env.sh \
    && chmod 0755 /usr/local/bin/agy-remote /usr/local/bin/entrypoint.sh \
    && echo 'source /etc/profile.d/dev-env.sh' >> /etc/zsh/zshenv \
    && echo 'source /etc/profile.d/dev-env.sh' >> /etc/bash.bashrc

# Verify toolchains work as non-root dev user
RUN su - dev -c 'go version && rustc --version && cargo --version && rustfmt --version && cargo clippy --version && rust-analyzer --version && python3 --version && uv --version && mise --version && agy --version'

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
