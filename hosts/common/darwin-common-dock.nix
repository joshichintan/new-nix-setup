{config, username, ...}: {
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Google Chrome.app"
      "/Applications/IntelliJ IDEA CE.app"
      "/Applications/DataGrip.app"
      "/Users/${username}/Applications/Home Manager Apps/WezTerm.app"
      "/Applications/Cursor.app"
    ];
  };
}
