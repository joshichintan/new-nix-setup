{ config, ... }:
{
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Firefox.app"
      "/Applications/Visual Studio Code.app"
    ];
  };
}