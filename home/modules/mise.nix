{
  config,
  lib,
  pkgs,
  ...
}: {
  # mise configuration using Home Manager's programs.mise module
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    
    # Global mise settings
    settings = {
      # Explicitly enable idiomatic version files for specific tools
      idiomatic_version_file = true;
      idiomatic_version_file_enable_tools = ["java" "node" "python" "ruby"];
      
      # Auto-install settings
      not_found_auto_install = true;  # Automatically install missing tools when detected
    };
    
    # Global configuration (config.toml)
    globalConfig = {
      settings = {
        # Must also set here for config.toml to suppress warning
        idiomatic_version_file_enable_tools = ["java" "node" "python" "ruby"];
      };
      tools = {
        # Set global Java version using Temurin distribution
        # You can also use: corretto-17, zulu-17, liberica-17, etc.
        java = "temurin-17";
        
        # Uncomment to set other global versions:
        # node = "20";
        # python = "3.11";
      };
    };
  };
}
