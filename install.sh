#!/usr/bin/env bash
set -euo pipefail

############################
# CONFIG (МЕНЯЙ ТУТ)
############################
MONIKER="test"

# ВАЖНО: это ИМЯ сети для init, НЕ chain-id
STORY_NETWORK="story"     # mainnet: story | testnet: aeneid

# Префикс портов, чтобы не конфликтовать с Celestia (у тебя 26656/26657 заняты)
# Пример: 45 => 45656/45657/45658 и т.д.
PORT_PREFIX="45"

# Версии
GO_VERSION="1.22.5"
STORY_VERSION="v1.4.1"
GETH_VERSION="v1.1.2"

############################
# PATHS
############################
HOME_DIR="$HOME"
STORY_HOME="$HOME_DIR/.story"
BIN_DIR="$HOME_DIR/go/bin"

STORY_SRC_DIR="$HOME_DIR/story"
GETH_SRC_DIR="$HOME_DIR/story-geth"

STORY_BIN="$BIN_DIR/story"
GETH_BIN="$BIN_DIR/geth"

# CometBFT/Story порты (из префикса)
P2P_PORT="${PORT_PREFIX}656"   # p2p: 45656
RPC_PORT="${PORT_PREFIX}657"   # rpc: 45657
ABCI_PORT="${PORT_PREFIX}658"  # abci/socket: 45658
P2P_PP_PORT="${PORT_PREFIX}660" # pprof/metrics etc: 45660 (если используется)

# Story API/Engine порты
API_PORT="${PORT_PREFIX}317"   # api: 45317
ENGINE_AUTH_PORT="${PORT_PREFIX}551" # authrpc: 45551
GETH_HTTP_PORT="${PORT_PREFIX}545"   # http: 45545
GETH_WS_PORT="${PORT_PREFIX}546"     # ws:   45546
GETH_P2P_PORT="${PORT_PREFIX}303"    # geth p2p: 45303

############################
# SNAPSHOTS (ОПЦИОНАЛЬНО)
############################
STORY_SNAP_URL="https://server-2.itrocket.net/mainnet/story/story_2025-12-12_11812794_snap.tar.lz4"
GETH_SNAP_URL="https://server-2.itrocket.net/mainnet/story/geth_story_2025-12-12_11812794_snap.tar.lz4"

############################
# HELPERS
############################
log() { echo -e "\n== $* =="; }

############################
# 0) Остановить/удалить старое
############################
log "Stopping old services (if any) + removing old unit files"
sudo systemctl stop story story-geth geth 2>/dev/null || true
sudo systemctl disable story story-geth geth 2>/dev/null || true

sudo rm -f /etc/systemd/system/story.service
sudo rm -f /etc/systemd/system/story-geth.service
sudo rm -f /etc/systemd/system/geth.service

sudo systemctl daemon-reload
sudo systemctl reset-failed

log "Removing old Story directories and source trees"
rm -rf "$STORY_HOME"
rm -rf "$STORY_SRC_DIR" "$GETH_SRC_DIR"

mkdir -p "$BIN_DIR"

############################
# 1) Зависимости
############################
log "Installing system dependencies"
sudo apt update
sudo apt install -y \
  git curl wget jq build-essential make gcc \
  chrony lz4 tmux unzip bc

############################
# 2) Go (ставим нужную версию, если отличается)
############################
log "Checking Go installation"
need_go="1"
if command -v go >/dev/null 2>&1; then
  if go version | grep -q "go${GO_VERSION}"; then
    need_go="0"
  fi
fi

if [ "$need_go" = "1" ]; then
  log "Installing Go ${GO_VERSION}"
  sudo rm -rf /usr/local/go
  curl -L "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" | sudo tar -C /usr/local -xz
fi

export PATH="/usr/local/go/bin:$HOME_DIR/go/bin:$PATH"
go version

############################
# 3) story-geth: СБОРКА ИЗ ИСХОДНИКОВ (glibc-safe)
############################
log "Building story-geth from source (${GETH_VERSION})"
cd "$HOME_DIR"
git clone https://github.com/piplabs/story-geth
cd "$GETH_SRC_DIR"
git checkout "$GETH_VERSION"

# сборка geth (как у тебя уже отработало)
go run build/ci.go install ./cmd/geth

cp build/bin/geth "$GETH_BIN"
chmod +x "$GETH_BIN"

"$GETH_BIN" version

############################
# 4) story: СБОРКА ИЗ ИСХОДНИКОВ (glibc-safe)
############################
log "Building story from source (${STORY_VERSION})"
cd "$HOME_DIR"
git clone https://github.com/piplabs/story
cd "$STORY_SRC_DIR"
git checkout "$STORY_VERSION"

go build -o story ./client
cp story "$STORY_BIN"
chmod +x "$STORY_BIN"

"$STORY_BIN" version

############################
# 5) Init (ВАЖНО: network=story, НЕ story-1)
############################
log "Initializing Story (network=${STORY_NETWORK}, moniker=${MONIKER})"
"$STORY_BIN" init --moniker "$MONIKER" --network "$STORY_NETWORK"

############################
# 6) Правки config.toml + story.toml (на всякий случай)
############################
log "Configuring ports in config.toml + story.toml"
CFG="$STORY_HOME/story/config/config.toml"
STORY_TOML="$STORY_HOME/story/config/story.toml"

# CometBFT порты (могут не примениться полностью — мы ещё закрепим flags в systemd)
sed -i.bak \
  -e "s/:26656/:${P2P_PORT}/g" \
  -e "s/:26657/:${RPC_PORT}/g" \
  -e "s/:26658/:${ABCI_PORT}/g" \
  -e "s/:26660/:${P2P_PP_PORT}/g" \
  "$CFG" || true

# Story api/engine порты в story.toml
sed -i.bak \
  -e "s/:1317/:${API_PORT}/g" \
  -e "s/:8551/:${ENGINE_AUTH_PORT}/g" \
  "$STORY_TOML" || true

# prometheus on + indexer off
sed -i \
  -e 's/prometheus = false/prometheus = true/' \
  -e 's/^indexer *=.*/indexer = "null"/' \
  "$CFG" || true

############################
# 7) systemd units (АБСОЛЮТНЫЕ ПУТИ + ЖЁСТКО ЗАДАННЫЕ ПОРТЫ ЧЕРЕЗ FLAGS)
############################
log "Creating systemd unit: story-geth.service"
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth
After=network-online.target

[Service]
User=root
ExecStart=${GETH_BIN} --story --syncmode full \\
  --http --http.api eth,net,web3,engine \\
  --http.addr 0.0.0.0 --http.port ${GETH_HTTP_PORT} \\
  --authrpc.port ${ENGINE_AUTH_PORT} \\
  --ws --ws.api eth,web3,net,txpool \\
  --ws.addr 0.0.0.0 --ws.port ${GETH_WS_PORT} \\
  --port ${GETH_P2P_PORT}
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

log "Creating systemd unit: story.service (фиксируем порты, чтобы НЕ лез на 26657)"
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Node
After=network-online.target story-geth.service

[Service]
User=root
WorkingDirectory=${STORY_HOME}/story
ExecStart=${STORY_BIN} run \\
  --rpc.laddr tcp://127.0.0.1:${ABCI_PORT} \\
  --p2p.laddr tcp://0.0.0.0:${P2P_PORT} \\
  --proxy-app tcp://127.0.0.1:${ABCI_PORT} \\
  --api.address tcp://127.0.0.1:${API_PORT} \\
  --engine-endpoint http://127.0.0.1:${ENGINE_AUTH_PORT} \\
  --engine-jwt-file ${STORY_HOME}/geth/story/geth/jwtsecret
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

############################
# 8) Snapshot restore (по твоему гайду, но с путями под story/geth)
############################
log "Restoring snapshots (Story + Geth)"

sudo systemctl stop story story-geth 2>/dev/null || true

# backup priv_validator_state.json
if [ -f "${STORY_HOME}/story/data/priv_validator_state.json" ]; then
  cp "${STORY_HOME}/story/data/priv_validator_state.json" \
     "${STORY_HOME}/story/priv_validator_state.json.backup"
fi

# Story snapshot
rm -rf "${STORY_HOME}/story/data"
curl -L "${STORY_SNAP_URL}" | lz4 -dc | tar -xf - -C "${STORY_HOME}/story"

# restore priv_validator_state.json
if [ -f "${STORY_HOME}/story/priv_validator_state.json.backup" ]; then
  mv "${STORY_HOME}/story/priv_validator_state.json.backup" \
     "${STORY_HOME}/story/data/priv_validator_state.json" || true
fi

# Geth snapshot (создаём директорию заранее, чтобы не повторить твою ошибку "Cannot open: No such file or directory")
mkdir -p "${STORY_HOME}/geth/story/geth"
rm -rf "${STORY_HOME}/geth/story/geth/chaindata"
curl -L "${GETH_SNAP_URL}" | lz4 -dc | tar -xf - -C "${STORY_HOME}/geth/story/geth"

############################
# 9) Start services
############################
log "Enabling and starting services"
sudo systemctl enable story-geth story

sudo systemctl restart story-geth
sleep 5
sudo systemctl restart story

log "Ports check (должны быть 45xxx, а 26657 занята Celestia)"
sudo ss -ltnp | egrep ":${P2P_PORT}|:${RPC_PORT}|:${ABCI_PORT}|:${API_PORT}|:${GETH_HTTP_PORT}|:${ENGINE_AUTH_PORT}|:${GETH_WS_PORT}" || true

log "Done. Logs:"
echo "journalctl -u story-geth -f"
echo "journalctl -u story -f"
