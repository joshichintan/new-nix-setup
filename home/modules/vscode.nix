{
  config,
  lib,
  pkgs,
  ...
}: {
  # VSCode configuration - manage settings only, not the package
  # This approach avoids building VSCode from source and uses system VSCode
  
  # Add VSCode CLI to PATH
  home.sessionPath = [
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  ];
  
  # VSCode settings as a file instead of using programs.vscode
  home.file."Library/Application Support/Code/User/settings.json".text = builtins.toJSON {
    editor = {
      fontFamily = "MesloLGSDZ Nerd Font, monospace";
      fontSize = 14;
      tabSize = 2;
      insertSpaces = true;
      wordWrap = "on";
      minimap.enabled = false;
      bracketPairColorization.enabled = true;
      guides.bracketPairs = true;
    };
    
    terminal = {
      integrated = {
        fontFamily = "MesloLGSDZ Nerd Font, monospace";
        fontSize = 13;
      };
    };
    
    explorer = {
      confirmDelete = false;
      confirmDragAndDrop = false;
    };
    
    git = {
      enableSmartCommit = true;
      confirmSync = false;
    };
    
    workbench = {
      colorTheme = "Gruvbox Dark Hard";
      iconTheme = "material-icon-theme";
    };
    
    extensions = {
      autoUpdate = false;
      autoCheckUpdates = true;
    };
    
    # Disable automatic updates since we're using system VSCode
    update.mode = "none";
  };
}
