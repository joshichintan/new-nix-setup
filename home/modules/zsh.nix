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
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 1: Powerlevel10k Instant Prompt
      # ══════════════════════════════════════════════════════════════════════
      p10kPrompt = lib.mkOrder 500 ''
        if [[ -r "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '';
      
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 2: Environment Setup, Hooks, and Functions
      # ══════════════════════════════════════════════════════════════════════
      functions = lib.mkOrder 1000 ''
        # ──────────────────────────────────────────────────────────────────
        # PATH Configuration
        # ──────────────────────────────────────────────────────────────────
        export PATH="$HOME/.rd/bin:$PATH"
        
        # ──────────────────────────────────────────────────────────────────
        # mise Hooks (Runtime Version Manager)
        # ──────────────────────────────────────────────────────────────────
        # Note: mise is automatically activated via programs.mise.enableZshIntegration
        # which sets up automatic environment activation via its own precmd hook
        
        autoload -U add-zsh-hook
        
        # Display active tools for project-level configs
        mise_display_tools() {
          if mise ls --current &>/dev/null && [[ -n "$(mise ls --current 2>/dev/null)" ]]; then
            local current_dir="$PWD"
            local json_output=$(mise ls --current --json 2>/dev/null)
            
            # Only display for project-level configs (not global)
            if echo "$json_output" | grep -q "\"path\": \"$current_dir/[^/]*\""; then
              # Check if any tools are missing
              if echo "$json_output" | grep -q '"installed": false'; then
                return  # Don't display if tools are not installed
              fi
              
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
        
        # Display tools on directory change
        mise_chpwd() {
          mise_display_tools
        }
        add-zsh-hook chpwd mise_chpwd
        
        # Install missing tools and display if installed
        typeset -g MISE_PRECMD_FIRST_RUN=1
        mise_precmd() {
          # Skip first run to avoid p10k instant prompt interference
          if [[ $MISE_PRECMD_FIRST_RUN -eq 1 ]]; then
            MISE_PRECMD_FIRST_RUN=0
            return
          fi
          
          if mise ls --current &>/dev/null && [[ -n "$(mise ls --current 2>/dev/null)" ]]; then
            if mise ls --current --json 2>/dev/null | grep -q '"installed": false'; then
              echo "» Installing missing tools..."
              mise install
              mise_display_tools  # Display after installation
            fi
          fi
        }
        add-zsh-hook precmd mise_precmd
        
        # ──────────────────────────────────────────────────────────────────
        # Nix Management Functions
        # ──────────────────────────────────────────────────────────────────
        
        # Home Manager
        hm() {
          nix --extra-experimental-features 'nix-command flakes' run "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage"
        }

        hm-build() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage"
        }

        hm-check() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage" --dry-run
        }

        # nix-darwin
        darwin() {
          sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-rebuild' -- switch --flake "''${NIX_USER_CONFIG_PATH:-.}#$(scutil --get LocalHostName)"
        }

        darwin-build() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(scutil --get LocalHostName).system"
        }

        darwin-check() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(scutil --get LocalHostName).system" --dry-run
        }

        # Combined rebuilds
        rebuild() {
          darwin && hm
        }
        
        rebuild-home() {
          hm
        }
        
        rebuild-system() {
          darwin
        }
        
        # ──────────────────────────────────────────────────────────────────
        # Development Environment Setup
        # ──────────────────────────────────────────────────────────────────
        
        generate-ssh-key() {
          echo "» SSH Key Generation"
          
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
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
        
        # ──────────────────────────────────────────────────────────────────
        # ECR Profile Management Functions
        # ──────────────────────────────────────────────────────────────────
        
        # Main ECR profile management
        setup-ecr-profiles() {
          echo "ECR Profile Management:"
          echo "1. Add new ECR registry"
          echo "2. Update ECR profile"
          echo "3. Remove ECR profile"
          echo "4. Resync ECR profiles"
          echo ""
          
          read -p "Enter your choice (1-4): " choice
          
          case $choice in
            1) setup_new_ecr_profile ;;
            2) update_ecr_profile ;;
            3) remove_ecr_profile ;;
            4) resync_ecr_profiles ;;
            *) echo "Invalid choice" ;;
          esac
        }
        
        # Add new ECR registry
        setup_new_ecr_profile() {
          echo "Add new ECR registry"
          echo ""
          
          # Get available AWS profiles
          aws_profiles=$(aws configure list-profiles)
          
          if [[ -z "$aws_profiles" ]]; then
            echo "No AWS profiles found"
            return 1
          fi
          
          echo "Available AWS profiles:"
          echo "$aws_profiles" | nl
          echo ""
          
          read -p "Select AWS profile number: " profile_num
          
          if [[ "$profile_num" =~ ^[0-9]+$ ]]; then
            selected_profile=$(aws configure list-profiles | sed -n "${profile_num}p")
            
            if [[ -n "$selected_profile" ]]; then
              echo ""
              read -p "ECR registry URL: " registry_url
              
              if [[ -n "$registry_url" ]]; then
                setup-ecr-profile "$selected_profile" "$registry_url"
                show_credhelper_config
              else
                echo "Registry URL is required"
              fi
            else
              echo "Invalid profile number"
            fi
          else
            echo "Invalid input"
          fi
        }
        
        # Update ECR profile
        update_ecr_profile() {
          echo "Update ECR Profile"
          echo ""
          
          # List existing ECR profiles
          local ecr_profiles
          ecr_profiles=$(jq -r '.credHelpers // {} | to_entries[] | select(.value | startswith("ecr-login-")) | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null || true)
          
          if [[ -z "$ecr_profiles" ]]; then
            echo "No ECR profiles found"
            return 0
          fi
          
          echo "Existing ECR profiles:"
          echo "$ecr_profiles" | nl
          echo ""
          
          read -p "Select ECR profile to update (number): " ecr_num
          
          if [[ "$ecr_num" =~ ^[0-9]+$ ]]; then
            local selected_ecr
            selected_ecr=$(echo "$ecr_profiles" | sed -n "${ecr_num}p")
            
            if [[ -n "$selected_ecr" ]]; then
              local registry_url
              registry_url=$(echo "$selected_ecr" | cut -d' ' -f1)
              local current_helper
              current_helper=$(echo "$selected_ecr" | cut -d' ' -f3)
              local current_aws_profile
              current_aws_profile=$(echo "$current_helper" | sed 's/^ecr-login-//')
              
              echo "Updating ECR profile for registry: $registry_url"
              echo ""
              
              # Get new AWS profile
              local new_aws_profile
              new_aws_profile=$(get_new_aws_profile "$current_aws_profile")
              
              if [[ -n "$new_aws_profile" ]]; then
                update_ecr_profile_direct "$registry_url" "$new_aws_profile"
                show_credhelper_config
              fi
            else
              echo "Invalid ECR profile number"
            fi
          else
            echo "Invalid input"
          fi
        }
        
        # Remove ECR profile
        remove_ecr_profile() {
          echo "Remove ECR Profile"
          echo ""
          
          # List existing ECR profiles
          local ecr_profiles
          ecr_profiles=$(jq -r '.credHelpers // {} | to_entries[] | select(.value | startswith("ecr-login-")) | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null || true)
          
          if [[ -z "$ecr_profiles" ]]; then
            echo "No ECR profiles found"
            return 0
          fi
          
          echo "Existing ECR profiles:"
          echo "$ecr_profiles" | nl
          echo ""
          
          read -p "Select ECR profile to remove (number): " ecr_num
          
          if [[ "$ecr_num" =~ ^[0-9]+$ ]]; then
            local selected_ecr
            selected_ecr=$(echo "$ecr_profiles" | sed -n "${ecr_num}p")
            
            if [[ -n "$selected_ecr" ]]; then
              local registry_url
              registry_url=$(echo "$selected_ecr" | cut -d' ' -f1)
              
              echo "Removing ECR profile for registry: $registry_url"
              echo ""
              
              read -p "Are you sure? (y/N): " confirm
              
              if [[ "$confirm" =~ ^[Yy]$ ]]; then
                remove_ecr_profile_direct "$registry_url"
                show_credhelper_config
              else
                echo "Cancelled"
              fi
            else
              echo "Invalid ECR profile number"
            fi
          else
            echo "Invalid input"
          fi
        }
        
        # Resync ECR profiles
        resync_ecr_profiles() {
          echo "🔄 Resyncing ECR profiles..."
          echo ""
          
          # Get all ECR profiles from Docker config
          local ecr_profiles
          ecr_profiles=$(jq -r '.credHelpers // {} | to_entries[] | select(.value | startswith("ecr-login-")) | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null || true)
          
          if [[ -z "$ecr_profiles" ]]; then
            echo "No ECR profiles found in Docker config"
            return 0
          fi
          
          # Check each ECR profile
          echo "$ecr_profiles" | while IFS=' -> ' read -r registry helper; do
            local aws_profile
            aws_profile=$(echo "$helper" | sed 's/^ecr-login-//')
            
            # Check if AWS profile exists
            if aws configure list-profiles | grep -q "^$aws_profile$"; then
              echo "✓ ECR profile is valid (AWS profile: $aws_profile exists)"
            else
              echo "⚠ ECR profile is invalid (AWS profile: $aws_profile missing)"
              handle_invalid_ecr_profile "$helper" "$registry"
            fi
          done
          
          echo ""
          echo "ECR resync complete!"
        }
        
        # Handle invalid ECR profile
        handle_invalid_ecr_profile() {
          local ecr_profile="$1"
          local registry_url="$2"
          
          echo "ECR profile '$ecr_profile' has missing AWS profile"
          echo "Registry: $registry_url"
          echo ""
          echo "What would you like to do?"
          echo "1. Select new AWS profile"
          echo "2. Remove ECR profile"
          echo "3. Skip"
          echo ""
          
          read -p "Enter choice (1-3): " choice
          
          case $choice in
            1)
              # Get new AWS profile
              local new_aws_profile
              new_aws_profile=$(get_new_aws_profile "")
              
              if [[ -n "$new_aws_profile" ]]; then
                update_ecr_profile_direct "$registry_url" "$new_aws_profile"
                show_credhelper_config
              fi
              ;;
            2)
              # Remove ECR profile
              remove_ecr_profile_direct "$registry_url"
              show_credhelper_config
              ;;
            3)
              echo "Skipping $ecr_profile"
              ;;
            *)
              echo "Invalid choice"
              ;;
          esac
        }
        
        # Get new AWS profile with validation
        get_new_aws_profile() {
          local current_profile="$1"
          local prompt="New AWS profile"
          
          if [[ -n "$current_profile" ]]; then
            prompt="New AWS profile [$current_profile]"
          fi
          
          read -p "$prompt: " new_profile
          
          # Validate the profile exists
          if aws configure list-profiles | grep -q "^$new_profile$"; then
            echo "$new_profile"
          else
            echo "Invalid AWS profile: $new_profile" >&2
            return 1
          fi
        }
        
        # Update ECR profile direct
        update_ecr_profile_direct() {
          local registry_url="$1"
          local new_aws_profile="$2"
          
          # Remove old ECR profile
          remove_ecr_profile_direct "$registry_url"
          
          # Create new ECR profile
          setup-ecr-profile "$new_aws_profile" "$registry_url"
        }
        
        # Remove ECR profile direct
        remove_ecr_profile_direct() {
          local registry_url="$1"
          
          # Get current credential helper
          local current_helper
          current_helper=$(jq -r --arg reg "$registry_url" '.credHelpers[$reg] // empty' ~/.docker/config.json 2>/dev/null)
          
          if [[ -n "$current_helper" ]]; then
            # Remove binary
            local binary_path="${config.xdg.dataHome}/bin/$current_helper"
            if [[ -f "$binary_path" ]]; then
              rm -f "$binary_path"
            fi
            
            # Remove from Docker config
            local docker_config="$HOME/.docker/config.json"
            if [[ -f "$docker_config" ]]; then
              jq --arg reg "$registry_url" 'del(.credHelpers[$reg])' "$docker_config" > "$docker_config.tmp" && mv "$docker_config.tmp" "$docker_config"
            fi
          fi
        }
        
        # Show credhelper config
        show_credhelper_config() {
          echo ""
          echo "CredHelper config:"
          jq '.credHelpers // {}' ~/.docker/config.json 2>/dev/null || echo '{}'
        }
        
        # ECR profile setup helper
        setup-ecr-profile() {
          local profile_name="$1"
          local registry_url="$2"
          
          # Validate inputs
          if [[ -z "$profile_name" || -z "$registry_url" ]]; then
            echo "Profile name and registry URL are required"
            return 1
          fi
          
          # Check if AWS profile exists
          if ! aws configure list-profiles | grep -q "^$profile_name$"; then
            echo "AWS profile '$profile_name' does not exist"
            return 1
          fi
          
          # Create binary name and path (no prefix)
          binary_name="$profile_name"
          binary_path="${config.xdg.dataHome}/bin/$binary_name"
          
          # Ensure directory exists
          mkdir -p "$(dirname "$binary_path")"
          
          # Create the profile-specific binary
          cat > "$binary_path" << 'EOF'
#!/bin/bash
exec smart-ecr-helper "$@"
EOF
          
          chmod +x "$binary_path"
          
          # Update Docker config
          docker_config="$HOME/.docker/config.json"
          if [[ ! -f "$docker_config" ]]; then
            mkdir -p "$(dirname "$docker_config")"
            echo '{"credHelpers": {}}' > "$docker_config"
          fi
          
          # Add registry to Docker config using jq
          if command -v jq >/dev/null 2>&1; then
            jq --arg url "$registry_url" --arg helper "$binary_name" \
               '.credHelpers[$url] = $helper' "$docker_config" > "$docker_config.tmp" && \
            mv "$docker_config.tmp" "$docker_config"
          else
            echo "jq not found. Please manually add to ~/.docker/config.json:"
            echo "  \"$registry_url\": \"$binary_name\""
          fi
        }
        
        # ──────────────────────────────────────────────────────────────────
        # Utility Functions
        # ──────────────────────────────────────────────────────────────────
        
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