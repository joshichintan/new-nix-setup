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
        "HundredAcreStudio/zsh-claude"
        "muePatrick/zsh-ai-commands"
        
        # Essential tools (keep for aliases, fzf-tab handles completions)
        "ohmyzsh/ohmyzsh path:plugins/aws"
        "ohmyzsh/ohmyzsh path:plugins/docker"
        "ohmyzsh/ohmyzsh path:plugins/helm"
        "ohmyzsh/ohmyzsh path:plugins/kubectl"
        "ohmyzsh/ohmyzsh path:plugins/postgres"
        "ohmyzsh/ohmyzsh path:plugins/terraform"
        "ohmyzsh/ohmyzsh path:plugins/vault"
        
        # Git & productivity (keep for aliases, fzf-tab handles completions)
        "ohmyzsh/ohmyzsh path:plugins/git"
        "ohmyzsh/ohmyzsh path:plugins/tmux"
        "ohmyzsh/ohmyzsh path:plugins/zoxide"
        
        # Custom completion plugins (deferred loading)
        # These will be loaded on-demand when the commands are first used
        "${config.programs.zsh.dotDir}/plugins/aws-context"
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
        
        # AWS Context - load when aws-context command is used
        if command -v aws-context >/dev/null 2>&1; then
          zsh-defer source "${config.programs.zsh.dotDir}/plugins/aws-context/aws-context.plugin.zsh"
        fi
        
        # ECR Manager - load when ecr-mgr command is used
        if command -v ecr-mgr >/dev/null 2>&1; then
          zsh-defer source "${config.programs.zsh.dotDir}/plugins/ecr-manager/ecr-manager.plugin.zsh"
        fi
        
        # SSH Setup - load when ssh-setup command is used
        if command -v ssh-setup >/dev/null 2>&1; then
          zsh-defer source "${config.programs.zsh.dotDir}/plugins/ssh-setup/ssh-setup.plugin.zsh"
        fi
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