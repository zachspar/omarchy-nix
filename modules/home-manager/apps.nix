{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
in
{
  config = lib.mkIf (cfg.enable && cfg.apps.enable) {
    # Neovim enable + theme plugins live in neovim.nix so the apps pillar
    # still owns the editor, and theme-set can retint it without a second
    # programs.neovim.enable.

    services.cliphist.enable = true;

    home.packages = [
      cfg.apps.browser
      cfg.apps.fileManager
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
    ]
    ++ cfg.apps.extraPackages;

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    # Plasma / xdg-user-dirs already wrote these on a first login. Without
    # force, Home Manager aborts and never writes hyprland.conf / Waybar.
    xdg.configFile."user-dirs.dirs".force = true;
    xdg.configFile."user-dirs.conf".force = true;

    # Storage (LUKS / Btrfs / Snapper) is implemented only on the NixOS
    # module. The option is still declared here so the four-pillar shape
    # matches; flipping it in Home Manager is a no-op.
  };
}
