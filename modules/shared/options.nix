{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkPackageOption
    types
    ;

  mkPillarEnable =
    description:
    mkOption {
      type = types.bool;
      default = true;
      example = false;
      inherit description;
    };
in
{
  options.programs.omarchy = {
    enable = mkEnableOption ''
      the Omarchy desktop UX stack (Hyprland, Walker, Ghostty, unified theming,
      curated apps, and LUKS+Btrfs+Snapper storage).

      This is a desktop experience, not a daemon — hence `programs.omarchy`,
      never `services.omarchy`.
    '';

    shell = {
      enable = mkPillarEnable ''
        Shell pillar: Hyprland + Walker + Ghostty, the "feels like Omarchy"
        baseline. Also enables Waybar (Omarchy's status bar; Walker is the
        launcher), the Elephant backend Walker 2.x needs, hyprlock + hypridle
        (lock on idle), and mako (notifications).
      '';

      withUWSM = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Launch Hyprland through UWSM (Universal Wayland Session Manager),
          matching Omarchy. Requires `programs.hyprland.withUWSM` on NixOS.
        '';
      };

      terminalPackage = mkPackageOption pkgs "ghostty" { };

      launcherPackage = mkPackageOption pkgs "walker" {
        extraDescription = ''
          Upstream Walker from nixpkgs. Omarchy's branded `omarchy-walker`
          overlay is not packaged here — do not vendor unpublished blobs.
          Walker 2.x expects `services.elephant.enable`.
        '';
      };

      barPackage = mkPackageOption pkgs "waybar" {
        extraDescription = ''
          Omarchy's top bar is Waybar, not Walker. Walker is the launcher.
        '';
      };

      lockPackage = mkPackageOption pkgs "hyprlock" {
        extraDescription = ''
          Screen locker. The NixOS module installs PAM (`security.pam.services.hyprlock`);
          without that, hyprlock cannot unlock. Theme-pack art is a later milestone.
        '';
      };

      idlePackage = mkPackageOption pkgs "hypridle" {
        extraDescription = ''
          Idle daemon: DPMS off at 150s (Omarchy's screensaver slot — we do not
          ship `omarchy-launch-screensaver`), lock at 300s. Matches
          `~/.config/omarchy/shell.json` idle.lock / idle.screensaver.
        '';
      };

      notificationPackage = mkPackageOption pkgs "mako" {
        extraDescription = ''
          Notification daemon. Omarchy Quattro is moving to a native shell
          notifier; this stub stays on mako from nixpkgs.
        '';
      };
    };

    theme = {
      enable = mkPillarEnable ''
        Theme pillar: one command (`omarchy-theme-set`) and one keybind
        (`Super+Ctrl+Shift+Space`) that flip GTK, Hyprland, Ghostty, and
        icons together.
      '';

      name = mkOption {
        type = types.str;
        default = "tokyo-night";
        example = "catppuccin-latte";
        description = ''
          Default theme applied at login. Built-in stubs: `tokyo-night`
          (dark) and `catppuccin-latte` (light). Full Omarchy theme packs
          (wallpapers, Waybar CSS, hyprlock, Neovim, btop, Chromium) are
          a later parity milestone — see the README roadmap.
        '';
      };
    };

    apps = {
      enable = mkPillarEnable ''
        Apps pillar: a small opinionated set — browser, file manager,
        editor (Neovim), plus screenshot and clipboard helpers.
      '';

      browser = mkPackageOption pkgs "chromium" { };

      fileManager = mkPackageOption pkgs "nautilus" { };

      editor = mkPackageOption pkgs "neovim" { };

      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Additional packages to install with the apps pillar.";
      };
    };

    storage = {
      enable = mkPillarEnable ''
        Storage pillar: LUKS + Btrfs `@` / `@home` + Snapper (or equivalent)
        for rollback. Omarchy does not treat an unencrypted ext4 root as a
        supported layout. This module will not reformat disks; you must
        declare the LUKS device and Btrfs subvolumes in your host config.
      '';

      luks = {
        device = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
          description = ''
            LUKS backing device. When set, wires
            `boot.initrd.luks.devices.<name>`. Leave null only while you
            still declare LUKS yourself — do not ship an unencrypted
            Omarchy machine.
          '';
        };

        name = mkOption {
          type = types.str;
          default = "cryptroot";
          description = "dm-crypt mapping name for the LUKS device.";
        };
      };

      snapper = {
        snapshotRoot = mkOption {
          type = types.bool;
          default = true;
          description = "Enable a Snapper config for `/` (requires a `.snapshots` subvolume).";
        };

        snapshotHome = mkOption {
          type = types.bool;
          default = true;
          description = "Enable a Snapper config for `/home` (requires `/home/.snapshots`).";
        };

        snapshotRootOnBoot = mkOption {
          type = types.bool;
          default = true;
          description = "Take a root snapshot on boot, matching Omarchy's rollback posture.";
        };
      };
    };
  };
}
