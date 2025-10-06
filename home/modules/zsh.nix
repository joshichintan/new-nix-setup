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
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
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
        # AWS Profile Management Functions
        # ──────────────────────────────────────────────────────────────────
        
        # Main AWS profile management
        setup-aws-profile() {
          echo "» AWS Profile Management"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Check if profiles exist
          profiles=$(aws configure list-profiles)
          
          if [[ -n "$profiles" ]]; then
            echo "Existing profiles: $profiles"
            echo ""
            echo "Choose action:"
            echo "1. Create new AWS profile"
            echo "2. Update existing AWS profile"
            echo "3. Remove AWS profile"
            echo "4. Resync AWS profiles (discover new accounts/roles)"
            echo "5. List all profiles"
            echo "6. Test profile"
            
            action_choice=""
            vared -p "Choose option (1-6): " action_choice
            
            case $action_choice in
              1)
                setup_new_aws_profile
                ;;
              2)
                update-aws-profile
                ;;
              3)
                remove-aws-profile
                ;;
              4)
                resync-aws-profiles
                ;;
              5)
                list-aws-profiles
                ;;
              6)
                test-aws-profile
                ;;
              *)
                echo "✗ Invalid option"
                return 1
                ;;
            esac
          else
            echo "No existing profiles found"
            echo "→ Creating new AWS profile..."
            setup_new_aws_profile
          fi
        }
        
        # AWS profile creation functions
        setup_new_aws_profile() {
          echo "» Create New AWS Profile"
          
          # Get profile name
          profile_name=""
          while true; do
            vared -p "Enter AWS profile name: " profile_name
            if [[ -z "$profile_name" ]]; then
              echo "✗ Profile name is required"
              continue
            fi
            
            # Check if profile already exists
            if aws configure list-profiles | grep -q "^$profile_name$"; then
              echo "✗ AWS profile '$profile_name' already exists"
              continue
            fi
            
            break
          done
          
          echo ""
          
          # Choose authentication method
          echo "Choose authentication method:"
          echo "1. AWS SSO (if your company uses it)"
          echo "2. Access Key & Secret Key (IAM user credentials)"
          echo "3. IAM Role (assume role from another profile)"
          
          auth_choice=""
          vared -p "Choose option (1-3): " auth_choice
          
          case $auth_choice in
            1)
              setup_sso_profile "$profile_name"
              ;;
            2)
              setup_credentials_profile "$profile_name"
              ;;
            3)
              setup_role_profile "$profile_name"
              ;;
            *)
              echo "✗ Invalid option"
              return 1
              ;;
          esac
        }
        
        # AWS profile update functions
        update-aws-profile() {
          echo "» Update AWS Profile"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Get all existing profiles
          profiles=$(aws configure list-profiles)
          
          if [[ -z "$profiles" ]]; then
            echo "✗ No AWS profiles found"
            return 1
          fi
          
          echo "Available profiles:"
          local profile_array=($profiles)
          for i in "${!profile_array[@]}"; do
            echo "  $((i+1)). ${profile_array[i]}"
          done
          
          echo ""
          echo "Select profile to update:"
          selected_index=""
          vared -p "Enter selection: " selected_index
          
          if [[ -z "$selected_index" ]]; then
            echo "✗ No profile selected"
            return 1
          fi
          
          # Validate index
          if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
            echo "✗ Invalid profile selection: $selected_index"
            return 1
          fi
          
          # Convert to 0-based index
          array_index=$((selected_index-1))
          selected_profile="${profile_array[$array_index]}"
          
          echo ""
          
          # Detect current auth method and show all configurable options
          if aws configure get sso_start_url --profile "$selected_profile" >/dev/null 2>&1; then
            # SSO Profile - show SSO options
            update_sso_profile_direct "$selected_profile"
          else
            # Credentials Profile - show credentials options
            update_credentials_profile_direct "$selected_profile"
          fi
        }
        
        # AWS profile resync functions
        resync-aws-profiles() {
          echo "» Resync AWS Profiles"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Get existing profiles
          existing_profiles=$(aws configure list-profiles)
          
          echo "Existing profiles:"
          if [[ -n "$existing_profiles" ]]; then
            echo "$existing_profiles" | sed 's/^/  /'
          else
            echo "  No existing profiles found"
          fi
          echo ""
          
          # Choose resync method
          echo "Choose resync method:"
          echo "1. AWS SSO resync (discover new accounts and roles)"
          echo "2. IAM User resync (discover new roles in current account)"
          echo "3. Complete resync (discover everything and cleanup)"
          
          resync_choice=""
          vared -p "Choose option (1-3): " resync_choice
          
          case $resync_choice in
            1)
              resync_sso_profiles "$existing_profiles"
              ;;
            2)
              resync_iam_profiles "$existing_profiles"
              ;;
            3)
              resync_complete "$existing_profiles"
              ;;
            *)
              echo "✗ Invalid option"
              return 1
              ;;
          esac
        }
        
        # AWS profile removal functions
        remove-aws-profile() {
          echo "» Remove AWS Profile"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Get all existing profiles
          profiles=$(aws configure list-profiles)
          
          if [[ -z "$profiles" ]]; then
            echo "✗ No AWS profiles found"
            return 1
          fi
          
          echo "Available profiles:"
          local profile_array=($profiles)
          for i in "${!profile_array[@]}"; do
            echo "  $((i+1)). ${profile_array[i]}"
          done
          
          echo ""
          echo "Select profile to remove:"
          selected_index=""
          vared -p "Enter selection: " selected_index
          
          if [[ -z "$selected_index" ]]; then
            echo "✗ No profile selected"
            return 1
          fi
          
          # Validate index
          if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
            echo "✗ Invalid profile selection: $selected_index"
            return 1
          fi
          
          # Convert to 0-based index
          array_index=$((selected_index-1))
          selected_profile="${profile_array[$array_index]}"
          
          echo ""
          echo "Selected profile: $selected_profile"
          echo ""
          
          # Check for dependent ECR profiles
          dependent_ecr_profiles=()
          if [[ -f ~/.docker/config.json ]]; then
            # Find ECR profiles that use this AWS profile
            ecr_helper_name="ecr-login-${selected_profile}"
            dependent_registries=$(jq -r --arg helper "$ecr_helper_name" '.credHelpers // {} | to_entries[] | select(.value == $helper) | .key' ~/.docker/config.json 2>/dev/null)
            
            if [[ -n "$dependent_registries" ]]; then
              echo "⚠ WARNING: This AWS profile is connected to ECR profiles:"
              while IFS= read -r registry; do
                echo "  - $registry -> $ecr_helper_name"
                dependent_ecr_profiles+=("$registry")
              done <<< "$dependent_registries"
              echo ""
            fi
          fi
          
          # Check for profiles that use this as source profile
          dependent_role_profiles=()
          for profile in $profiles; do
            if [[ "$profile" != "$selected_profile" ]]; then
              source_profile=$(aws configure get source_profile --profile "$profile" 2>/dev/null)
              if [[ "$source_profile" == "$selected_profile" ]]; then
                dependent_role_profiles+=("$profile")
              fi
            fi
          done
          
          if [[ ${#dependent_role_profiles[@]} -gt 0 ]]; then
            echo "⚠ WARNING: These profiles depend on this profile as source profile:"
            for profile in "${dependent_role_profiles[@]}"; do
              echo "  - $profile (role profile)"
            done
            echo ""
          fi
          
          # Show removal options
          echo "Removal options:"
          echo "1. Remove AWS profile only"
          echo "2. Remove AWS profile and dependent ECR profiles"
          echo "3. Remove AWS profile, ECR profiles, and dependent role profiles"
          echo "4. Cancel removal"
          
          removal_choice=""
          vared -p "Choose option (1-4): " removal_choice
          
          case $removal_choice in
            1)
              remove_aws_profile_only "$selected_profile"
              ;;
            2)
              remove_aws_profile_with_ecr "$selected_profile" "${dependent_ecr_profiles[@]}"
              ;;
            3)
              remove_aws_profile_complete "$selected_profile" "${dependent_ecr_profiles[@]}" "${dependent_role_profiles[@]}"
              ;;
            4)
              echo "→ Removal cancelled"
              return 0
              ;;
            *)
              echo "✗ Invalid option"
              return 1
              ;;
          esac
        }
        
        # Helper functions for AWS profile management
        list-aws-profiles() {
          echo "» AWS Profiles"
          profiles=$(aws configure list-profiles)
          
          if [[ -z "$profiles" ]]; then
            echo "No AWS profiles found"
            return 0
          fi
          
          echo "Available profiles:"
          for profile in $profiles; do
            echo "  - $profile"
          done
        }
        
        test-aws-profile() {
          echo "» Test AWS Profile"
          
          profiles=$(aws configure list-profiles)
          
          if [[ -z "$profiles" ]]; then
            echo "✗ No AWS profiles found"
            return 1
          fi
          
          echo "Available profiles:"
          local profile_array=($profiles)
          for i in "${!profile_array[@]}"; do
            echo "  $((i+1)). ${profile_array[i]}"
          done
          
          echo ""
          echo "Select profile to test:"
          selected_index=""
          vared -p "Enter selection: " selected_index
          
          if [[ -z "$selected_index" ]]; then
            echo "✗ No profile selected"
            return 1
          fi
          
          # Validate index
          if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
            echo "✗ Invalid profile selection: $selected_index"
            return 1
          fi
          
          # Convert to 0-based index
          array_index=$((selected_index-1))
          selected_profile="${profile_array[$array_index]}"
          
          echo ""
          echo "Testing profile: $selected_profile"
          
          # Test profile
          if aws sts get-caller-identity --profile "$selected_profile" >/dev/null 2>&1; then
            echo "✓ Profile '$selected_profile' is working"
            echo "Account details:"
            aws sts get-caller-identity --profile "$selected_profile"
          else
            echo "✗ Profile '$selected_profile' is not working"
            echo "Please check your configuration and try again"
          fi
        }
        
        # AWS helper functions
        setup_sso_profile() {
          local profile_name="$1"
          
          # Get SSO configuration
          sso_start_url=""
          while true; do
            vared -p "SSO start URL: " sso_start_url
            if [[ -z "$sso_start_url" ]]; then
              echo "✗ SSO start URL is required"
              continue
            fi
            break
          done
          
          sso_region=""
          while true; do
            vared -p "SSO region (e.g., us-east-1): " sso_region
            if [[ -z "$sso_region" ]]; then
              echo "✗ SSO region is required"
              continue
            fi
            break
          done
          
          sso_account_id=""
          while true; do
            vared -p "SSO account ID: " sso_account_id
            if [[ -z "$sso_account_id" ]]; then
              echo "✗ SSO account ID is required"
              continue
            fi
            
            if [[ ! "$sso_account_id" =~ ^[0-9]{12}$ ]]; then
              echo "✗ Account ID must be 12 digits"
              continue
            fi
            break
          done
          
          sso_role_name=""
          while true; do
            vared -p "SSO role name: " sso_role_name
            if [[ -z "$sso_role_name" ]]; then
              echo "✗ SSO role name is required"
              continue
            fi
            break
          done
          
          region=""
          while true; do
            vared -p "Default region (e.g., us-west-1): " region
            if [[ -z "$region" ]]; then
              echo "✗ Default region is required"
              continue
            fi
            break
          done
          
          # Configure SSO profile
          aws configure set sso_start_url "$sso_start_url" --profile "$profile_name"
          aws configure set sso_region "$sso_region" --profile "$profile_name"
          aws configure set sso_account_id "$sso_account_id" --profile "$profile_name"
          aws configure set sso_role_name "$sso_role_name" --profile "$profile_name"
          aws configure set region "$region" --profile "$profile_name"
        }
        
        setup_credentials_profile() {
          local profile_name="$1"
          
          # Get credentials
          access_key=""
          while true; do
            vared -p "AWS Access Key ID: " access_key
            if [[ -z "$access_key" ]]; then
              echo "✗ Access Key ID is required"
              continue
            fi
            break
          done
          
          secret_key=""
          while true; do
            vared -p "AWS Secret Access Key: " secret_key
            if [[ -z "$secret_key" ]]; then
              echo "✗ Secret Access Key is required"
              continue
            fi
            break
          done
          
          region=""
          while true; do
            vared -p "Default region (e.g., us-west-1): " region
            if [[ -z "$region" ]]; then
              echo "✗ Default region is required"
              continue
            fi
            break
          done
          
          # Configure credentials profile
          aws configure set aws_access_key_id "$access_key" --profile "$profile_name"
          aws configure set aws_secret_access_key "$secret_key" --profile "$profile_name"
          aws configure set region "$region" --profile "$profile_name"
        }
        
        setup_role_profile() {
          local profile_name="$1"
          
          # Get available source profiles
          source_profiles=$(aws configure list-profiles)
          
          if [[ -z "$source_profiles" ]]; then
            echo "✗ No source profiles found"
            echo "→ Create a base profile first (SSO or credentials)"
            return 1
          fi
          
          echo "Available source profiles:"
          echo "$source_profiles" | sed 's/^/  /'
          echo ""
          
          # Select source profile
          echo "Select source profile:"
          local profile_array=($source_profiles)
          for i in "${!profile_array[@]}"; do
            echo "  $((i+1)). ${profile_array[i]}"
          done
          
          selected_index=""
          vared -p "Enter selection: " selected_index
          
          if [[ -z "$selected_index" ]]; then
            echo "✗ No profile selected"
            return 1
          fi
          
          # Validate index
          if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
            echo "✗ Invalid profile selection: $selected_index"
            return 1
          fi
          
          # Convert to 0-based index
          array_index=$((selected_index-1))
          source_profile="${profile_array[$array_index]}"
          
          echo ""
          
          # Get role ARN
          role_arn=""
          while true; do
            vared -p "Role ARN: " role_arn
            if [[ -z "$role_arn" ]]; then
              echo "✗ Role ARN is required"
              continue
            fi
            
            if [[ ! "$role_arn" =~ ^arn:aws:iam::[0-9]{12}:role/ ]]; then
              echo "✗ Invalid Role ARN format"
              echo "Expected format: arn:aws:iam::123456789012:role/RoleName"
              continue
            fi
            break
          done
          
          region=""
          while true; do
            vared -p "Default region (e.g., us-west-1): " region
            if [[ -z "$region" ]]; then
              echo "✗ Default region is required"
              continue
            fi
            break
          done
          
          # Configure role profile
          aws configure set role_arn "$role_arn" --profile "$profile_name"
          aws configure set source_profile "$source_profile" --profile "$profile_name"
          aws configure set region "$region" --profile "$profile_name"
        }
        
        update_sso_profile_direct() {
          local profile="$1"
          
          # Get current values
          current_sso_start_url=$(aws configure get sso_start_url --profile "$profile" 2>/dev/null)
          current_sso_region=$(aws configure get sso_region --profile "$profile" 2>/dev/null)
          current_sso_account_id=$(aws configure get sso_account_id --profile "$profile" 2>/dev/null)
          current_sso_role_name=$(aws configure get sso_role_name --profile "$profile" 2>/dev/null)
          current_region=$(aws configure get region --profile "$profile" 2>/dev/null)
          
          # Update SSO Start URL
          if [[ -n "$current_sso_start_url" ]]; then
            read -p "SSO start URL ($current_sso_start_url): " new_sso_start_url
            if [[ -n "$new_sso_start_url" ]]; then
              aws configure set sso_start_url "$new_sso_start_url" --profile "$profile"
            fi
          else
            while true; do
              read -p "SSO start URL: " new_sso_start_url
              if [[ -n "$new_sso_start_url" ]]; then
                aws configure set sso_start_url "$new_sso_start_url" --profile "$profile"
                break
              else
                echo "✗ SSO start URL is required"
              fi
            done
          fi
          
          # Update SSO Region
          if [[ -n "$current_sso_region" ]]; then
            read -p "SSO region ($current_sso_region): " new_sso_region
            if [[ -n "$new_sso_region" ]]; then
              aws configure set sso_region "$new_sso_region" --profile "$profile"
            fi
          else
            while true; do
              read -p "SSO region: " new_sso_region
              if [[ -n "$new_sso_region" ]]; then
                aws configure set sso_region "$new_sso_region" --profile "$profile"
                break
              else
                echo "✗ SSO region is required"
              fi
            done
          fi
          
          # Update SSO Account ID
          if [[ -n "$current_sso_account_id" ]]; then
            read -p "SSO account ID ($current_sso_account_id): " new_sso_account_id
            if [[ -n "$new_sso_account_id" ]]; then
              if [[ ! "$new_sso_account_id" =~ ^[0-9]{12}$ ]]; then
                echo "✗ Account ID must be 12 digits"
              else
                aws configure set sso_account_id "$new_sso_account_id" --profile "$profile"
              fi
            fi
          else
            while true; do
              read -p "SSO account ID: " new_sso_account_id
              if [[ -n "$new_sso_account_id" ]]; then
                if [[ ! "$new_sso_account_id" =~ ^[0-9]{12}$ ]]; then
                  echo "✗ Account ID must be 12 digits"
                  continue
                fi
                aws configure set sso_account_id "$new_sso_account_id" --profile "$profile"
                break
              else
                echo "✗ SSO account ID is required"
              fi
            done
          fi
          
          # Update SSO Role Name
          if [[ -n "$current_sso_role_name" ]]; then
            read -p "SSO role name ($current_sso_role_name): " new_sso_role_name
            if [[ -n "$new_sso_role_name" ]]; then
              aws configure set sso_role_name "$new_sso_role_name" --profile "$profile"
            fi
          else
            while true; do
              read -p "SSO role name: " new_sso_role_name
              if [[ -n "$new_sso_role_name" ]]; then
                aws configure set sso_role_name "$new_sso_role_name" --profile "$profile"
                break
              else
                echo "✗ SSO role name is required"
              fi
            done
          fi
          
          # Update Default Region
          if [[ -n "$current_region" ]]; then
            read -p "Default region ($current_region): " new_region
            if [[ -n "$new_region" ]]; then
              aws configure set region "$new_region" --profile "$profile"
            fi
          else
            while true; do
              read -p "Default region: " new_region
              if [[ -n "$new_region" ]]; then
                aws configure set region "$new_region" --profile "$profile"
                break
              else
                echo "✗ Default region is required"
              fi
            done
          fi
        }
        
        update_credentials_profile_direct() {
          local profile="$1"
          
          # Get current values
          current_access_key=$(aws configure get aws_access_key_id --profile "$profile" 2>/dev/null)
          current_secret_key=$(aws configure get aws_secret_access_key --profile "$profile" 2>/dev/null)
          current_region=$(aws configure get region --profile "$profile" 2>/dev/null)
          
          # Update Access Key ID
          if [[ -n "$current_access_key" ]]; then
            masked_key="${current_access_key:0:4}...${current_access_key: -4}"
            read -p "AWS Access Key ID ($masked_key): " new_access_key
            if [[ -n "$new_access_key" ]]; then
              aws configure set aws_access_key_id "$new_access_key" --profile "$profile"
            fi
          else
            while true; do
              read -p "AWS Access Key ID: " new_access_key
              if [[ -n "$new_access_key" ]]; then
                aws configure set aws_access_key_id "$new_access_key" --profile "$profile"
                break
              else
                echo "✗ Access Key ID is required"
              fi
            done
          fi
          
          # Update Secret Access Key
          if [[ -n "$current_secret_key" ]]; then
            read -p "AWS Secret Access Key (***): " new_secret_key
            if [[ -n "$new_secret_key" ]]; then
              aws configure set aws_secret_access_key "$new_secret_key" --profile "$profile"
            fi
          else
            while true; do
              read -p "AWS Secret Access Key: " new_secret_key
              if [[ -n "$new_secret_key" ]]; then
                aws configure set aws_secret_access_key "$new_secret_key" --profile "$profile"
                break
              else
                echo "✗ Secret Access Key is required"
              fi
            done
          fi
          
          # Update Default Region
          if [[ -n "$current_region" ]]; then
            read -p "Default region ($current_region): " new_region
            if [[ -n "$new_region" ]]; then
              aws configure set region "$new_region" --profile "$profile"
            fi
          else
            while true; do
              read -p "Default region: " new_region
              if [[ -n "$new_region" ]]; then
                aws configure set region "$new_region" --profile "$profile"
                break
              else
                echo "✗ Default region is required"
              fi
            done
          fi
        }
        
        # Helper function to get existing or new value
        get_existing_or_new_value() {
          local prompt="$1"
          local existing_value="$2"
          
          if [[ -n "$existing_value" ]]; then
            read -p "$prompt ($existing_value): " new_value
            
            if [[ -n "$new_value" ]]; then
              echo "$new_value"
            else
              echo "$existing_value"
            fi
          else
            while true; do
              read -p "$prompt: " new_value
              if [[ -n "$new_value" ]]; then
                echo "$new_value"
                break
              else
                echo "✗ $prompt is required"
              fi
            done
          fi
        }
        
        # ──────────────────────────────────────────────────────────────────
        # ECR Profile Management Functions
        # ──────────────────────────────────────────────────────────────────
        
        # Main ECR profile management
        setup-ecr-profiles() {
          echo "» ECR Profile Management"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Check if ECR profiles exist
          if [[ -f ~/.docker/config.json ]]; then
            existing_profiles=$(jq -r '.credHelpers // {} | to_entries[] | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null)
            
            if [[ -n "$existing_profiles" ]]; then
              echo "Existing ECR profiles:"
              echo "$existing_profiles" | while read registry helper; do
                echo "  $registry -> $helper"
              done
              echo ""
              echo "Choose action:"
              echo "1. Create new ECR profile"
              echo "2. Update existing ECR profile"
              echo "3. Remove ECR profile"
              echo "4. List all ECR profiles"
              echo "5. Test ECR profile"
              
              action_choice=""
              vared -p "Choose option (1-5): " action_choice
              
              case $action_choice in
                1)
                  setup_new_ecr_profile
                  ;;
                2)
                  update-ecr-profile
                  ;;
                3)
                  remove-ecr-profile
                  ;;
                4)
                  list-ecr-profiles
                  ;;
                5)
                  test-ecr-profile
                  ;;
                *)
                  echo "✗ Invalid option"
                  return 1
                  ;;
              esac
            else
              echo "No existing ECR profiles found"
              echo "→ Creating new ECR profile..."
              setup_new_ecr_profile
            fi
          else
            echo "No Docker config found"
            echo "→ Creating new ECR profile..."
            setup_new_ecr_profile
          fi
        }
        
        # ECR profile creation functions
        setup_new_ecr_profile() {
          echo "» Create New ECR Profile"
          
          # Get available AWS profiles
          aws_profiles=$(aws configure list-profiles)
          
          if [[ -z "$aws_profiles" ]]; then
            echo "✗ No AWS profiles found"
            echo "→ Run 'setup-aws-profile' first to create AWS profiles"
            return 1
          fi
          
          echo "Available AWS profiles:"
          echo "$aws_profiles" | sed 's/^/  /'
          echo ""
          
          # Select AWS profile
          echo "Select AWS profile:"
          local profile_array=($aws_profiles)
          for i in "${!profile_array[@]}"; do
            echo "  $((i+1)). ${profile_array[i]}"
          done
          
          selected_index=""
          vared -p "Enter selection: " selected_index
          
          if [[ -z "$selected_index" ]]; then
            echo "✗ No profile selected"
            return 1
          fi
          
          # Validate index
          if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
            echo "✗ Invalid profile selection: $selected_index"
            return 1
          fi
          
          # Convert to 0-based index
          array_index=$((selected_index-1))
          selected_profile="${profile_array[$array_index]}"
          
          echo ""
          
          # Get registry URL
          registry_url=""
          while true; do
            vared -p "Enter ECR registry URL: " registry_url
            if [[ -z "$registry_url" ]]; then
              echo "✗ Registry URL is required"
              continue
            fi
            
            # Basic validation
            if [[ ! "$registry_url" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ ]]; then
              echo "✗ Invalid ECR registry URL format"
              echo "Expected format: 123456789012.dkr.ecr.region.amazonaws.com"
              continue
            fi
            
            break
          done
          
          # Setup ECR profile
          setup-ecr-profile "$selected_profile" "$registry_url"
        }
        
        # ECR profile update functions
        update-ecr-profile() {
          echo "» Update ECR Profile"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Check if ECR profiles exist
          if [[ -f ~/.docker/config.json ]]; then
            existing_profiles=$(jq -r '.credHelpers // {} | to_entries[] | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null)
            
            if [[ -n "$existing_profiles" ]]; then
              echo "Available ECR profiles:"
              local profile_array=()
              while IFS=' -> ' read -r registry helper; do
                profile_array+=("$registry -> $helper")
              done <<< "$existing_profiles"
              
              for i in "${!profile_array[@]}"; do
                echo "  $((i+1)). ${profile_array[i]}"
              done
              
              echo ""
              echo "Select ECR profile to update:"
              selected_index=""
              vared -p "Enter selection: " selected_index
              
              if [[ -z "$selected_index" ]]; then
                echo "✗ No profile selected"
                return 1
              fi
              
              # Validate index
              if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
                echo "✗ Invalid profile selection: $selected_index"
                return 1
              fi
              
              # Convert to 0-based index
              array_index=$((selected_index-1))
              selected_profile="${profile_array[$array_index]}"
              
              # Extract registry and helper from selection
              registry_url=$(echo "$selected_profile" | cut -d' ' -f1)
              helper_name=$(echo "$selected_profile" | cut -d' ' -f3)
              aws_profile=$(echo "$helper_name" | sed 's/^ecr-login-//')
              
              echo ""
              
              # Show configurable options directly
              update_ecr_profile_direct "$registry_url" "$aws_profile"
            else
              echo "✗ No ECR profiles found"
              return 1
            fi
          else
            echo "✗ No Docker config found"
            return 1
          fi
        }
        
        # ECR profile removal functions
        remove-ecr-profile() {
          echo "» Remove ECR Profile"
          
          # Check if we're in an interactive shell
          if [[ ! -t 0 ]]; then
            echo "✗ This function requires an interactive shell"
            echo "  Please run this function directly in your terminal"
            return 1
          fi
          
          # Check if ECR profiles exist
          if [[ -f ~/.docker/config.json ]]; then
            existing_profiles=$(jq -r '.credHelpers // {} | to_entries[] | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null)
            
            if [[ -n "$existing_profiles" ]]; then
              echo "Available ECR profiles:"
              local profile_array=()
              while IFS=' -> ' read -r registry helper; do
                profile_array+=("$registry -> $helper")
              done <<< "$existing_profiles"
              
              for i in "${!profile_array[@]}"; do
                echo "  $((i+1)). ${profile_array[i]}"
              done
              
              echo ""
              echo "Select ECR profile to remove:"
              selected_index=""
              vared -p "Enter selection: " selected_index
              
              if [[ -z "$selected_index" ]]; then
                echo "✗ No profile selected"
                return 1
              fi
              
              # Validate index
              if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
                echo "✗ Invalid profile selection: $selected_index"
                return 1
              fi
              
              # Convert to 0-based index
              array_index=$((selected_index-1))
              selected_profile="${profile_array[$array_index]}"
              
              # Extract registry and helper from selection
              registry_url=$(echo "$selected_profile" | cut -d' ' -f1)
              helper_name=$(echo "$selected_profile" | cut -d' ' -f3)
              aws_profile=$(echo "$helper_name" | sed 's/^ecr-login-//')
              
              echo ""
              echo "Selected ECR profile: $selected_profile"
              echo "This will remove:"
              echo "  - ECR registry: $registry_url"
              echo "  - AWS profile: $aws_profile"
              echo "  - Binary: $helper_name"
              echo ""
              echo "Are you sure you want to remove this ECR profile?"
              echo "1. Yes, remove ECR profile"
              echo "2. No, cancel"
              
              confirm_choice=""
              vared -p "Choose option (1-2): " confirm_choice
              
              case $confirm_choice in
                1)
                  # Remove from Docker config
                  jq --arg registry "$registry_url" 'del(.credHelpers[$registry])' \
                     ~/.docker/config.json > ~/.docker/config.json.tmp && \
                  mv ~/.docker/config.json.tmp ~/.docker/config.json
                  
                  # Remove binary
                  binary_path="${XDG_DATA_HOME:-$HOME/.local/share}/bin/$helper_name"
                  if [[ -f "$binary_path" ]]; then
                    rm "$binary_path"
                  fi
                  
                  echo "✓ ECR profile removed: $registry_url"
                  ;;
                2)
                  echo "→ Removal cancelled"
                  return 0
                  ;;
                *)
                  echo "✗ Invalid option"
                  return 1
                  ;;
              esac
            else
              echo "✗ No ECR profiles found"
              return 1
            fi
          else
            echo "✗ No Docker config found"
            return 1
          fi
        }
        
        # Helper functions for ECR profile management
        list-ecr-profiles() {
          echo "» ECR Profiles"
          
          if [[ -f ~/.docker/config.json ]]; then
            existing_profiles=$(jq -r '.credHelpers // {} | to_entries[] | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null)
            
            if [[ -n "$existing_profiles" ]]; then
              echo "Available ECR profiles:"
              echo "$existing_profiles" | while read registry helper; do
                echo "  - $registry -> $helper"
              done
            else
              echo "No ECR profiles found"
            fi
          else
            echo "No Docker config found"
          fi
        }
        
        test-ecr-profile() {
          echo "» Test ECR Profile"
          
          if [[ -f ~/.docker/config.json ]]; then
            existing_profiles=$(jq -r '.credHelpers // {} | to_entries[] | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null)
            
            if [[ -n "$existing_profiles" ]]; then
              echo "Available ECR profiles:"
              local profile_array=()
              while IFS=' -> ' read -r registry helper; do
                profile_array+=("$registry -> $helper")
              done <<< "$existing_profiles"
              
              for i in "${!profile_array[@]}"; do
                echo "  $((i+1)). ${profile_array[i]}"
              done
              
              echo ""
              echo "Select ECR profile to test:"
              selected_index=""
              vared -p "Enter selection: " selected_index
              
              if [[ -z "$selected_index" ]]; then
                echo "✗ No profile selected"
                return 1
              fi
              
              # Validate index
              if [[ ! "$selected_index" =~ ^[0-9]+$ ]] || [[ $selected_index -lt 1 ]] || [[ $selected_index -gt ${#profile_array[@]} ]]; then
                echo "✗ Invalid profile selection: $selected_index"
                return 1
              fi
              
              # Convert to 0-based index
              array_index=$((selected_index-1))
              selected_profile="${profile_array[$array_index]}"
              
              # Extract registry and helper from selection
              registry_url=$(echo "$selected_profile" | cut -d' ' -f1)
              helper_name=$(echo "$selected_profile" | cut -d' ' -f3)
              aws_profile=$(echo "$helper_name" | sed 's/^ecr-login-//')
              
              echo ""
              echo "Testing ECR profile: $registry_url -> $aws_profile"
              
              # Test ECR profile
              if aws ecr get-authorization-token --profile "$aws_profile" --region "$(echo "$registry_url" | cut -d'.' -f4)" >/dev/null 2>&1; then
                echo "✓ ECR profile '$registry_url' is working"
                echo "✓ AWS profile '$aws_profile' has access to ECR"
              else
                echo "✗ ECR profile '$registry_url' is not working"
                echo "Please check your AWS profile configuration and ECR permissions"
              fi
            else
              echo "✗ No ECR profiles found"
              return 1
            fi
          else
            echo "✗ No Docker config found"
            return 1
          fi
        }
        
        # ECR profile setup helper
        setup-ecr-profile() {
          local profile_name="$1"
          local registry_url="$2"
          
          # Validate inputs
          if [[ -z "$profile_name" || -z "$registry_url" ]]; then
            echo "✗ Profile name and registry URL are required"
            return 1
          fi
          
          # Check if AWS profile exists
          if ! aws configure list-profiles | grep -q "^$profile_name$"; then
            echo "✗ AWS profile '$profile_name' does not exist"
            return 1
          fi
          
          # Create binary name and path
          binary_name="ecr-login-${profile_name}"
          binary_path="${XDG_DATA_HOME:-$HOME/.local/share}/bin/$binary_name"
          
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
            echo "⚠ jq not found. Please manually add to ~/.docker/config.json:"
            echo "  \"$registry_url\": \"$binary_name\""
          fi
        }
        
        # ECR profile update helper
        update_ecr_profile_direct() {
          local registry_url="$1"
          local current_aws_profile="$2"
          
          # Get available AWS profiles
          aws_profiles=$(aws configure list-profiles)
          
          if [[ -z "$aws_profiles" ]]; then
            echo "✗ No AWS profiles found"
            return 1
          fi
          
          # Show available AWS profiles
          echo "Available AWS profiles:"
          echo "$aws_profiles" | sed 's/^/  /'
          
          # Show current AWS profile
          read -p "AWS profile ($current_aws_profile): " new_aws_profile
          
          if [[ -n "$new_aws_profile" ]]; then
            # Check if new AWS profile exists
            if ! echo "$aws_profiles" | grep -q "^$new_aws_profile$"; then
              echo "✗ AWS profile '$new_aws_profile' does not exist"
              echo "Available profiles: $aws_profiles"
              return 1
            fi
            
            # Update ECR profile
            setup-ecr-profile "$new_aws_profile" "$registry_url"
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