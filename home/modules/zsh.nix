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
        # Initialize mise
        eval "$(mise activate zsh)"
        
        # Home Manager functions
        hm() {
          nix --extra-experimental-features 'nix-command flakes' run "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(hostname | cut -d'.' -f1)\".activationPackage"
        }

        hm-build() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(hostname | cut -d'.' -f1)\".activationPackage"
        }

        hm-check() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(hostname | cut -d'.' -f1)\".activationPackage" --dry-run
        }

        # nix-darwin functions
        darwin() {
          sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-rebuild' -- switch --flake "''${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)"
        }

        darwin-build() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(hostname | cut -d'.' -f1).system"
        }

        darwin-check() {
          nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(hostname | cut -d'.' -f1).system" --dry-run
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
      '';
    in
      lib.mkMerge [ p10kPrompt functions ];

    plugins = [
      {
        name = "powerlevel10k-config";
        src = ../p10k-config;
        file = ".p10k.zsh";
      }
    ];

    zplug = {
      enable = true;
      zplugHome = "${config.xdg.dataHome}/zplug";
      plugins = [
        {
          name = "Aloxaf/fzf-tab";
          tags = [as:plugin depth:1];
        }
        {
          name = "romkatv/powerlevel10k";
          tags = ["as:theme" "depth:1"];
        }
      ];
    };

    sessionVariables = {
      NIX_USER_CONFIG_PATH = "${config.xdg.configHome}/nix-config";
    };


    shellAliases = {
      # General Nix aliases
      nix-update = "nix --extra-experimental-features 'nix-command flakes' flake update --flake .";
      nix-gc = "nix-store --gc";
      nix-clean = "nix-collect-garbage -d";
    };
  };
}