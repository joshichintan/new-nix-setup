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
        export PATH="${config.home.homeDirectory}/.rd/bin:$PATH"
        
        # ──────────────────────────────────────────────────────────────────
        # AWS SSO Token Check
        # ──────────────────────────────────────────────────────────────────
        check_aws_sso_tokens() {
          # Only check if AWS CLI is available
          if ! command -v aws >/dev/null 2>&1; then
            return 0
          fi
          
          # Check if AWS config exists
          if [[ ! -f "${config.home.homeDirectory}/.aws/config" ]]; then
            return 0
          fi
          
          # Get list of SSO sessions
          local sessions
          sessions=$(grep '^\[sso-session ' "${config.home.homeDirectory}/.aws/config" 2>/dev/null | sed 's/^\[sso-session //' | sed 's/\]$//' | sort)
          
          if [[ -z "$sessions" ]]; then
            return 0
          fi
          
          # Check if any session has valid token
          local has_valid=false
          local aws_cache_dir="$HOME/.aws/sso/cache"
          
          if [[ -d "$aws_cache_dir" ]]; then
            for session in $sessions; do
              # Get session details
              local start_url region
              start_url=$(grep -A 10 "^\[sso-session $session\]" "$HOME/.aws/config" 2>/dev/null | grep 'sso_start_url' | cut -d'=' -f2 | tr -d ' ')
              region=$(grep -A 10 "^\[sso-session $session\]" "$HOME/.aws/config" 2>/dev/null | grep 'sso_region' | cut -d'=' -f2 | tr -d ' ')
              
              if [[ -n "$start_url" && -n "$region" ]]; then
                # Check for valid token
                for cache_file in "$aws_cache_dir"/*.json; do
                  if [[ -f "$cache_file" ]]; then
                    if jq -e --arg url "$start_url" --arg reg "$region" '
                      select(.accessToken and .expiresAt and .startUrl==$url and .region==$reg) |
                      select((.expiresAt | fromdateiso8601) > now)
                    ' "$cache_file" >/dev/null 2>&1; then
                      has_valid=true
                      break 2
                    fi
                  fi
                done
              fi
            done
          fi
          
          # Show message only if no valid tokens found and not during initialization
          if [[ "$has_valid" == "false" && -z "$P10K_INITIALIZATION_COMPLETE" ]]; then
            echo "⚠ No active AWS SSO sessions"
          fi
        }
        
        # ──────────────────────────────────────────────────────────────────
        # mise Hooks (Runtime Version Manager)
        # ──────────────────────────────────────────────────────────────────
        # Note: mise is automatically activated via programs.mise.enableZshIntegration
        # which sets up automatic environment activation via its own precmd hook
        
        autoload -U add-zsh-hook
        
        # Install missing tools and display if installed
        typeset -g P10K_INITIALIZATION_COMPLETE=1
        mise_precmd() {
          # Skip first run to avoid p10k instant prompt interference
          if [[ $P10K_INITIALIZATION_COMPLETE -eq 1 ]]; then
            P10K_INITIALIZATION_COMPLETE=0
            # Check AWS SSO tokens on first run (shell startup)
            check_aws_sso_tokens
            return
          fi
          
          if mise ls --current &>/dev/null && [[ -n "$(mise ls --current 2>/dev/null)" ]]; then
            if mise ls --current --json 2>/dev/null | grep -q '"installed": false'; then
              echo "» Installing missing tools..."
              mise install
            fi
          fi
        }
        add-zsh-hook precmd mise_precmd
        
        # ──────────────────────────────────────────────────────────────────
        # Source Shell Utilities
        # ──────────────────────────────────────────────────────────────────
        if [[ -f "${config.xdg.configHome}/zsh/shell-utils.sh" ]]; then
          source "${config.xdg.configHome}/zsh/shell-utils.sh"
        fi
        
        # Source Dev Tools
        if [[ -f "${config.xdg.configHome}/zsh/dev-tools.sh" ]]; then
          source "${config.xdg.configHome}/zsh/dev-tools.sh"
        fi
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

    # Enable  CLI completion
    enableCompletion = true;

    sessionVariables = {
      NIX_USER_CONFIG_PATH = "${config.xdg.configHome}/nix-config";
    };


    shellAliases = {
      # General Nix aliases
      nix-update = "nix --extra-experimental-features 'nix-command flakes' flake update --flake .";
      nix-gc = "nix-store --gc";
      nix-clean = "nix-collect-garbage -d";
      
      # Mise aliases
      mise-reload = "mise_auto_activate";
      
      # AWS aliases
      aws-check = "check_aws_sso_tokens";
      
      # Config editing aliases
      nix-config = "nvim $NIX_USER_CONFIG_PATH";
      
      # Core utilities (functions are available directly)
      # hm, darwin, reload, nix-gc, nix-clean are available as functions
      
      # Dev tools (functions are available directly)
      # git-setup and ssh-setup are available as functions
    };
  };
}