{ config, lib, pkgs, ... }:

{
  # Tmux configuration
  programs.tmux = {
    enable = true;
    #keyMode = "vi";
    clock24 = true;
    historyLimit = 10000;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = gruvbox;
        # extraConfig = "set -g @gruvbox 'dark'";
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
} 