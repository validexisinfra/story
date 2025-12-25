#!/usr/bin/env bash
set -e

# === Configuration ===
STORY_VERSION="v1.4.2"
STORY_REPO="https://github.com/piplabs/story"
INSTALL_DIR="$HOME/story"

echo "▶ Updating Story to version $STORY_VERSION"

# Go to HOME directory
cd "$HOME"

# Remove existing directory if it exists
if [ -d "$INSTALL_DIR" ]; then
  echo "🧹 Removing existing story directory"
  rm -rf "$INSTALL_DIR"
fi

# Clone repository
echo "📥 Cloning repository"
git clone "$STORY_REPO"
cd story

# Checkout required version
echo "🔀 Checking out tag $STORY_VERSION"
git checkout "$STORY_VERSION"

# Build story client
echo "⚙️ Building story client"
go build -o story ./client

# (Optional) Update geth — uncomment if needed
# echo "⏸ Stopping story-geth"
# sudo systemctl stop story-geth
#
# echo "⬇️ Updating geth"
# sudo wget -O $(which geth) https://github.com/piplabs/story-geth/releases/download/v1.1.0/geth-linux-amd64
# sudo chmod +x $(which geth)
#
# echo "▶ Starting story-geth"
# sudo systemctl start story-geth

# Install binary
echo "📦 Installing story binary"
sudo mv "$INSTALL_DIR/story" "$(which story)"

# Restart service
echo "🔄 Restarting story service"
sudo systemctl restart story

# Show logs
echo "📜 Story logs (Ctrl+C to exit)"
sudo journalctl -u story -f
