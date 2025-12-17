#!/usr/bin/env bash
# YO Network public validator/full-node setup
#
# Usage:
#   MONIKER=my-node ./scripts/setup.sh

set -euo pipefail

CHAIN_ID="evmos_100892-1"
DEFAULT_PERSISTENT_PEER="c24d9aa369bf91e0e26c86d664b2c4fbc90d216f@rpc.yonetwork.io:26656"

EVMOS_VERSION="${EVMOS_VERSION:-v20.0.0}"
MONIKER="${MONIKER:-yo-public-node}"
EVMOS_HOME="${EVMOS_HOME:-/root/.evmosd}"
PERSISTENT_PEERS="${PERSISTENT_PEERS:-$DEFAULT_PERSISTENT_PEER}"
SEEDS="${SEEDS:-}"
MIN_GAS="${MIN_GAS:-0aevmos}"

log() { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$1"; }
log_done() { printf "\033[1;32m[DONE]\033[0m %s\n" "$1"; }
log_err() { printf "\033[1;31m[ERR]\033[0m %s\n" "$1"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_err "Запусти скрипт от root (sudo -i)."
    exit 1
  fi
}

install_packages() {
  log "Устанавливаю зависимости..."
  apt-get update -qq
  apt-get install -y -qq curl wget jq lz4 tar systemd
}

install_evmos() {
  local target_version="${EVMOS_VERSION#v}"
  local installed_version
  installed_version="$(evmosd version 2>/dev/null || true)"

  if [[ "$installed_version" == "$target_version" ]]; then
    log "evmosd ${installed_version} уже установлен."
    return
  fi

  log "Скачиваю evmosd ${EVMOS_VERSION}..."
  local arch_tag
  case "$(uname -m)" in
    x86_64|amd64) arch_tag="amd64" ;;
    arm64|aarch64) arch_tag="arm64" ;;
    *)
      log_err "Неподдерживаемая архитектура: $(uname -m)"
      exit 1
      ;;
  esac

  local url="https://github.com/evmos/evmos/releases/download/${EVMOS_VERSION}/evmos_${target_version}_Linux_${arch_tag}.tar.gz"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  pushd "$tmp_dir" >/dev/null
  wget -q --show-progress "$url" -O evmos.tar.gz
  tar -xzf evmos.tar.gz

  local bin_path
  bin_path="$(find . -name evmosd -type f | head -1)"
  if [[ -z "$bin_path" ]]; then
    log_err "Не удалось найти бинарник evmosd после распаковки."
    exit 1
  fi

  cp "$bin_path" /usr/local/bin/evmosd
  chmod +x /usr/local/bin/evmosd
  popd >/dev/null
  rm -rf "$tmp_dir"

  log_done "Установлен $(evmosd version)"
}

init_home() {
  mkdir -p "$EVMOS_HOME"
  if [[ ! -d "$EVMOS_HOME/config" ]]; then
    log "Инициализирую директорию $EVMOS_HOME..."
    evmosd init "$MONIKER" --chain-id "$CHAIN_ID" --home "$EVMOS_HOME"
  else
    log_warn "Каталог $EVMOS_HOME уже существует, пропускаю init."
  fi
}

configure_files() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local config_toml="$EVMOS_HOME/config/config.toml"
  local app_toml="$EVMOS_HOME/config/app.toml"

  log "Копирую genesis..."
  cp "$script_dir/../config/genesis.json" "$EVMOS_HOME/config/genesis.json"

  log "Обновляю config.toml..."
  sed -i.bak \
    -e "s/^moniker = .*/moniker = \"${MONIKER}\"/" \
    -e "s|^seeds = .*|seeds = \"${SEEDS}\"|" \
    -e "s|^persistent_peers = .*|persistent_peers = \"${PERSISTENT_PEERS}\"|" \
    -e 's|^laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' \
    "$config_toml"

  log "Обновляю app.toml..."
  sed -i.bak \
    -e "s/^minimum-gas-prices = .*/minimum-gas-prices = \"${MIN_GAS}\"/" \
    -e 's/^pruning *=.*/pruning = "nothing"/' \
    -e 's/^pruning-keep-recent *=.*/pruning-keep-recent = "0"/' \
    -e 's/^pruning-interval *=.*/pruning-interval = "0"/' \
    "$app_toml"

  # Включаем публичные API
  sed -i '/\[api\]/,/^\[/ s/^enable = .*/enable = true/' "$app_toml"
  sed -i '/\[api\]/,/^\[/ s|^address = .*|address = "tcp://0.0.0.0:1317"|' "$app_toml"

  sed -i '/\[json-rpc\]/,/^\[/ s/^enable = .*/enable = true/' "$app_toml"
  sed -i '/\[json-rpc\]/,/^\[/ s|^address = .*|address = "0.0.0.0:8545"|' "$app_toml"
  sed -i '/\[json-rpc\]/,/^\[/ s|^ws-address = .*|ws-address = "0.0.0.0:8546"|' "$app_toml"

  sed -i '/\[grpc\]/,/^\[/ s/^enable = .*/enable = true/' "$app_toml"
  sed -i '/\[grpc\]/,/^\[/ s|^address = .*|address = "0.0.0.0:9090"|' "$app_toml"

  rm -f "$config_toml.bak" "$app_toml.bak"
}

install_service() {
  log "Создаю systemd сервис..."
  cat >/etc/systemd/system/evmosd.service <<EOF
[Unit]
Description=YO Network Evmos Node
After=network-online.target
Wants=network-online.target

[Service]
User=root
WorkingDirectory=${EVMOS_HOME}
ExecStart=/usr/local/bin/evmosd start \\
  --home ${EVMOS_HOME} \\
  --json-rpc.enable \\
  --json-rpc.api eth,net,web3,txpool,debug \\
  --json-rpc.address 0.0.0.0:8545 \\
  --json-rpc.ws-address 0.0.0.0:8546 \\
  --api.enable \\
  --api.address tcp://0.0.0.0:1317 \\
  --grpc.enable \\
  --grpc.address 0.0.0.0:9090 \\
  --minimum-gas-prices ${MIN_GAS} \\
  --pruning=nothing
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal
SyslogIdentifier=evmosd

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable evmosd
}

start_service() {
  log "Запускаю evmosd..."
  systemctl restart evmosd
  sleep 3
  systemctl status evmosd --no-pager -l | head -n 15
}

main() {
  require_root
  install_packages
  install_evmos
  init_home
  configure_files
  install_service
  start_service

  log_done "Нода запущена."
  log "Проверяй статус: journalctl -u evmosd -f"
  log "Tendermint RPC: http://$(hostname -I | awk '{print $1}'):26657"
  log "JSON-RPC:      http://$(hostname -I | awk '{print $1}'):8545"
}

main "$@"
