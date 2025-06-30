{
  config,
  inputs,
  pkgs,
  lib,
  username,
  unstablePkgs,
  ...
}: {
  # Basic home configuration
  home.stateVersion = "23.11";
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # File configurations
  home.file = {
    # Aerospace configuration
    "${config.xdg.configHome}/aerospace/aerospace.toml".text = builtins.readFile ./aerospace/aerospace.toml;

    # Disable default .zshrc since we're using custom config
    ".zshrc".enable = false;
  };

  # Session variables
  home.sessionVariables = {
    VSCODE_EXTENSIONS = "${config.xdg.dataHome}/vscode/extensions";
  };

  # allow home-manager to manager itself
  programs.home-manager.enable = true;

  # Nixpkgs configuration
  nixpkgs = {
    config.allowUnfree = true;
  };

  # Enable XDG base directories
  xdg.enable = true;

  # Import all modular configurations
  imports = [
    ./modules
  ];
}
