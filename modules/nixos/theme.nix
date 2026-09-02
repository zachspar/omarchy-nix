{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  themeTools = pkgs.callPackage ../../pkgs/omarchy-theme-tools { };
  palettes = import ../shared/palettes.nix;
  chromiumPolicy = import ../shared/chromium-policy.nix { inherit lib; };
  chromium =
    if builtins.hasAttr cfg.theme.name palettes then
      chromiumPolicy.fromPalette palettes.${cfg.theme.name}
    else
      chromiumPolicy.fallback;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.theme.enable) {
      environment.systemPackages = [
        themeTools
        pkgs.yaru-theme
        pkgs.gnome-themes-extra
        pkgs.adwaita-icon-theme
        pkgs.gsettings-desktop-schemas
      ];

      environment.sessionVariables.OMARCHY_THEME = cfg.theme.name;
    })

    # Chromium chrome color is a managed policy under /etc. Omarchy's
    # omarchy-theme-set-browser tees color.json as root (and historically
    # made that directory world-writable). NixOS generations own /etc, so
    # this is keyed off programs.omarchy.theme.name and needs a rebuild.
    # Live omarchy-theme-set still writes chromium.theme into user state and
    # asks a running browser to --refresh-platform-policy; that refresh
    # cannot change the color until extra.json does.
    (lib.mkIf (cfg.enable && cfg.theme.enable && cfg.apps.enable) {
      programs.chromium = {
        enable = lib.mkDefault true;
        extraOpts = chromium.policy;
      };
    })
  ];
}
