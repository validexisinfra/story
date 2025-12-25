#!/usr/bin/env bash
set -e

### ================== CONFIGURATION ==================
STORY_VERSION="v1.4.2"
GETH_VERSION="v1.1.0"
GO_VERSION="1.23.5"
STORY_PORT=36
MONIKER="your_moniker_here"
NETWORK="aeneid"

SEEDS="46b7995b0b77515380000b7601e6fc21f783e16f@story-testnet-seed.itrocket.net:52656"
PEERS="01f8a2148a94f0267af919d2eab78452c90d9864@story-testnet-peer.itrocket.net:52656,bbdc5d760daa758d294f6305d5df4e9560762ca1@188.40.102.137:55656,5812d193191d98dbd732f6266192aa401c839a16@65.21.88.99:14656,2d0585ca77f128723f80f70d1c2c3f71e2e02372@65.21.130.42:26656"

### ================== SYSTEM UPDATE ==================
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git jq lz4 build-essential

### ================== INSTALL GO ==================
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local

echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" | sudo tee /etc/profile.d/golang.sh
echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile

go version

### ================== INSTALL GETH ==================
cd $HOME
rm -rf story-geth
git clone https://github.com/piplabs/story-geth.git
cd story-geth
git checkout ${GETH_VERSION}
make geth
mkdir -p $HOME/go/bin
mv build/bin/geth $HOME/go/bin/

### ================== INSTALL STORY ==================
cd $HOME
rm -rf story
git clone https://github.com/piplabs/story
cd story
git checkout ${STORY_VERSION}
go build -o story ./client
mv story $HOME/go/bin/

### ================== INIT STORY ==================
story init $MONIKER --network $NETWORK

### ================== CONFIG ==================
CONFIG="$HOME/.story/story/config"

sed -i -e "/^\[p2p\]/,/^\[/{s/^seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" \
       $CONFIG/config.toml

sed -i 's/prometheus = false/prometheus = true/' $CONFIG/config.toml
sed -i 's/^indexer *=.*/indexer = "null"/' $CONFIG/config.toml

### ================== PORTS ==================
sed -i.bak -e "s%:1317%:${STORY_PORT}317%g;
s%:8551%:${STORY_PORT}551%g" $CONFIG/story.toml

sed -i.bak -e "s%:26658%:${STORY_PORT}658%g;
s%:26657%:${STORY_PORT}657%g;
s%:26656%:${STORY_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(curl -s eth0.me):${STORY_PORT}656\"%;
s%:26660%:${STORY_PORT}660%g" $CONFIG/config.toml

### ================== SYSTEMD ==================
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth
After=network-online.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/geth --aeneid --syncmode full \
 --http --http.addr 0.0.0.0 --http.port ${STORY_PORT}545 \
 --authrpc.port ${STORY_PORT}551 \
 --ws --ws.addr 0.0.0.0 --ws.port ${STORY_PORT}546
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
ExecStart=$(which story) run
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

### ================== SNAPSHOTS ==================
cp $HOME/.story/story/data/priv_validator_state.json \
   $HOME/.story/story/priv_validator_state.json.backup

rm -rf $HOME/.story/story/data
curl https://server-3.itrocket.net/testnet/story/story_2025-12-24_12549758_snap.tar.lz4 \
 | lz4 -dc - | tar -xf - -C $HOME/.story/story

mv $HOME/.story/story/priv_validator_state.json.backup \
   $HOME/.story/story/data/priv_validator_state.json

rm -rf $HOME/.story/geth/aeneid/geth/chaindata
mkdir -p $HOME/.story/geth/aeneid/geth
curl https://server-3.itrocket.net/testnet/story/geth_story_2025-12-24_12549758_snap.tar.lz4 \
 | lz4 -dc - | tar -xf - -C $HOME/.story/geth/aeneid/geth

### ================== START ==================
sudo systemctl daemon-reload
sudo systemctl enable story story-geth
sudo systemctl restart story-geth
sleep 5
sudo systemctl restart story

journalctl -u story -u story-geth -f
