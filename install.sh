#!/usr/bin/env bash

############################################
# Story full node installer (FINAL, SAFE)
# - build story-geth from source (glibc-safe)
# - absolute paths, no PATH dependency
# - safe for screen / tmux
############################################

set +e

### CONFIG ###
NODE_MONIKER="NodeName"        # <-- ЗАМЕНИ
STORY_NETWORK="story"          # story | aeneid
STORY_VERSION="v1.4.1"
GETH_VERSION="v1.1.2"

### PATHS ###
BIN_DIR="$HOME/go/bin"
STORY_BIN="$BIN_DIR/story"
GETH_BIN="$BIN_DIR/geth"
STORY_HOME="$HOME/.story/story"
GETH_HOME="$HOME/.story/geth"

### COLORS ###
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${GREEN}== Story full node installer (FINAL) ==${NC}"

############################################
# 1. System deps
############################################
echo -e "${GREEN}Installing system dependencies...${NC}"
sudo apt update
sudo apt install -y \
  git curl build-essential make jq gcc snapd chrony \
  lz4 tmux unzip bc wget

############################################
# 2. Check Go
############################################
echo -e "${GREEN}Checking Go installation...${NC}"
if ! command -v go >/dev/null 2>&1; then
  echo -e "${RED}Go is not installed. Install Go first.${NC}"
  exit 1
fi
go version

############################################
# 3. Build story-geth from source
############################################
echo -e "${GREEN}Building story-geth from source (${GETH_VERSION})...${NC}"

cd "$HOME" || exit 1
rm -rf story-geth

git clone https://github.com/piplabs/story-geth.git
cd story-geth || exit 1
git checkout "${GETH_VERSION}"

make geth
if [[ $? -ne 0 ]]; then
  echo -e "${RED}geth build failed${NC}"
  exit 1
fi

mkdir -p "$BIN_DIR"
cp build/bin/geth "$GETH_BIN"
chmod +x "$GETH_BIN"

"$GETH_BIN" version || exit 1

cd "$HOME"
rm -rf story-geth

############################################
# 4. Install Story binary
############################################
echo -e "${GREEN}Installing story ${STORY_VERSION}...${NC}"

wget -q "https://github.com/piplabs/story/releases/download/${STORY_VERSION}/story-linux-amd64"
mv story-linux-amd64 story
chmod +x story
mkdir -p "$BIN_DIR"
mv story "$STORY_BIN"

"$STORY_BIN" version || exit 1

############################################
# 5. Init Story
############################################
echo -e "${GREEN}Initializing Story node...${NC}"

"$STORY_BIN" init --network "${STORY_NETWORK}" --moniker "${NODE_MONIKER}"

############################################
# 6. Addrbook
############################################
echo -e "${GREEN}Downloading addrbook...${NC}"

mkdir -p "$STORY_HOME/config"
curl -Ls https://ss.story.nodestake.org/addrbook.json \
  > "$STORY_HOME/config/addrbook.json"

############################################
# 7. story.service
############################################
echo -e "${GREEN}Creating story.service...${NC}"

sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$STORY_BIN run
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

############################################
# 8. geth.service
############################################
echo -e "${GREEN}Creating geth.service...${NC}"

sudo tee /etc/systemd/system/geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$GETH_BIN --story --syncmode full
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable story geth

############################################
# 9. Optional snapshot
############################################
echo -e "${GREEN}Checking snapshot...${NC}"

SNAP_NAME=$(curl -s https://ss-t.story.nodestake.org/ \
  | egrep -o ">20.*\.tar.lz4" | tr -d ">")

if [[ -n "$SNAP_NAME" ]]; then
  echo -e "${YELLOW}Applying snapshot ${SNAP_NAME}${NC}"

  sudo systemctl stop story geth

  if [[ -f "$STORY_HOME/data/priv_validator_state.json" ]]; then
    cp "$STORY_HOME/data/priv_validator_state.json" \
       "$STORY_HOME/priv_validator_state.json.backup"
  fi

  rm -rf "$STORY_HOME/data"

  curl -L "https://ss.story.nodestake.org/${SNAP_NAME}" \
    | lz4 -dc | tar -xf - -C "$STORY_HOME"

  if [[ -f "$STORY_HOME/priv_validator_state.json.backup" ]]; then
    mv "$STORY_HOME/priv_validator_state.json.backup" \
       "$STORY_HOME/data/priv_validator_state.json"
  fi

  mkdir -p "$GETH_HOME/story/geth"

  curl -L https://ss.story.nodestake.org/geth.tar.lz4 \
    | lz4 -dc | tar -xf - -C "$GETH_HOME/story/geth"
fi

############################################
# 10. Start services
############################################
echo -e "${GREEN}Starting services...${NC}"

sudo systemctl restart geth
sleep 3
sudo systemctl restart story

echo
echo -e "${GREEN}Installation complete.${NC}"
echo
echo "Logs:"
echo "  journalctl -u geth -f"
echo "  journalctl -u story -f"
