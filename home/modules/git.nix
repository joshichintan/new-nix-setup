{
  config,
  lib,
  pkgs,
  ...
}: {
  # Git configuration
  programs.git = {
    enable = true;
    # userEmail = "chintanjoshi2012@gmail.com";  # Remove this - managed by dev tools
    # userName = "Chintan Joshi";                # Remove this - managed by dev tools
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
}
