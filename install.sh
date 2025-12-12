#!/usr/bin/env bash
set -e

############################
# CONFIG
############################
MONIKER="test"
STORY_CHAIN_ID="story-1"
STORY_PORT="45"

GO_VERSION="1.22.5"
STORY_VERSION="v1.4.1"
GETH_VERSION="v1.1.2"

BIN_DIR="$HOME/go/bin"
STORY_BIN="$BIN_DIR/story"
GETH_BIN="$BIN_DIR/geth"

STORY_HOME="$HOME/.story/story"
GETH_HOME="$HOME/.story/geth"

############################
# Deps
############################
sudo apt update
sudo apt install -y git curl build-essential jq lz4 tmux unzip bc wget

############################
# Go
############################
cd $HOME
sudo rm -rf /usr/local/go
wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz

mkdir -p $BIN_DIR
export PATH=/usr/local/go/bin:$BIN_DIR:$PATH

go version

############################
# Build story-geth (glibc SAFE)
############################
cd $HOME
git clone https://github.com/piplabs/story-geth.git
cd story-geth
git checkout ${GETH_VERSION}
make geth
cp build/bin/geth $GETH_BIN
chmod +x $GETH_BIN

$GETH_BIN version

cd $HOME
rm -rf story-geth

############################
# Build story
############################
git clone https://github.com/piplabs/story
cd story
git checkout ${STORY_VERSION}
go build -o story ./client
mv story $STORY_BIN
chmod +x $STORY_BIN

$STORY_BIN version

############################
# Init
############################
$STORY_BIN init --moniker $MONIKER --network $STORY_CHAIN_ID

############################
# Peers / Seeds
############################
SEEDS="8db87ee67cdf4c098d023e8f96d6156f098f0ae1@story-mainnet-seed.itrocket.net:45656"
PEERS="ef8d211e08ca33193c2dff535ec5a29902e2b3f4@story-mainnet-peer.itrocket.net:45656"

sed -i -e "/^\[p2p\]/,/^\[/{s/^seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" \
       $STORY_HOME/config/config.toml

############################
# Ports
############################
sed -i -e "
s/:26658/:${STORY_PORT}658/g;
s/:26657/:${STORY_PORT}657/g;
s/:26656/:${STORY_PORT}656/g;
s/:26660/:${STORY_PORT}660/g;
" $STORY_HOME/config/config.toml

sed -i -e "
s/:1317/:${STORY_PORT}317/g;
s/:8551/:${STORY_PORT}551/g;
" $STORY_HOME/config/story.toml

sed -i 's/prometheus = false/prometheus = true/' $STORY_HOME/config/config.toml
sed -i 's/^indexer *=.*/indexer = "null"/' $STORY_HOME/config/config.toml

############################
# systemd
############################
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth
After=network-online.target

[Service]
User=$USER
ExecStart=$GETH_BIN --story --syncmode full \
 --http --http.api eth,net,web3,engine \
 --http.addr 0.0.0.0 --http.port ${STORY_PORT}545 \
 --authrpc.port ${STORY_PORT}551 \
 --ws --ws.api eth,web3,net,txpool \
 --ws.addr 0.0.0.0 --ws.port ${STORY_PORT}546 \
 --port ${STORY_PORT}303
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$STORY_HOME
ExecStart=$STORY_BIN run
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

############################
# Snapshot
############################
sudo systemctl daemon-reload
sudo systemctl stop story story-geth

cp $STORY_HOME/data/priv_validator_state.json \
   $STORY_HOME/priv_validator_state.json.backup || true

rm -rf $STORY_HOME/data
curl https://server-2.itrocket.net/mainnet/story/story_2025-12-12_11812794_snap.tar.lz4 \
 | lz4 -dc | tar -xf - -C $STORY_HOME

mv $STORY_HOME/priv_validator_state.json.backup \
   $STORY_HOME/data/priv_validator_state.json || true

mkdir -p $GETH_HOME/story/geth
curl https://server-2.itrocket.net/mainnet/story/geth_story_2025-12-12_11812794_snap.tar.lz4 \
 | lz4 -dc | tar -xf - -C $GETH_HOME/story/geth

############################
# Start
############################
sudo systemctl enable story story-geth
sudo systemctl restart story-geth
sleep 5
sudo systemctl restart story

echo "DONE"
journalctl -u story -u story-geth -f
