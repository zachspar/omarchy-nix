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

    # TODO: Neovim, btop, Chromium policy. Official palettes already
    # retint GTK, Hyprland, Ghostty, icons, hyprlock, mako, Waybar,
    # Walker, and wallpaper (swaybg; backgrounds fetched from basecamp/omarchy).
  };
}
