{ config, pkgs, ... }:
{
  # Simple shell aliases
  programs.zsh.shellAliases = {
    # Shell utilities
    reload = "source ~/.zshenv 2>/dev/null || true && source \"$ZDOTDIR/.zshrc\" 2>/dev/null || true";
    
    # Dev setup methods
    generate-ssh-key = "generate_ssh_key";
    setup-git-ssh = "setup_git_ssh";
    setup-dev-environment = "setup_dev_environment";
  };

  # Dev setup functions
  programs.zsh.initExtra = ''
    # Development setup functions
    generate_ssh_key() {
      echo "» Generating SSH key..."
      ssh-keygen -t ed25519 -C "$(git config user.email)" -f ~/.ssh/id_ed25519 -N ""
      chmod 600 ~/.ssh/id_ed25519
      chmod 644 ~/.ssh/id_ed25519.pub
      ssh-add ~/.ssh/id_ed25519
      echo "✓ SSH key generated and added to agent"
      echo "→ Public key:"
      cat ~/.ssh/id_ed25519.pub
    }
    
    setup_git_ssh() {
      echo "» Git configuration commands:"
      echo "git config --global user.name \"Your Name\""
      echo "git config --global user.email \"your@email.com\""
      echo "git config --global init.defaultBranch main"
      echo "git config --global pull.rebase false"
    }
    
    setup_dev_environment() {
      echo "» Setting up development environment..."
      generate_ssh_key
      echo ""
      echo "→ Add your SSH key to GitHub: https://github.com/settings/keys"
      echo ""
      setup_git_ssh
      echo "✓ Development environment setup complete"
    }
  '';
}
