{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  currentTheme = "${config.xdg.stateHome}/omarchy/current";
  terminal = lib.getExe cfg.shell.terminalPackage;
  launcher = "omarchy-launch-walker";
  app = cmd: if cfg.shell.withUWSM then "uwsm-app -- ${cmd}" else cmd;
  nmEditor = lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor";
  blueman = lib.getExe' pkgs.blueman "blueman-manager";
  pavucontrol = lib.getExe pkgs.pavucontrol;
  pamixer = lib.getExe pkgs.pamixer;
  btop = lib.getExe pkgs.btop;
  fallbackWaybarCss = ''
    @define-color foreground #c0caf5;
    @define-color background #1a1b26;
  '';
  structuralCss = builtins.readFile ./waybar/style.css;
  waybarStyle =
    if cfg.theme.enable then
      ''
        @import "${currentTheme}/waybar.css";

        ${structuralCss}
      ''
    else
      ''
        ${fallbackWaybarCss}

        ${structuralCss}
      '';
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.enable) {
    # Click targets for the Omarchy bar (wifi / bluetooth / mixer / btop).
    home.packages = [
      pkgs.networkmanagerapplet
      pkgs.blueman
      pkgs.pavucontrol
      pkgs.pamixer
      pkgs.btop
    ];

    programs.waybar = {
      enable = true;
      package = cfg.shell.barPackage;
      systemd.enable = true;
      style = waybarStyle;
      # List form writes ~/.config/waybar/config (single bar), matching Omarchy.
      settings = [
        {
          reload_style_on_change = true;
          layer = "top";
          position = "top";
          spacing = 0;
          height = 26;
          modules-left = [
            "custom/omarchy"
            "hyprland/workspaces"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "group/tray-expander"
            "bluetooth"
            "network"
            "pulseaudio"
            "cpu"
            "battery"
          ];

          "hyprland/workspaces" = {
            on-click = "activate";
            format = "{icon}";
            format-icons = {
              default = "";
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "4" = "4";
              "5" = "5";
              "6" = "6";
              "7" = "7";
              "8" = "8";
              "9" = "9";
              "10" = "0";
              active = "󱓻";
            };
            persistent-workspaces = {
              "1" = [ ];
              "2" = [ ];
              "3" = [ ];
              "4" = [ ];
              "5" = [ ];
            };
          };

          "custom/omarchy" = {
            format = "";
            on-click = app launcher;
            on-click-right = app terminal;
            tooltip-format = "Launch apps\n\nSuper + Space";
          };

          cpu = {
            interval = 5;
            format = "󰍛";
            on-click = app "${terminal} -e ${btop}";
          };

          clock = {
            format = "{:L%A %H:%M}";
            format-alt = "{:L%d %B W%V %Y}";
            tooltip-format = "<tt>{calendar}</tt>";
            calendar = {
              mode = "month";
              weeks-pos = "right";
              on-scroll = 1;
            };
          };

          network = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format = "{icon}";
            format-wifi = "{icon}";
            format-ethernet = "󰀂";
            format-disconnected = "󰤮";
            tooltip-format-wifi = "{essid} ({frequency} GHz)";
            tooltip-format-ethernet = "Connected";
            tooltip-format-disconnected = "Disconnected";
            interval = 3;
            on-click = app nmEditor;
          };

          battery = {
            format = "{capacity}% {icon}";
            format-discharging = "{icon}";
            format-charging = "{icon}";
            format-plugged = "";
            format-icons = {
              charging = [
                "󰢜"
                "󰂆"
                "󰂇"
                "󰂈"
                "󰢝"
                "󰂉"
                "󰢞"
                "󰂊"
                "󰂋"
                "󰂅"
              ];
              default = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            format-full = "󰂅";
            tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
            tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
            interval = 5;
            states = {
              warning = 20;
              critical = 10;
            };
          };

          bluetooth = {
            format = "";
            format-off = "󰂲";
            format-disabled = "󰂲";
            format-connected = "󰂱";
            format-no-controller = "";
            tooltip-format = "Devices connected: {num_connections}";
            on-click = app blueman;
          };

          pulseaudio = {
            format = "{icon}";
            on-click = app pavucontrol;
            on-click-right = "${pamixer} -t";
            tooltip-format = "Playing at {volume}%";
            scroll-step = 5;
            format-muted = "";
            format-icons = {
              headphone = "";
              headset = "";
              default = [
                ""
                ""
                ""
              ];
            };
          };

          "group/tray-expander" = {
            orientation = "inherit";
            drawer = {
              transition-duration = 600;
              children-class = "tray-group-item";
            };
            modules = [
              "custom/expand-icon"
              "tray"
            ];
          };

          "custom/expand-icon" = {
            format = "";
            tooltip = false;
          };

          tray = {
            icon-size = 12;
            spacing = 17;
          };
        }
      ];
    };

    xdg.configFile."waybar/config".force = true;
    xdg.configFile."waybar/style.css".force = true;
  };
}
