{
  config,
  lib,
  pkgs,
  ...
}: {
  # Utility programs
  programs.gpg.enable = true;
  # programs.alacritty.enable = true;  # Removed - using WezTerm instead

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

  programs.htop = {
    enable = true;
    settings.show_program_path = true;
  };

  programs.lf.enable = true;

  programs.home-manager.enable = true;
  programs.nix-index.enable = true;

  programs.bat.enable = true;
  programs.bat.config.theme = "Nord";

  programs.zoxide.enable = true;
}
