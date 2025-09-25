{
  config,
  lib,
  pkgs,
  ...
}: {
  # Zsh configuration
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh"; # make sure xdg.enable = true; in home config for this to work.
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
      p10kInstantPrompt = lib.mkOrder 500 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]];
        then source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"; fi
      '';
    in
      lib.mkMerge [p10kInstantPrompt];

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

    shellAliases = {
      # General Nix aliases
  nix-update = "nix --extra-experimental-features 'nix-command flakes' flake update --flake .";
      nix-gc = "nix-store --gc";
      nix-clean = "nix-collect-garbage -d";
    };

    # Functions for dynamic user/hostname detection
    initExtra = ''
      # Home Manager functions
      hm() {
        local user="$(whoami)"
        local host="$(hostname | cut -d'.' -f1)"
        local flake_ref=".#homeConfigurations.\"$user@$host\".activationPackage"
        nix --extra-experimental-features 'nix-command flakes' run "$flake_ref"
      }

      hm-build() {
        local user="$(whoami)"
        local host="$(hostname | cut -d'.' -f1)"
        local flake_ref=".#homeConfigurations.\"$user@$host\".activationPackage"
        nix --extra-experimental-features 'nix-command flakes' build "$flake_ref"
      }

      hm-check() {
        local user="$(whoami)"
        local host="$(hostname | cut -d'.' -f1)"
        local flake_ref=".#homeConfigurations.\"$user@$host\".activationPackage"
        nix --extra-experimental-features 'nix-command flakes' build "$flake_ref" --dry-run
      }

      # nix-darwin functions
      darwin() {
        local host="$(hostname | cut -d'.' -f1)"
        local flake_ref=".#$host"
        nix --extra-experimental-features 'nix-command flakes' run nix-darwin#darwin-rebuild -- switch --flake "$flake_ref"
      }

      darwin-build() {
        local host="$(hostname | cut -d'.' -f1)"
        local flake_ref=".#darwinConfigurations.$host.system"
        nix --extra-experimental-features 'nix-command flakes' build "$flake_ref"
      }

      darwin-check() {
        local host="$(hostname | cut -d'.' -f1)"
        local flake_ref=".#darwinConfigurations.$host.system"
        nix --extra-experimental-features 'nix-command flakes' build "$flake_ref" --dry-run
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
  };
}