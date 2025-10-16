{
  config,
  lib,
  pkgs,
  ...
}: {
  # Git configuration
  programs.git = {
    enable = true;
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

  # Create the Git config file explicitly at the XDG location
  home.file."${config.xdg.configHome}/git/config".text = ''
    [init]
        defaultBranch = main
    [merge]
        conflictStyle = diff3
        tool = meld
    [pull]
        rebase = true
  '';

  # Set GIT_CONFIG_GLOBAL to use XDG location
  home.sessionVariables = {
    GIT_CONFIG_GLOBAL = "${config.xdg.configHome}/git/config";
  };
}
