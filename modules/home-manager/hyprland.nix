{
  lib,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  terminal = lib.getExe cfg.shell.terminalPackage;
  launcher = lib.getExe cfg.shell.launcherPackage;
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
          "${launcher} --gapplication-service"
          # mako has no Home Manager systemd unit; start it with the session
          # the way Omarchy does. hypridle is started by services.hypridle.
          "${notify}"
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
          "SUPER CTRL, L, exec, ${lock}"
          "SUPER, COMMA, exec, ${makoctl} dismiss"
          "SUPER SHIFT, COMMA, exec, ${makoctl} dismiss --all"
        ]
        ++ lib.optionals cfg.theme.enable [
          "SUPER CTRL SHIFT, Space, exec, omarchy-theme-next"
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

      };
      extraConfig = lib.optionalString cfg.theme.enable ''
        source = ${config.xdg.stateHome}/omarchy/current/hyprland.conf
      '';
    };

    # Waybar is Omarchy's status bar. systemd starts it; do not also exec-once.
    programs.waybar.enable = true;
  };
}
