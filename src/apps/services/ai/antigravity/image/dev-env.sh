# Shared shell environment for bash and zsh (login and non-login)
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export EDITOR=vim
export GOPATH="${HOME}/go"
export GOCACHE="${HOME}/.cache/go-build"
export RUSTUP_HOME="/usr/local/rustup"
export CARGO_HOME="${HOME}/.cargo"
export UV_CACHE_DIR="${HOME}/.cache/uv"

case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) ;;
  *) PATH="${HOME}/.local/bin:${PATH}" ;;
esac
case ":${PATH}:" in
  *":${GOPATH}/bin:"*) ;;
  *) PATH="${GOPATH}/bin:${PATH}" ;;
esac
case ":${PATH}:" in
  *":${CARGO_HOME}/bin:"*) ;;
  *) PATH="${CARGO_HOME}/bin:${PATH}" ;;
esac
case ":${PATH}:" in
  *":/usr/local/go/bin:"*) ;;
  *) PATH="/usr/local/go/bin:${PATH}" ;;
esac
case ":${PATH}:" in
  *":/usr/local/cargo/bin:"*) ;;
  *) PATH="/usr/local/cargo/bin:${PATH}" ;;
esac

export PATH
