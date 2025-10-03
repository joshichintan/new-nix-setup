{
  config,
  lib,
  pkgs,
  ...
}: {
  # Zsh configuration
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh"; # make sure xdg.enable = true; in home config for this to work.
    history = {
      path = "$ZDOTDIR/.zsh_history";
      append = true;
      saveNoDups = true;
      ignoreAllDups = true;
      findNoDups = true;
    };

    historySubstringSearch = {
      enable = true;
      searchUpKey = ["^k"];
      searchDownKey = ["^j"];
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = let
      p10kPrompt = lib.mkOrder 500 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]];
        then source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"; fi
      '';
      
      functions = lib.mkOrder 1000 ''
        # Add Rancher Desktop binaries to PATH
        export PATH="$HOME/.rd/bin:$PATH"
        
        # Note: mise is automatically activated via programs.mise.enableZshIntegration
        # No manual activation needed
        
      # Auto-activate mise environment when changing directories
      autoload -U add-zsh-hook
      mise_auto_activate() {
        # Check if mise detects any configuration for current directory
        if mise ls --current &>/dev/null && [[ -n "$(mise ls --current 2>/dev/null)" ]]; then
          # Check if any tools are missing and install them (show output only when installing)
          # Use JSON output for robust detection (more reliable than text parsing)
          if mise ls --current --json 2>/dev/null | grep -q '"installed": false'; then
            mise install || true
          else
            mise install --quiet 2>/dev/null || true
          fi
          # Activate mise environment for this directory
          eval "$(mise hook-env -s zsh)"
          
          # Only display if there's a project-level config (check if source path is in current dir)
          local has_local_config=false
          local current_dir="$PWD"
          
          # Check if any tool's source is from a file directly in current directory (not subdirs or parent/global)
          local json_output=$(mise ls --current --json 2>/dev/null)
          if echo "$json_output" | grep -q "\"path\": \"$current_dir/[^/]*\""; then
            has_local_config=true
          fi
          
          if [[ "$has_local_config" == "true" ]]; then
            # Display active tool versions with tree structure
            echo "Active Tools"
            local tools=($(mise ls --current 2>/dev/null | awk '{if ($1 && $2) print $1":"$2}'))
            local count=''${#tools[@]}
            local i=1
            
            for tool_version in "''${tools[@]}"; do
              local tool="''${tool_version%%:*}"
              local version="''${tool_version##*:}"
              
              if [[ $i -eq $count ]]; then
                echo "└─ $tool → $version"
              else
                echo "├─ $tool → $version"
              fi
              ((i++))
            done
          fi
        fi
      }
      add-zsh-hook chpwd mise_auto_activate
        
        # Home Manager functions
        hm() {
          nix --extra-experimental-features 'nix-command flakes' run "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage"
        }

        hm-build() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage"
        }

        hm-check() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage" --dry-run
        }

        # nix-darwin functions
        darwin() {
          sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-rebuild' -- switch --flake "''${NIX_USER_CONFIG_PATH:-.}#$(scutil --get LocalHostName)"
        }

        darwin-build() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(scutil --get LocalHostName).system"
        }

        darwin-check() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(scutil --get LocalHostName).system" --dry-run
        }

        # Quick rebuild functions
        rebuild() {
          darwin && hm
        }
        
        rebuild-home() {
          hm
        }
        
        rebuild-system() {
          darwin
        }
        
        # SSH Key Generation
        generate-ssh-key() {
          echo "» SSH Key Generation"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Check if key exists
          if [ -f ~/.ssh/id_ed25519 ]; then
            echo "⚠ SSH key already exists: ~/.ssh/id_ed25519"
            echo "1. Keep existing key"
            echo "2. Replace with new key (backup old)"
            echo "3. Show existing key"
            
            choice=""
            vared -p "Choose option (1-3): " choice
            
            case $choice in
              1)
                echo "• Keeping existing key"
                cat ~/.ssh/id_ed25519.pub
                return 0
                ;;
              2)
                echo "→ Replacing existing key..."
                # Backup old key
                cp ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.backup.$(date +%Y%m%d_%H%M%S)
                cp ~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub.backup.$(date +%Y%m%d_%H%M%S)
                ;;
              3)
                echo "→ Existing public key:"
                cat ~/.ssh/id_ed25519.pub
                return 0
                ;;
              *)
                echo "✗ Invalid option"
                return 1
                ;;
            esac
          fi
          
          # Prompt for email
          email=""
          while true; do
            vared -p "Enter your email address: " email
            if [ -z "$email" ]; then
              echo "✗ Email is required"
              continue
            fi
            
            if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
              echo "✗ Invalid email format"
              continue
            fi
            
            break
          done
          
          # Generate key
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""
          chmod 600 ~/.ssh/id_ed25519
          chmod 644 ~/.ssh/id_ed25519.pub
          
          # Add to SSH agent
          eval "$(ssh-agent -s)"
          ssh-add ~/.ssh/id_ed25519
          
          echo "✓ SSH key generated for: $email"
          echo "→ Public key:"
          cat ~/.ssh/id_ed25519.pub
          echo ""
          echo "→ Add this key to GitHub: https://github.com/settings/keys"
        }
        
        # Git Setup
        setup-git-ssh() {
          echo "» Git Configuration"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Check existing configuration
          existing_name=$(git config --global user.name 2>/dev/null)
          existing_email=$(git config --global user.email 2>/dev/null)
          
          if [ -n "$existing_name" ] || [ -n "$existing_email" ]; then
            echo "⚠ Git is already configured:"
            echo "  Name: $existing_name"
            echo "  Email: $existing_email"
            echo ""
            echo "1. Keep existing configuration"
            echo "2. Replace with new configuration"
            echo "3. Update specific values"
            
            choice=""
            vared -p "Choose option (1-3): " choice
            
            case $choice in
              1)
                echo "• Keeping existing configuration"
                return 0
                ;;
              2)
                echo "→ Replacing configuration..."
                ;;
              3)
                echo "→ Updating specific values..."
                ;;
              *)
                echo "✗ Invalid option"
                return 1
                ;;
            esac
          fi
          
          # Get name
          name=""
          if [ "$choice" = "3" ] && [ -n "$existing_name" ]; then
            vared -p "Enter your Git username [$existing_name]: " name
            name="${name:-$existing_name}"
          else
            while true; do
              vared -p "Enter your Git username: " name
              if [ -z "$name" ]; then
                echo "✗ Username is required"
                continue
              fi
              break
            done
          fi
          
          # Get email
          email=""
          if [ "$choice" = "3" ] && [ -n "$existing_email" ]; then
            vared -p "Enter your Git email [$existing_email]: " name
            email="${email:-$existing_email}"
          else
            while true; do
              vared -p "Enter your Git email: " email
              if [ -z "$email" ]; then
                echo "✗ Email is required"
                continue
              fi
              
              if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                echo "✗ Invalid email format"
                continue
              fi
              
              break
            done
          fi
          
          # Configure Git
          git config --global user.name "$name"
          git config --global user.email "$email"
          git config --global init.defaultBranch main
          git config --global pull.rebase false
          
          echo "✓ Git configured for: $name <$email>"
        }
        
        # Combined Setup
        setup-dev-environment() {
          echo "» Development Environment Setup"
          
          # SSH Key setup
          generate-ssh-key
          
          echo ""
          echo "→ Waiting for you to add the SSH key to GitHub..."
          dummy=""
          vared -p "Press Enter after adding the key to GitHub... " dummy
          
          # Test GitHub connection
          echo "→ Testing GitHub connection..."
          if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo "✓ GitHub connection successful"
          else
            echo "✗ GitHub connection failed"
            return 1
          fi
          
          # Git setup
          setup-git-ssh
          
          echo "✓ Development environment setup complete"
        }
        
        # Shell refresh function
        reload-shell() {
          echo "» Reloading shell configuration"
          source ~/.zshenv 2>/dev/null || true
          source "$ZDOTDIR/.zshrc" 2>/dev/null || true
          echo "✓ Configuration reloaded"
        }
      '';
    in
      lib.mkMerge [ p10kPrompt functions ];

    # Native Nix plugins (much faster than zplug)
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = ../p10k-config;
        file = ".p10k.zsh";
      }
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    sessionVariables = {
      NIX_USER_CONFIG_PATH = "${config.xdg.configHome}/nix-config";
    };


    shellAliases = {
      # General Nix aliases
      nix-update = "nix --extra-experimental-features 'nix-command flakes' flake update --flake .";
      nix-gc = "nix-store --gc";
      nix-clean = "nix-collect-garbage -d";
      
      # Shell refresh alias
      reload = "reload-shell";
      
      # Mise aliases
      mise-reload = "mise_auto_activate";
      
      # Config editing aliases
      nix-config = "nvim $NIX_USER_CONFIG_PATH";
    };
  };
}