{
  config,
  inputs,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  # nvf - Modern Neovim configuration
  programs.nvf = {
    enable = true;

    settings.vim = {
      # Aliases
      viAlias = true;
      vimAlias = true;

      # Editor options (converted from options.lua)
      options = {
        # Basic display
        number = true;
        relativenumber = true;
        wrap = false;

        # Indentation
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        autoindent = true;

        # Search
        ignorecase = true;
        smartcase = true;

        # Colors
        background = "dark";
        signcolumn = "yes";

        # Backspace
        backspace = "indent,eol,start";

        # Clipboard
        clipboard = "unnamedplus";

        # Window splits
        splitright = true;
        splitbelow = true;

        # Files
        swapfile = false;

        # Mouse
        mouse = "a";
      };

      # Keymaps using proper nvf syntax
      keymaps = [
        # Insert mode - exit with jk
        {
          key = "jk";
          mode = "i";
          action = "<ESC>";
        }
        
        # Normal mode keymaps
        {
          key = "<leader>nh";
          mode = "n";
          action = ":nohl<CR>";
        }
        
        # Telescope keymaps
        {
          key = "<leader>ff";
          mode = "n";
          action = "<cmd>Telescope find_files<cr>";
        }
        {
          key = "<leader>fr";
          mode = "n";
          action = "<cmd>Telescope oldfiles<cr>";
        }
        {
          key = "<leader>fs";
          mode = "n";
          action = "<cmd>Telescope live_grep<cr>";
        }
        {
          key = "<leader>fc";
          mode = "n";
          action = "<cmd>Telescope grep_string<cr>";
        }
        {
          key = "<leader>ft";
          mode = "n";
          action = "<cmd>TodoTelescope<cr>";
        }
        
        # Window management
        {
          key = "<leader>sv";
          mode = "n";
          action = "<C-w>v";
        }
        {
          key = "<leader>sh";
          mode = "n";
          action = "<C-w>s";
        }
        {
          key = "<leader>se";
          mode = "n";
          action = "<C-w>=";
        }
        {
          key = "<leader>sx";
          mode = "n";
          action = "<cmd>close<CR>";
        }
        
        # Tab management
        {
          key = "<leader>to";
          mode = "n";
          action = "<cmd>tabnew<CR>";
        }
        {
          key = "<leader>tx";
          mode = "n";
          action = "<cmd>tabclose<CR>";
        }
        {
          key = "<leader>tn";
          mode = "n";
          action = "<cmd>tabn<CR>";
        }
        {
          key = "<leader>tp";
          mode = "n";
          action = "<cmd>tabp<CR>";
        }
        {
          key = "<leader>tf";
          mode = "n";
          action = "<cmd>tabnew %<CR>";
        }
      ];

    statusline.lualine = {
      enable = true;
    };

    autocomplete.nvim-cmp.enable = true;

    languages = {
      enableLSP = true;
      enableTreesitter = true;

      python.enable = true;
    };

      # Plugins (converted from your current setup)
    extraPlugins = {
      #   # Your existing plugins
      #   comment-nvim = pkgs.vimPlugins.comment-nvim;
      #   lualine-nvim = pkgs.vimPlugins.lualine-nvim;
      #   nvim-web-devicons = pkgs.vimPlugins.nvim-web-devicons;
      #   vim-tmux-navigator = pkgs.vimPlugins.vim-tmux-navigator;
        gruvbox-nvim = pkgs.vimPlugins.gruvbox-nvim;
        gruvbox-material = pkgs.vimPlugins.gruvbox-material;
      #   telescope-nvim = pkgs.vimPlugins.telescope-nvim;
      #   telescope-fzf-native-nvim = pkgs.vimPlugins.telescope-fzf-native-nvim;
    };

      # Custom Lua configuration (only for terminal detection)
      luaConfigRC.themeSetup = ''
        -- Terminal-specific colorscheme and termguicolors
        if vim.env.TERM_PROGRAM == "Apple_Terminal" then
          vim.opt.termguicolors = false
          vim.cmd("colorscheme gruvbox-material")
        else
          vim.opt.termguicolors = true
          vim.cmd("colorscheme gruvbox")
        end
      '';
    };
  };
}
