{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: {
  # Zsh configuration
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh"; # make sure xdg.enable = true; in home config for this to work.
    history = {
      path = "${config.programs.zsh.dotDir}/history/.zsh_history";
      append = true;
      saveNoDups = true;
      ignoreAllDups = true;
      findNoDups = true;
      share = true;
    };

    historySubstringSearch = {
      enable = true;
      searchUpKey = ["^k"];
      searchDownKey = ["^j"];
    };
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
    syntaxHighlighting.enable = true;

    # Antidote plugin manager configuration
    # Using antidote instead of oh-my-zsh for better performance
    antidote = {
      enable = true;
      plugins = [
        # Load the use-omz plugin to handle Oh My Zsh dependencies
        "getantidote/use-omz"
        
        # Deferred loading plugin
        "romkatv/zsh-defer"
        
        # Load Oh My Zsh's library
        "ohmyzsh/ohmyzsh path:lib"
        
        # Core productivity utilities
        "ohmyzsh/ohmyzsh path:plugins/aliases"
        "ohmyzsh/ohmyzsh path:plugins/colored-man-pages"
        "ohmyzsh/ohmyzsh path:plugins/z"
        
        # AI and search plugins
        # "HundredAcreStudio/zsh-claude"
        # "muePatrick/zsh-ai-commands"  # Temporarily disabled - requires API key setup
        # To enable zsh-ai-commands:
        # 1. Set ZSH_AI_COMMANDS_OPENAI_API_KEY in sessionVariables below
        # 2. Uncomment the line above
        # 3. Run: nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(scutil --get LocalHostName).activationPackage
        
        # Essential tools (keep for aliases, fzf-tab handles completions)
        "ohmyzsh/ohmyzsh path:plugins/aws"
        "ohmyzsh/ohmyzsh path:plugins/postgres"
        "ohmyzsh/ohmyzsh path:plugins/terraform"
        "ohmyzsh/ohmyzsh path:plugins/vault"
        
        # Git & productivity (keep for aliases, fzf-tab handles completions)
        "ohmyzsh/ohmyzsh path:plugins/git"
        "ohmyzsh/ohmyzsh path:plugins/tmux"
        "ohmyzsh/ohmyzsh path:plugins/zoxide"
        
        # Custom completion plugins (deferred loading)
        # These will be loaded on-demand when the commands are first used
        "${config.programs.zsh.dotDir}/plugins/aws-manager"
        "${config.programs.zsh.dotDir}/plugins/ecr-manager"
        "${config.programs.zsh.dotDir}/plugins/ssh-setup"
      ];
    };

    initContent = let
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 0: Performance Profiling (DISABLED)
      # ══════════════════════════════════════════════════════════════════════
      # profiling = lib.mkOrder 0 ''
      #   # Load zsh profiling module for startup performance analysis
      #   zmodload zsh/zprof
      # '';

      # ══════════════════════════════════════════════════════════════════════
      # SECTION 1: Powerlevel10k Instant Prompt
      # ══════════════════════════════════════════════════════════════════════
      p10kPrompt = lib.mkOrder 500 ''
        if [[ -r "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
        
        # Source Powerlevel10k configuration if it exists
        if [[ -r "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh" ]]; then
          source "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh"
        fi
      '';
      
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 2: Environment Setup and PATH Configuration
      # ══════════════════════════════════════════════════════════════════════
      environment = lib.mkOrder 1000 ''
        # PATH Configuration
        export PATH="$HOME/.rd/bin:$PATH"
        
        # Homebrew environment (ARM64)
        # NOTE: This must match nix-homebrew.enableRosetta = false in lib/helpers.nix
        # If you change enableRosetta, update this path accordingly:
        # - enableRosetta = false -> /opt/homebrew (ARM64)
        # - enableRosetta = true  -> /usr/local (Intel/Rosetta)
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '';

      # SECTION 3: Deferred Loading for Custom Plugins
      # ══════════════════════════════════════════════════════════════════════
      deferredPlugins = lib.mkOrder 2000 ''
        # Defer loading of custom plugins until they're actually needed
        # This improves shell startup performance
        
        # AWS Manager - load when aws-mgr command is used
        if command -v aws-mgr >/dev/null 2>&1; then
          zsh-defer source "${config.programs.zsh.dotDir}/plugins/aws-manager/aws-manager.plugin.zsh"
        fi
        
        # ECR Manager - load when ecr-mgr command is used
        if command -v ecr-mgr >/dev/null 2>&1; then
          zsh-defer source "${config.programs.zsh.dotDir}/plugins/ecr-manager/ecr-manager.plugin.zsh"
        fi
        
        # SSH Setup - load when ssh-setup command is used
        if command -v ssh-setup >/dev/null 2>&1; then
          zsh-defer source "${config.programs.zsh.dotDir}/plugins/ssh-setup/ssh-setup.plugin.zsh"
        fi
        
        # ══════════════════════════════════════════════════════════════════════
        # COMPLETION STRATEGY FOR TOOLS
        # ══════════════════════════════════════════════════════════════════════
        # 
        # PRIORITY ORDER FOR COMPLETIONS:
        # 1. NATIVE COMPLETIONS FIRST - Use `tool completion zsh` if available
        # 2. ANTIDOTE PLUGINS SECOND - Use plugins for tools without native completions
        # 
        # HOW TO ADD NEW TOOL COMPLETIONS:
        # 1. If no native completion, search for Antidote plugins and add to plugins list
        # 2. Add completion loading for tools that don't have the completion command
        #
        # FALLBACK STRATEGY:
        # Don't add anything if completion is not available
        # ══════════════════════════════════════════════════════════════════════
        
        # K9s completion - load automatically if k9s exists
        if command -v k9s >/dev/null 2>&1; then
          source <(k9s completion zsh)
        fi
        
        # Kubectl completion - load automatically if kubectl exists
        if command -v kubectl >/dev/null 2>&1; then
          source <(kubectl completion zsh)
        fi
        
        # Helm completion - load automatically if helm exists
        if command -v helm >/dev/null 2>&1; then
          source <(helm completion zsh)
        fi
        
        # Rancher Desktop CLI completion - load automatically if rdctl exists
        if command -v rdctl >/dev/null 2>&1; then
          source <(rdctl completion zsh)
        fi
        
        # Docker completion - try native first, fall back to Oh My Zsh plugin
        if command -v docker >/dev/null 2>&1; then
          # Try native completion first
          if docker completion zsh >/dev/null 2>&1; then
            source <(docker completion zsh)
          fi
          # Oh My Zsh docker plugin is already loaded above for aliases
        fi
        
        # 1Password CLI completion - load automatically if op exists
        if command -v op >/dev/null 2>&1; then
          source <(op completion zsh)
        fi
        
        # ══════════════════════════════════════════════════════════════════════
        # CUSTOM SCRIPTS DIRECTORY
        # ══════════════════════════════════════════════════════════════════════
        # Auto-source all .sh files from custom-scripts directory
        # This directory is NOT managed by Home Manager - add your own scripts here
        
        # Create custom-scripts directory if it doesn't exist
        CUSTOM_SCRIPTS_DIR="${config.programs.zsh.dotDir}/custom-scripts"
        if [[ ! -d "$CUSTOM_SCRIPTS_DIR" ]]; then
          mkdir -p "$CUSTOM_SCRIPTS_DIR"
          echo "Created custom scripts directory: $CUSTOM_SCRIPTS_DIR"
        fi
        
        # Source all .sh files from custom-scripts directory
        if [[ -d "$CUSTOM_SCRIPTS_DIR" ]]; then
          # Use nullglob to handle empty directory gracefully
          setopt nullglob 2>/dev/null || true
          for script in "$CUSTOM_SCRIPTS_DIR"/*.sh; do
            if [[ -f "$script" && -r "$script" ]]; then
              # Skip files starting with . or _ (hidden/system files)
              if [[ "$(basename "$script")" =~ ^[^._] ]]; then
                source "$script"
              fi
            fi
          done
          # Reset nullglob
          unsetopt nullglob 2>/dev/null || true
        fi
        # ══════════════════════════════════════════════════════════════════════
      '';

      # ══════════════════════════════════════════════════════════════════════
      # SECTION 5: Performance Profiling Output (DISABLED)
      # ══════════════════════════════════════════════════════════════════════
      # profilingOutput = lib.mkOrder 9999 ''
      #   # Display profiling results at the end of startup
      #   zprof
      # '';
    in
      lib.mkMerge [ p10kPrompt environment deferredPlugins ];

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
      ZSH_COMPDUMP = "${config.xdg.cacheHome}/zsh/.zcompdump-${hostname}";
      ZSH_AI_COMMANDS_OPENAI_API_KEY = "";
      # POWERLEVEL9K_CONFIG_FILE = "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh"; # enable this when p10k merges mise config
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
    };
  };
}