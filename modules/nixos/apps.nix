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
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    # Nautilus expects GVFS + udisks for removable media, as on Omarchy.
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    xdg.mime.defaultApplications = {
      "text/html" = "chromium.desktop";
      "x-scheme-handler/http" = "chromium.desktop";
      "x-scheme-handler/https" = "chromium.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };

    environment.systemPackages = [
      cfg.apps.browser
      cfg.apps.fileManager
      cfg.apps.editor
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
      pkgs.cliphist
      pkgs.xdg-utils
      pkgs.btop
    ]
    ++ cfg.apps.extraPackages;
  };
}
