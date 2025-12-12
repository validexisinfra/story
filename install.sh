#!/usr/bin/env bash
set -e

### CONFIG ###
NODE_MONIKER="NodeName"        # <-- ЗАМЕНИ на свой moniker
STORY_NETWORK="story"          # story | aeneid
STORY_VERSION="v1.4.1"
GETH_VERSION="v1.1.2"

### COLORS ###
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${GREEN}== Story full node installer ==${NC}"

### 1. System update & deps ###
echo -e "${GREEN}Installing system dependencies...${NC}"
sudo apt update
sudo apt install -y \
  git curl build-essential make jq gcc snapd chrony \
  lz4 tmux unzip bc wget

### 2. Check Go ###
echo -e "${GREEN}Checking Go installation...${NC}"
if ! command -v go >/dev/null 2>&1; then
  echo -e "${RED}Go is not installed. Please install Go before running this script.${NC}"
  exit 1
fi

go version

### 3. Install Story Geth ###
echo -e "${GREEN}Installing story-geth ${GETH_VERSION}...${NC}"
cd $HOME
wget -q https://github.com/piplabs/story-geth/releases/download/${GETH_VERSION}/geth-linux-amd64
mv geth-linux-amd64 geth
chmod +x geth
mkdir -p $HOME/go/bin
mv geth $HOME/go/bin/
geth -v

### 4. Install Story ###
echo -e "${GREEN}Installing story ${STORY_VERSION}...${NC}"
wget -q https://github.com/piplabs/story/releases/download/${STORY_VERSION}/story-linux-amd64
mv story-linux-amd64 story
chmod +x story
mv story $HOME/go/bin/
story version

### 5. Init Story ###
echo -e "${GREEN}Initializing Story node...${NC}"
story init --network ${STORY_NETWORK} --moniker "${NODE_MONIKER}"

### 6. Addrbook ###
echo -e "${GREEN}Downloading addrbook...${NC}"
curl -Ls https://ss.story.nodestake.org/addrbook.json \
  > $HOME/.story/story/config/addrbook.json

### 7. Story systemd service ###
echo -e "${GREEN}Creating story.service...${NC}"
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which story) run
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

### 8. Geth systemd service ###
echo -e "${GREEN}Creating geth.service...${NC}"
sudo tee /etc/systemd/system/geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which geth) --story --syncmode full
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable story geth

### 9. Optional snapshots ###
echo -e "${GREEN}Downloading Story snapshot (optional)...${NC}"
SNAP_NAME=$(curl -s https://ss-t.story.nodestake.org/ \
  | egrep -o ">20.*\.tar.lz4" | tr -d ">")

if [[ -n "$SNAP_NAME" ]]; then
  sudo systemctl stop story geth

  cp $HOME/.story/story/data/priv_validator_state.json \
     $HOME/.story/story/priv_validator_state.json.backup || true

  rm -rf $HOME/.story/story/data
  curl -L https://ss.story.nodestake.org/${SNAP_NAME} \
    | lz4 -dc | tar -xf - -C $HOME/.story/story

  mv $HOME/.story/story/priv_validator_state.json.backup \
     $HOME/.story/story/data/priv_validator_state.json || true

  mkdir -p $HOME/.story/geth/story/geth
  curl -L https://ss.story.nodestake.org/geth.tar.lz4 \
    | lz4 -dc | tar -xf - -C $HOME/.story/geth/story/geth
fi

### 10. Start services ###
echo -e "${GREEN}Starting services...${NC}"
sudo systemctl restart geth
sleep 3
sudo systemctl restart story

echo -e "${GREEN}Installation complete.${NC}"
echo "Check logs:"
echo "  journalctl -u story -f"
echo "  journalctl -u geth -f"
