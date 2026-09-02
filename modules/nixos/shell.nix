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
  config = lib.mkIf (cfg.enable && cfg.shell.enable) {
    programs.hyprland = {
      enable = true;
      withUWSM = cfg.shell.withUWSM;
      xwayland.enable = true;
    };

    # Walker 2.x talks to Elephant. Started here (not services.elephant) so
    # the module evaluates on nixpkgs pins that lack that option.
    # Omarchy's branded `omarchy-walker` providers are still a TODO.
    systemd.user.services.omarchy-elephant = {
      description = "Elephant application launcher backend (Walker)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.elephant}";
        Restart = "on-failure";
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    programs.dconf.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      OMARCHY_THEME_DIR = "/run/current-system/sw/share/omarchy/themes";
    };

    fonts.packages = [
      pkgs.nerd-fonts.jetbrains-mono
    ];

    # Hyprlock authenticates via PAM. The Home Manager package alone cannot
    # unlock; this empty service is what nixpkgs programs.hyprlock installs.
    # Do not enable programs.hyprlock here — that also starts a system
    # hypridle unit that would race the Home Manager one.
    security.pam.services.hyprlock = { };

    environment.systemPackages = [
      cfg.shell.terminalPackage
      cfg.shell.launcherPackage
      cfg.shell.barPackage
      cfg.shell.lockPackage
      cfg.shell.idlePackage
      cfg.shell.notificationPackage
      pkgs.elephant
      pkgs.uwsm
    ];
  };
}
