{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  themeTools = pkgs.callPackage ../../pkgs/omarchy-theme-tools { };
  palettes = import ../../modules/shared/palettes.nix;
  currentTheme = "${config.xdg.stateHome}/omarchy/current";
  isLight = (palettes.${cfg.theme.name} or { mode = "dark"; }).mode == "light";
in
{
  config = lib.mkIf (cfg.enable && cfg.theme.enable) (
    lib.mkMerge [
      {
        home.packages = [
          themeTools
          pkgs.yaru-theme
          pkgs.gnome-themes-extra
          pkgs.adwaita-icon-theme
          pkgs.swaybg
        ];

        home.sessionVariables.OMARCHY_THEME = cfg.theme.name;

        gtk = {
          enable = true;
          gtk3.extraConfig.gtk-application-prefer-dark-theme = !isLight;
        };

        dconf.settings."org/gnome/desktop/interface" = {
          color-scheme = if isLight then "prefer-light" else "prefer-dark";
        };

        # Seed writable state so Hyprland/hyprlock/mako/Waybar/Walker can
        # source a theme file before the first `omarchy-theme-set`, and so
        # Ghostty's `theme = omarchy` resolves.
        home.activation.omarchyThemeSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          state="${currentTheme}"
          themes="${themeTools}/share/omarchy/themes/${cfg.theme.name}"
          mkdir -p "$state" "${config.xdg.configHome}/ghostty/themes"
          seed() {
            src="$1"
            dest="$2"
            if [ ! -e "$dest" ] && [ -f "$src" ]; then
              cp "$src" "$dest"
            fi
          }
          seed "$themes/hyprland.conf" "$state/hyprland.conf"
          seed "$themes/hyprlock.conf" "$state/hyprlock.conf"
          seed "$themes/mako.ini" "$state/mako.ini"
          seed "$themes/waybar.css" "$state/waybar.css"
          seed "$themes/walker.css" "$state/walker.css"
          seed "$themes/ghostty" "${config.xdg.configHome}/ghostty/themes/omarchy"
        '';

        # Apply the configured theme on graphical login so the first session
        # matches programs.omarchy.theme.name before any keybind is pressed.
        systemd.user.services.omarchy-theme-apply = {
          Unit = {
            Description = "Apply Omarchy theme (GTK + Hyprland + Ghostty + lock/notify/bar + icons + wallpaper)";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe' themeTools "omarchy-theme-set"} ${cfg.theme.name}";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        # swaybg reads the image at start. theme-set updates
        # ~/.local/state/omarchy/background and restarts this unit.
        systemd.user.services.omarchy-wallpaper = {
          Unit = {
            Description = "Omarchy wallpaper (swaybg)";
            After = [
              "graphical-session.target"
              "omarchy-theme-apply.service"
            ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${lib.getExe' themeTools "omarchy-wallpaper"}";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        # TODO: Neovim, btop, Chromium theme files. hyprlock does
        # not hot-reload an already-visible lock screen. Walker GTK CSS
        # is rewritten via current/walker.css + omarchy-restart-walker.
      }

      (lib.mkIf cfg.shell.enable {
        # sourceFirst puts this above background/input-field so $color etc. exist.
        programs.hyprlock.settings.source = [ "${currentTheme}/hyprlock.conf" ];

        # Appended after structural services.mako.settings; color keys win.
        services.mako.extraConfig = ''
          include=${currentTheme}/mako.ini
        '';

        programs.waybar.style = ''
          @import "${currentTheme}/waybar.css";

          * {
            background-color: @background;
            color: @foreground;
            border: none;
            border-radius: 0;
            min-height: 0;
            font-family: "JetBrainsMono Nerd Font";
            font-size: 12px;
          }
        '';
      })
    ]
  );
}
