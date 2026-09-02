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
    home.packages = [
      themeTools
      pkgs.yaru-theme
      pkgs.gnome-themes-extra
      pkgs.adwaita-icon-theme
    ];

    home.sessionVariables.OMARCHY_THEME = cfg.theme.name;

    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = cfg.theme.name != "catppuccin-latte";
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = if cfg.theme.name == "catppuccin-latte" then "prefer-light" else "prefer-dark";
    };

    # Seed writable state so Hyprland can `source` a theme file before the
    # first `omarchy-theme-set`, and so Ghostty's `theme = omarchy` resolves.
    home.activation.omarchyThemeSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      state="${config.xdg.stateHome}/omarchy/current"
      themes="${themeTools}/share/omarchy/themes/${cfg.theme.name}"
      mkdir -p "$state" "${config.xdg.configHome}/ghostty/themes"
      if [ ! -e "$state/hyprland.conf" ] && [ -f "$themes/hyprland.conf" ]; then
        cp "$themes/hyprland.conf" "$state/hyprland.conf"
      fi
      if [ ! -e "${config.xdg.configHome}/ghostty/themes/omarchy" ] && [ -f "$themes/ghostty" ]; then
        cp "$themes/ghostty" "${config.xdg.configHome}/ghostty/themes/omarchy"
      fi
    '';

    # Apply the configured theme on graphical login so the first session
    # matches programs.omarchy.theme.name before any keybind is pressed.
    systemd.user.services.omarchy-theme-apply = {
      Unit = {
        Description = "Apply Omarchy theme (GTK + Hyprland + Ghostty + icons)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe' themeTools "omarchy-theme-set"} ${cfg.theme.name}";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # TODO: retint Waybar, hyprlock, Neovim, btop, Chromium, and wallpapers
    # when full theme packs land. The switcher already covers the four
    # surfaces required for this stub.
  };
}
