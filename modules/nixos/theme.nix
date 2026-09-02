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

    # TODO: import full Omarchy theme packs (Waybar CSS, hyprlock, Neovim,
    # btop, Chromium policy, wallpapers). The stub ships two palettes and a
    # switcher that already retints GTK + Hyprland + Ghostty + icons.
  };
}
