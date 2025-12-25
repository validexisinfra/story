#!/usr/bin/env bash
set -e

# === Configuration ===
STORY_VERSION="v1.4.2"
STORY_REPO="https://github.com/piplabs/story"
INSTALL_DIR="$HOME/story"

echo "▶ Installing Story version $STORY_VERSION"

# Go to HOME directory
cd "$HOME"

# Remove existing installation
if [ -d "$INSTALL_DIR" ]; then
  echo "🧹 Removing existing story directory"
  rm -rf "$INSTALL_DIR"
fi

# Clone repository
echo "📥 Cloning Story repository"
git clone "$STORY_REPO"
cd story

# Checkout specific version
echo "🔀 Checking out $STORY_VERSION"
git checkout "$STORY_VERSION"

# Build binary
echo "⚙️ Building Story client"
go build -o story ./client

# Install binary system-wide
echo "📦 Installing Story binary"
sudo mv "$INSTALL_DIR/story" "$(which story)"

# Restart service and show logs
echo "🔄 Restarting story service"
sudo systemctl restart story

echo "📜 Following story logs (Ctrl+C to exit)"
sudo journalctl -u story -f
