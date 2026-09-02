{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  lock = lib.getExe cfg.shell.lockPackage;
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";
  pidof = lib.getExe' pkgs.procps "pidof";
  loginctl = lib.getExe' pkgs.systemd "loginctl";
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.enable) {
    programs.hyprlock = {
      enable = true;
      package = cfg.shell.lockPackage;
      # Layout lives here. Palette tokens ($color, $inner_color, …) come from
      # ~/.local/state/omarchy/current/hyprlock.conf when the theme pillar is on.
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };
        background = [
          {
            monitor = "";
            path = "screenshot";
            blur_passes = 3;
            color = if cfg.theme.enable then "$color" else "rgb(26, 27, 38)";
          }
        ];
        input-field = [
          (
            {
              monitor = "";
              size = "650, 100";
              position = "0, 0";
              halign = "center";
              valign = "center";
              font_family = "JetBrainsMono Nerd Font";
              placeholder_text = "Enter Password";
              rounding = 0;
              outline_thickness = 4;
              fade_on_empty = false;
            }
            // lib.optionalAttrs cfg.theme.enable {
              inner_color = "$inner_color";
              outer_color = "$outer_color";
              font_color = "$font_color";
              check_color = "$check_color";
            }
          )
        ];
      };
    };

    # Omarchy idle timings (seconds from idle, not stacked): screensaver /
    # DPMS at 150, lock at 300. We have no `omarchy-launch-screensaver`, so
    # the first listener turns the display off instead.
    services.hypridle = {
      enable = true;
      package = cfg.shell.idlePackage;
      settings = {
        general = {
          lock_cmd = "${pidof} hyprlock || ${lock}";
          before_sleep_cmd = "${loginctl} lock-session";
          after_sleep_cmd = "${hyprctl} dispatch dpms on";
          inhibit_sleep = 3;
        };
        listener = [
          {
            timeout = 150;
            on-timeout = "${hyprctl} dispatch dpms off";
            on-resume = "${hyprctl} dispatch dpms on";
          }
          {
            timeout = 300;
            on-timeout = "${loginctl} lock-session";
          }
        ];
      };
    };

    # Structural Omarchy mako defaults (anchor, timeout, size). Colors come
    # from the theme pillar (`include` of current/mako.ini). dbus.packages
    # registers the notification daemon; Hyprland exec-once starts it at
    # login (see hyprland.nix).
    services.mako = {
      enable = true;
      package = cfg.shell.notificationPackage;
      settings = {
        anchor = "top-right";
        font = "JetBrainsMono Nerd Font 12";
        width = 420;
        padding = "10,15";
        border-size = 2;
        border-radius = 0;
        default-timeout = 5000;
        max-icon-size = 32;
        group-by = "app-name,summary,body";
        "urgency=critical" = {
          default-timeout = 0;
          layer = "overlay";
        };
      };
    };
  };
}
