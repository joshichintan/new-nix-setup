{ config, lib, pkgs, ... }:

{
  # Wezterm configuration
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
          "#1d2021"
          "#ea6962"
          "#a9b665"
          "#d8a657"
          "#7daea3"
          "#d3869b"
          "#89b482"
          "#d4be98"
        ];
        brights = [
          "#eddeb5"
          "#ea6962"
          "#a9b665"
          "#d8a657"
          "#7daea3"
          "#d3869b"
          "#89b482"
          "#d4be98"
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
} 