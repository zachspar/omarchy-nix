{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  themeTools = pkgs.callPackage ../../pkgs/omarchy-theme-tools { };
in
{
  config = lib.mkIf (cfg.enable && cfg.theme.enable) {
    environment.systemPackages = [
      themeTools
      pkgs.yaru-theme
      pkgs.gnome-themes-extra
      pkgs.adwaita-icon-theme
      pkgs.gsettings-desktop-schemas
    ];

    environment.sessionVariables.OMARCHY_THEME = cfg.theme.name;

    # TODO: Chromium managed-policy theming. Official packs do not ship
    # chromium.theme (it is generated from a template); applying it needs
    # root write to /etc/chromium/policies/managed, which we are not adding.
    # Neovim and btop retint from omarchy-theme-set (Home Manager neovim.lua
    # loader + btop current.theme symlink).
  };
}
