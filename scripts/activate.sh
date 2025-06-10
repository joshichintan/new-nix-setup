#!/usr/bin/env bash
set -euo pipefail

# Root of the dotfiles repository
dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
user_flake="chintan"

# Detect host flake (personal vs work)
hostname=$(hostname)
if [[ "$hostname" == *"personal"* ]]; then
  host_flake="personal"
else
  host_flake="work"
fi

cd "$dotfiles_dir"

# Auto-commit any changes
if [[ -n $(git status --porcelain) ]]; then
  echo "💾 Git: committing changes..."
  git add .
  git commit -m "🔧 Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')"
  git push
else
  echo "✅ Git: no changes to commit."
fi

# Apply nix-darwin configuration
echo "⚙️ Running darwin-rebuild for host '$host_flake'..."
darwin-rebuild switch --flake "$dotfiles_dir#${host_flake}"

# Apply home-manager configuration
echo "👤 Running home-manager for user '$user_flake'..."
home-manager switch --flake "$dotfiles_dir#${user_flake}" 