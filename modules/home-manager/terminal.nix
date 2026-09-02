{
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.enable) {
    programs.ghostty = {
      enable = true;
      package = cfg.shell.terminalPackage;
      settings = {
        font-family = "JetBrainsMono Nerd Font";
        window-decoration = false;
        # Live file owned by omarchy-theme-set (not a Home Manager symlink).
        theme = "omarchy";
      };
    };
  };
}
