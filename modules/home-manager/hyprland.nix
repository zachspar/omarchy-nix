{
  lib,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  terminal = lib.getExe cfg.shell.terminalPackage;
  # Wrapper ensures Elephant is up and applies Omarchy's Walker geometry.
  launcher = "omarchy-launch-walker";
  lock = lib.getExe cfg.shell.lockPackage;
  notify = lib.getExe cfg.shell.notificationPackage;
  makoctl = lib.getExe' cfg.shell.notificationPackage "makoctl";
  browser = lib.getExe cfg.apps.browser;
  files = lib.getExe cfg.apps.fileManager;
  editor = lib.getExe cfg.apps.editor;
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.enable) {
    wayland.windowManager.hyprland = {
      enable = true;
      # Stub settings are hyprlang; Omarchy upstream is moving toward Lua.
      configType = "hyprlang";
      systemd.enable = !cfg.shell.withUWSM;
      settings = {
        "$terminal" = terminal;
        "$launcher" = launcher;
        "$browser" = browser;
        "$fileManager" = files;

        exec-once = [
          # Walker + Elephant are systemd user units (see walker.nix).
          # mako has no Home Manager systemd unit; start it with the session
          # the way Omarchy does. hypridle, hyprsunset, and swayosd are
          # started by their user units — do not also exec-once them.
          "${notify}"
        ];

        layerrule = [
          "noanim, walker"
          "noanim, swayosd"
        ];

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
        };

        decoration = {
          rounding = 8;
        };

        input = {
          follow_mouse = 1;
          kb_options = "compose:caps";
        };

        bind = [
          "SUPER, Return, exec, $terminal"
          "SUPER, Space, exec, $launcher"
          "SUPER CTRL, E, exec, $launcher -m symbols"
          "SUPER CTRL, L, exec, ${lock}"
          "SUPER CTRL, N, exec, omarchy-toggle-nightlight"
          "SUPER, COMMA, exec, ${makoctl} dismiss"
          "SUPER SHIFT, COMMA, exec, ${makoctl} dismiss --all"
        ]
        ++ lib.optionals cfg.theme.enable [
          # Omarchy: Super+Ctrl+Shift+Space opens the theme picker, not cycle.
          # omarchy-theme-next remains the CLI for cycling.
          "SUPER CTRL SHIFT, Space, exec, $launcher -m menus:omarchythemes --width 800 --minheight 400"
          "SUPER CTRL, Space, exec, $launcher -m menus:omarchyBackgroundSelector --width 800 --minheight 400"
        ]
        ++ lib.optionals cfg.apps.enable [
          "SUPER, B, exec, $browser"
          "SUPER SHIFT, F, exec, $fileManager"
          "SUPER, N, exec, $terminal -e ${editor}"
          "SUPER SHIFT, S, exec, omarchy-screenshot"
          "SUPER, V, exec, $launcher -m clipboard"
        ];

        bindm = [
          "SUPER, mouse:272, movewindow"
          "SUPER, mouse:273, resizewindow"
        ];

        # Omarchy media.conf: bindel/bindl so volume and brightness still
        # work on the lock screen. Caps/Num/Scroll Lock OSD is the NixOS
        # libinput backend, not a Hyprland bind (avoids double-firing).
        "$osdclient" = "omarchy-swayosd-client";

        bindel = [
          ", XF86AudioRaiseVolume, exec, $osdclient --output-volume raise"
          ", XF86AudioLowerVolume, exec, $osdclient --output-volume lower"
          ", XF86AudioMute, exec, $osdclient --output-volume mute-toggle"
          ", XF86AudioMicMute, exec, $osdclient --input-volume mute-toggle"
          ", XF86MonBrightnessUp, exec, $osdclient --brightness raise"
          ", XF86MonBrightnessDown, exec, $osdclient --brightness lower"
          "ALT, XF86AudioRaiseVolume, exec, $osdclient --output-volume +1"
          "ALT, XF86AudioLowerVolume, exec, $osdclient --output-volume -1"
          "ALT, XF86MonBrightnessUp, exec, $osdclient --brightness +1"
          "ALT, XF86MonBrightnessDown, exec, $osdclient --brightness -1"
        ];

        bindl = [
          ", XF86AudioNext, exec, $osdclient --playerctl next"
          ", XF86AudioPause, exec, $osdclient --playerctl play-pause"
          ", XF86AudioPlay, exec, $osdclient --playerctl play-pause"
          ", XF86AudioPrev, exec, $osdclient --playerctl previous"
        ];

      };
      extraConfig = lib.optionalString cfg.theme.enable ''
        source = ${config.xdg.stateHome}/omarchy/current/hyprland.conf
      '';
    };

    # Waybar is Omarchy's status bar. systemd starts it; do not also exec-once.
    programs.waybar.enable = true;
  };
}
