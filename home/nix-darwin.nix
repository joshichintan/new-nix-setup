{ config, inputs, pkgs, lib, unstablePkgs, ... }:
{
  home.stateVersion = "23.11";

  # list of programs
  # https://mipmip.github.io/home-manager-option-search

  # aerospace config
  home.file.".config/aerospace/aerospace.toml".text = builtins.readFile ./aerospace/aerospace.toml;

  xdg.enable = true;
  # self.environment.etc."zshenv".text = ''
  #     source ${config.xdg.configHome}/zsh/.zshenv
  #   '';

  programs.gpg.enable = true;
  programs.alacritty.enable = true;
  home.sessionVariables = {
    VSCODE_EXTENSIONS = "${config.xdg.dataHome}/vscode/extensions";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
      "--color=auto"
    ];
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
    defaultOptions = [
      "--no-mouse"
    ];
  };

  programs.git = {
    enable = true;
    userEmail = "chintanjoshi2012@gmail.com";
    userName = "Chintan Joshi";
    diff-so-fancy.enable = true;
    lfs.enable = true;
    extraConfig = {
      init = {
        defaultBranch = "main";
      };
      merge = {
        conflictStyle = "diff3";
        tool = "meld";
      };
      pull = {
        rebase = true;
      };
    };
  };

  programs.htop = {
    enable = true;
    settings.show_program_path = true;
  };

  programs.lf.enable = true;

  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   enableBashIntegration = true;
  #   settings = pkgs.lib.importTOML ./starship/starship.toml;
  # };

  home.file.".zshrc".enable = false;
  # home.file.".zshenv".enable = false;
  programs.zsh = {

    enable = true;
    dotDir = ".config/zsh";
    history = {
      path = "$ZDOTDIR/.zsh_history";
      append = true;
      saveNoDups = true;
      ignoreAllDups = true;
      findNoDups = true;
    };

    historySubstringSearch = {
      enable = true;
      searchUpKey = [ "^k" ];
      searchDownKey = [ "^j" ];
    };
    # enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = 
    let 
      p10kInstantPrompt = lib.mkOrder 500 ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; 
      then source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"; fi
      '';
    in
    lib.mkMerge[ p10kInstantPrompt ];
    plugins = [
    {
      name = "powerlevel10k-config";
      src = ./p10k-config;
      file = ".p10k.zsh";
    }
    ];
    zplug = {
      enable = true;
      zplugHome = "${config.xdg.dataHome}/zplug";
      plugins = [
        { name = "Aloxaf/fzf-tab"; tags = [ as:plugin depth:1 ];}
        { name = "romkatv/powerlevel10k"; tags = [ "as:theme" "depth:1" ];}
      ];
    };
  };

  programs.tmux = {
    enable = true;
    #keyMode = "vi";
    clock24 = true;
    historyLimit = 10000;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = gruvbox;
        extraConfig = "set -g @gruvbox 'dark'";
      }
      vim-tmux-navigator
      {
        plugin = tmux-sessionx;
      }
    ];
    
    extraConfig = '' 
      new-session -s main
      bind-key -n C-a send-prefix
      bind-key o run-shell "tmux-sessionx"
    '';
  };

  programs.home-manager.enable = true;
  programs.nix-index.enable = true;

  programs.bat.enable = true;
  programs.bat.config.theme = "Nord";

  programs.wezterm = {
    enable = true;
    # enableTabBar = false;

    colorSchemes = {
        gruvbox_material_dark_hard = {
          foreground = "#D4BE98";
          background = "#1D2021";
          cursor_bg = "#D4BE98";
          cursor_border = "#D4BE98";
          cursor_fg = "#1D2021";
          selection_bg = "#D4BE98";
          selection_fg = "#3C3836";
          ansi = [
            "#1d2021" "#ea6962" "#a9b665" "#d8a657"
            "#7daea3" "#d3869b" "#89b482" "#d4be98"
          ];
          brights = [
            "#eddeb5" "#ea6962" "#a9b665" "#d8a657"
            "#7daea3" "#d3869b" "#89b482" "#d4be98"
          ];
        };
      };

    # Add only the minimal custom Lua config required
    extraConfig = ''
      local wezterm = require("wezterm")
      local config = wezterm.config_builder()

      config.enable_tab_bar = false
      config.font = wezterm.font("MesloLGS Nerd Font")
      config.font_size = 13
      config.enable_tab_bar = false
      config.window_decorations = "RESIZE"

      config.colorScheme = "GruvboxHardDark"

      -- macOS-specific visual polish
      config.macos_window_background_blur = 10

      return config
    '';
  };

  #programs.zsh.shellAliases.cat = "${pkgs.bat}/bin/bat";

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      ## regular
      comment-nvim
      lualine-nvim
      nvim-web-devicons
      vim-tmux-navigator
      {
        plugin = gruvbox-nvim;
        config = "colorscheme gruvbox";
      }

      ## telescope
      {
        plugin = telescope-nvim;
        type = "lua";
        config = builtins.readFile ./nvim/plugins/telescope.lua;
      }
      telescope-fzf-native-nvim

    ];
    extraLuaConfig = ''
      ${builtins.readFile ./nvim/options.lua}
      ${builtins.readFile ./nvim/keymap.lua}
    '';
  };

  programs.zoxide.enable = true;
  programs.vscode = {
    enable = true;
    profiles.default.userSettings = {
      editor.fontFamily = "MesloLGSDZ Nerd Font, monospace";
    };
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
  StrictHostKeyChecking no
    '';
    matchBlocks = {
      # ~/.ssh/config
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
      };
      "*" = {
        user = "root";
      };
      # wd
      "dev" = {
        hostname = "100.68.216.79";
        user = "alex";
      };
      # lancs
      # "e elrond" = {
      #   hostname = "100.117.223.78";
      #   user = "alexktz";
      # };
      # # jb
      # "core" = {
      #   hostname = "demo.selfhosted.show";
      #   user = "ironicbadger";
      #   port = 53142;
      # };
      # "status" = {
      #   hostname = "hc.ktz.cloud";
      #   user = "ironicbadger";
      #   port = 53142;
      # };
    };
  };
}
