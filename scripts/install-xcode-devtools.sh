#!/usr/bin/env bash
set -euo pipefail

# Usage: curl -fsSL https://raw.githubusercontent.com/<USERNAME>/<REPO>/master/scripts/install-xcode-devtools.sh | bash

echo "🔍 Checking for Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
  echo "✅ Xcode Command Line Tools already installed at $(xcode-select -p)"
  exit 0
else
  echo "🛠 Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "ℹ️ A GUI window may appear—please follow the prompts to complete installation."
  echo "Once finished, re-run this script to verify installation."
  exit 0
fi 