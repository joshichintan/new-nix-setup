{ config, inputs, pkgs, lib, unstablePkgs, ... }:

{
  programs.nvf = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Basic nvf configuration
    settings = {
      # Colorscheme
      colorscheme = {
        name = "gruvbox";
        background = "dark";
      };

      # Terminal detection for colorscheme
      terminal = {
        apple_terminal = {
          colorscheme = "default";
          termguicolors = false;
        };
        default = {
          colorscheme = "gruvbox";
          termguicolors = true;
        };
      };

      # Editor settings
      editor = {
        number = true;
        relativenumber = true;
        wrap = false;
        expandtab = true;
        tabstop = 2;
        shiftwidth = 2;
        ignorecase = true;
        smartcase = true;
        clipboard = "unnamedplus";
        splitright = true;
        splitbelow = true;
        swapfile = false;
      };

      # Plugins
      plugins = {
        # Essential plugins
        essential = {
          comment-nvim = { };
          lualine-nvim = { };
          nvim-web-devicons = { };
          vim-tmux-navigator = { };
        };

        # Telescope for fuzzy finding
        telescope = {
          telescope-nvim = { };
          telescope-fzf-native-nvim = { };
        };

        # Colorschemes
        colorschemes = {
          gruvbox-nvim = { };
          gruvbox-material = { };
        };
      };

      # Keymaps
      keymaps = {
        # Leader key
        leader = " ";

        # Telescope
        telescope = {
          find_files = "<leader>ff";
          oldfiles = "<leader>fr";
          live_grep = "<leader>fs";
          grep_string = "<leader>fc";
        };

        # Window management
        windows = {
          split_vertical = "<leader>sv";
          split_horizontal = "<leader>sh";
          equal_size = "<leader>se";
          close = "<leader>sx";
        };

        # Tab management
        tabs = {
          new = "<leader>to";
          close = "<leader>tx";
          next = "<leader>tn";
          previous = "<leader>tp";
          new_with_current = "<leader>tf";
        };
      };
    };
  };
} 