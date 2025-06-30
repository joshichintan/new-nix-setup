{
  config,
  lib,
  pkgs,
  ...
}: {
  # VSCode configuration
  programs.vscode = {
    enable = true;
    profiles.default.userSettings = {
      editor.fontFamily = "MesloLGSDZ Nerd Font, monospace";
    };
  };
}
