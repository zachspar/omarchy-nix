{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  palettes = import ../shared/palettes.nix;
  fallback = palettes.tokyo-night;
  palette =
    if cfg.theme.enable && builtins.hasAttr cfg.theme.name palettes then
      palettes.${cfg.theme.name}
    else
      fallback;

  greeter = pkgs.callPackage ../../pkgs/omarchy-greeter {
    themeName = if cfg.theme.enable then cfg.theme.name else "tokyo-night";
    background = palette.background;
    foreground = palette.foreground;
    failedColor = palette.red;
    logo = cfg.shell.greeter.logo;
  };

  sessionName = if cfg.shell.withUWSM then "hyprland-uwsm" else "hyprland";
  greeterOn = cfg.enable && cfg.shell.enable && cfg.shell.greeter.enable;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.shell.enable) {
      programs.hyprland = {
        enable = true;
        withUWSM = cfg.shell.withUWSM;
        xwayland.enable = true;
      };

      # Walker + Elephant user units live in Home Manager (walker.nix). NixOS
      # only installs the packages so the binaries exist on PATH.

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
        pkgs.libqalculate
        pkgs.uwsm
        (pkgs.callPackage ../../pkgs/omarchy-theme-tools { })
      ];
    })

    (lib.mkIf greeterOn {
      assertions = [
        {
          assertion = !cfg.shell.greeter.autoLogin.enable || cfg.shell.greeter.autoLogin.user != null;
          message = ''
            programs.omarchy.shell.greeter.autoLogin.enable is true but
            programs.omarchy.shell.greeter.autoLogin.user is unset.
          '';
        }
      ];

      # Omarchy's first-login path: SDDM (Wayland) + Hyprland/UWSM session.
      # Autologin stays off. FDE unlock is Plymouth / cryptsetup, not this.
      services.displayManager.defaultSession = lib.mkDefault sessionName;

      services.displayManager.autoLogin = lib.mkIf cfg.shell.greeter.autoLogin.enable {
        enable = true;
        user = cfg.shell.greeter.autoLogin.user;
      };

      services.displayManager.sddm = {
        enable = true;
        wayland = {
          enable = true;
        }
        // lib.optionalAttrs (cfg.shell.greeter.compositor == "weston") {
          compositor = "weston";
        };
        theme = "omarchy";
        extraPackages = [ greeter ];
        settings = lib.mkMerge [
          {
            Theme.Current = "omarchy";
          }
          (lib.mkIf (cfg.shell.greeter.compositor == "hyprland") {
            Wayland.CompositorCommand = "${lib.getExe' config.programs.hyprland.package "Hyprland"} --config ${greeter}/share/sddm/hyprland.conf";
          })
        ];
      };

      environment.systemPackages = [ greeter ];

      boot.plymouth = lib.mkIf cfg.shell.greeter.plymouth.enable {
        enable = true;
        theme = "omarchy";
        themePackages = [ greeter ];
      };

      warnings =
        lib.optionals
          (
            cfg.shell.greeter.plymouth.enable
            && cfg.storage.enable
            && (cfg.storage.luks.device != null || cfg.storage.disko.enable)
            && !config.boot.initrd.systemd.enable
          )
          [
            ''
              programs.omarchy.shell.greeter.plymouth is on and a LUKS device is
              declared, but boot.initrd.systemd.enable is false. NixOS's
              traditional initrd may still show the cryptsetup text prompt
              before Plymouth starts. Set boot.initrd.systemd.enable = true
              for the themed unlock dialog (Omarchy's unlock.png path).
            ''
          ];
    })
  ];
}
