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
      # Home Manager aliases (dynamic user/hostname detection)
      hm = "nix run \${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\$(whoami)@\$(hostname | cut -d'.' -f1).activationPackage";
      # hm-build = "nix build ''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.''$(whoami)@''$(hostname | cut -d'.' -f1).activationPackage";
      # hm-check = "nix build ''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.''$(whoami)@''$(hostname | cut -d'.' -f1).activationPackage --dry-run";

      # nix-darwin aliases (dynamic hostname detection)
      # darwin = "sudo nix run nix-darwin#darwin-rebuild -- switch --flake ''${NIX_USER_CONFIG_PATH:-.}#''$(hostname | cut -d'.' -f1)";
      # darwin-build = "nix build ''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.''$(hostname | cut -d'.' -f1).system";
      # darwin-check = "nix build ''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.''$(hostname | cut -d'.' -f1).system --dry-run";

      # General Nix aliases
      nix-update = "nix flake update";
      nix-gc = "nix-store --gc";
      nix-clean = "nix-collect-garbage -d";

      # Quick rebuild aliases
      rebuild = "darwin && hm"; # Rebuild both system and home
      rebuild-home = "hm"; # Rebuild only home
      rebuild-system = "darwin"; # Rebuild only system
    };
  };
}
