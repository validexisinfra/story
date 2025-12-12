#!/usr/bin/env bash
set -euo pipefail

############################
# CONFIG
############################
MONIKER="test"
STORY_CHAIN_ID="story-1"
STORY_PORT_PREFIX="45"   # чтобы не конфликтовать с Celestia
GO_VERSION="1.22.5"
STORY_VERSION="v1.4.1"
GETH_VERSION="v1.1.2"

STORY_HOME="$HOME/.story"
BIN_DIR="$HOME/go/bin"

STORY_BIN="$BIN_DIR/story"
GETH_BIN="$BIN_DIR/geth"

############################
# PREP
############################
echo "== Story full rebuild installer =="

sudo systemctl stop story story-geth 2>/dev/null || true
sudo systemctl disable story story-geth 2>/dev/null || true

rm -rf "$STORY_HOME"
rm -rf "$HOME/story"
rm -rf "$HOME/story-geth"

mkdir -p "$BIN_DIR"

############################
# SYSTEM DEPS
############################
sudo apt update
sudo apt install -y \
  git curl wget jq build-essential make gcc \
  chrony lz4 tmux unzip bc

############################
# GO
############################
if ! go version 2>/dev/null | grep -q "$GO_VERSION"; then
  echo "Installing Go $GO_VERSION"
  sudo rm -rf /usr/local/go
  curl -L "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | sudo tar -C /usr/local -xz

  if ! grep -q "/usr/local/go/bin" "$HOME/.bash_profile" 2>/dev/null; then
    echo 'export PATH=/usr/local/go/bin:$HOME/go/bin:$PATH' >> "$HOME/.bash_profile"
  fi
fi

export PATH=/usr/local/go/bin:$HOME/go/bin:$PATH
go version

############################
# BUILD story-geth
############################
echo "Building story-geth from source..."
cd "$HOME"
git clone https://github.com/piplabs/story-geth
cd story-geth
git checkout "$GETH_VERSION"

go run build/ci.go install ./cmd/geth
cp build/bin/geth "$GETH_BIN"
chmod +x "$GETH_BIN"

"$GETH_BIN" version

############################
# BUILD story
############################
echo "Building story from source..."
cd "$HOME"
git clone https://github.com/piplabs/story
cd story
git checkout "$STORY_VERSION"

go build -o story ./client
cp story "$STORY_BIN"
chmod +x "$STORY_BIN"

"$STORY_BIN" version

############################
# INIT STORY
############################
"$STORY_BIN" init --moniker "$MONIKER" --network "$STORY_CHAIN_ID"

############################
# CONFIG PORTS
############################
CFG="$STORY_HOME/story/config/config.toml"
STORY_TOML="$STORY_HOME/story/config/story.toml"

sed -i.bak \
  -e "s/:26658/:${STORY_PORT_PREFIX}658/g" \
  -e "s/:26657/:${STORY_PORT_PREFIX}657/g" \
  -e "s/:26656/:${STORY_PORT_PREFIX}656/g" \
  -e "s/:26660/:${STORY_PORT_PREFIX}660/g" \
  "$CFG"

sed -i.bak \
  -e "s/:1317/:${STORY_PORT_PREFIX}317/g" \
  -e "s/:8551/:${STORY_PORT_PREFIX}551/g" \
  "$STORY_TOML"

sed -i \
  -e 's/prometheus = false/prometheus = true/' \
  -e 's/^indexer *=.*/indexer = "null"/' \
  "$CFG"

############################
# SYSTEMD: story-geth
############################
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth
After=network-online.target

[Service]
User=$USER
ExecStart=$GETH_BIN --story --syncmode full \
  --http --http.api eth,net,web3,engine --http.addr 0.0.0.0 --http.port ${STORY_PORT_PREFIX}545 \
  --authrpc.port ${STORY_PORT_PREFIX}551 \
  --ws --ws.api eth,web3,net,txpool --ws.addr 0.0.0.0 --ws.port ${STORY_PORT_PREFIX}546
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

############################
# SYSTEMD: story
############################
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Node
After=network-online.target story-geth.service

[Service]
User=$USER
WorkingDirectory=$STORY_HOME/story
ExecStart=$STORY_BIN run
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

############################
# SNAPSHOTS (OPTIONAL)
############################
echo "Downloading snapshots..."

sudo systemctl daemon-reload

cp "$STORY_HOME/story/data/priv_validator_state.json" \
   "$STORY_HOME/story/priv_validator_state.json.backup" || true

rm -rf "$STORY_HOME/story/data"
curl https://server-2.itrocket.net/mainnet/story/story_2025-12-12_11812794_snap.tar.lz4 \
  | lz4 -dc | tar -xf - -C "$STORY_HOME/story"

mv "$STORY_HOME/story/priv_validator_state.json.backup" \
   "$STORY_HOME/story/data/priv_validator_state.json" || true

mkdir -p "$STORY_HOME/geth/story/geth"
rm -rf "$STORY_HOME/geth/story/geth/chaindata"
curl https://server-2.itrocket.net/mainnet/story/geth_story_2025-12-12_11812794_snap.tar.lz4 \
  | lz4 -dc | tar -xf - -C "$STORY_HOME/geth/story/geth"

############################
# START
############################
sudo systemctl enable story-geth story
sudo systemctl restart story-geth
sleep 5
sudo systemctl restart story

echo "=== INSTALL DONE ==="
echo "Logs:"
echo "journalctl -u story-geth -f"
echo "journalctl -u story -f"
