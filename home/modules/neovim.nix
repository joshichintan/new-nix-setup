{ config, inputs, pkgs, lib, unstablePkgs, ... }:

{
  # nvf - Modern Neovim configuration
  programs.nvf = {
    enable = true;

    settings.vim = {
      # Aliases
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      # Theme configuration (matching your current setup)
      theme = {
        enable = true;
        name = "gruvbox-material";
        style = "dark";
      };

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

      # Keymaps (converted from keymap.lua)
      keymaps = {
        # Leader key
        leader = " ";
        
        # Insert mode
        insert = {
          "jk" = "<ESC>";  # Exit insert mode with jk
        };
        
        # Normal mode
        normal = {
          "<leader>nh" = ":nohl<CR>";  # Clear search highlights
          
          # Telescope
          "<leader>ff" = "<cmd>Telescope find_files<cr>";  # Fuzzy find files
          "<leader>fr" = "<cmd>Telescope oldfiles<cr>";    # Fuzzy find recent files
          "<leader>fs" = "<cmd>Telescope live_grep<cr>";   # Find string in cwd
          "<leader>fc" = "<cmd>Telescope grep_string<cr>"; # Find string under cursor
          "<leader>ft" = "<cmd>TodoTelescope<cr>";         # Find todos
          
          # Window management
          "<leader>sv" = "<C-w>v";     # Split window vertically
          "<leader>sh" = "<C-w>s";     # Split window horizontally
          "<leader>se" = "<C-w>=";     # Make splits equal size
          "<leader>sx" = "<cmd>close<CR>"; # Close current split
          
          # Tab management
          "<leader>to" = "<cmd>tabnew<CR>";      # Open new tab
          "<leader>tx" = "<cmd>tabclose<CR>";    # Close current tab
          "<leader>tn" = "<cmd>tabn<CR>";        # Go to next tab
          "<leader>tp" = "<cmd>tabp<CR>";        # Go to previous tab
          "<leader>tf" = "<cmd>tabnew %<CR>";    # Open current buffer in new tab
        };
      };

      # Plugins (converted from your current setup)
      extraPlugins = {
        # Your existing plugins
        comment-nvim = pkgs.vimPlugins.comment-nvim;
        lualine-nvim = pkgs.vimPlugins.lualine-nvim;
        nvim-web-devicons = pkgs.vimPlugins.nvim-web-devicons;
        vim-tmux-navigator = pkgs.vimPlugins.vim-tmux-navigator;
        gruvbox-nvim = pkgs.vimPlugins.gruvbox-nvim;
        gruvbox-material = pkgs.vimPlugins.gruvbox-material;
        telescope-nvim = pkgs.vimPlugins.telescope-nvim;
        telescope-fzf-native-nvim = pkgs.vimPlugins.telescope-fzf-native-nvim;
      };

      # Telescope configuration (converted from telescope.lua)
      telescope = {
        enable = true;
        extensions = {
          fzf = {
            enable = true;
            fuzzy = true;
            override_generic_sorter = true;
            override_file_sorter = true;
            case_mode = "smart_case";
          };
        };
      };

      # Custom Lua configuration (only for terminal detection)
      lua = {
        pre = ''
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
  };
} 