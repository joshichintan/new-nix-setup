{ config, ... }:
{
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Google Chrome.app"
      "/Applications/Firefox.app"
      "/Applications/Visual Studio Code.app"
      "/Applications/Spotify.app"
    ];
  };
}
