# Custom Packages
# Contains custom shell scripts and utilities
{
  imports = [
    ./aws-manager.nix
    ./ecr-manager.nix
    ./smart-ecr-helper.nix
    ./ssh-setup.nix
  ];
}