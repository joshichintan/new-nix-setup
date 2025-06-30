{
  config,
  lib,
  pkgs,
  ...
}: {
  # Starship prompt configuration
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    # Starship configuration
    settings = {
      add_newline = false;

      # Character configuration
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
        vicmd_symbol = "[❮](bold green)";
      };

      # Directory configuration
      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        home_symbol = "~";
      };

      # Git configuration
      git_branch = {
        symbol = " ";
        style = "bold purple";
      };

      git_status = {
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?";
        stashed = "≡";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      # Node.js configuration
      nodejs = {
        symbol = " ";
        style = "bold green";
      };

      # Python configuration
      python = {
        symbol = " ";
        style = "bold yellow";
      };

      # Rust configuration
      rust = {
        symbol = " ";
        style = "bold red";
      };

      # Go configuration
      golang = {
        symbol = " ";
        style = "bold cyan";
      };
    };
  };
}
