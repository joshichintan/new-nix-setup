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
    # Using antidote instead of oh-my-zsh for better performance and plugin management
    antidote = {
      enable = true;
      useFriendlyNames = true;
      pluginsFile = "${config.xdg.configHome}/zsh/.zsh_plugins.txt";
    };

    initContent = let
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
    in
      lib.mkMerge [ p10kPrompt environment ];

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
      ZSH_CUSTOM = "${config.programs.zsh.dotDir}/custom";
      ANTIDOTE_HOME = "${config.xdg.dataHome}/antidote";
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

  # Add the antidote plugins file
  home.file."${config.xdg.configHome}/zsh/.zsh_plugins.txt" = {
    source = ../.zsh_plugins.txt;
  };
}