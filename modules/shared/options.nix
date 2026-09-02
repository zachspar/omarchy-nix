{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
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
        (lock on idle), mako (notifications), and SDDM + Plymouth so first
        login (and LUKS unlock) match Omarchy.
      '';

      greeter = {
        enable = mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = ''
            SDDM greeter with the Omarchy login theme (logo, lock, entry).
            This is the post-boot / post-logout screen. LUKS unlock is
            Plymouth (`programs.omarchy.shell.greeter.plymouth`), not SDDM.
            Autologin stays off unless you set `greeter.autoLogin`.
          '';
        };

        autoLogin = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Skip the SDDM password prompt and start the Hyprland/UWSM
              session. Off by default — Omarchy-on-NixOS still asks at the
              greeter. FDE unlock is a separate prompt (cryptsetup / Plymouth).
            '';
          };

          user = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "alice";
            description = "User for SDDM autologin. Required when `autoLogin.enable` is true.";
          };
        };

        compositor = mkOption {
          type = types.enum [
            "hyprland"
            "weston"
          ];
          default = "hyprland";
          description = ''
            Wayland compositor that hosts the SDDM greeter. Omarchy uses
            Hyprland (`start-hyprland` plus a tiny config). nixpkgs
            first-class supports weston (and kwin) as the greeter compositor;
            Hyprland is best-effort. Set `weston` if the greeter is black
            or crashes.
          '';
        };

        logo = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = literalExpression "./unlock.png";
          description = ''
            PNG used as the greeter and Plymouth logo. Defaults to the
            official pack's `unlock.png` for `programs.omarchy.theme.name`
            (fetched from basecamp/omarchy, MIT), then Omarchy's default
            `logo.png`, then a generated wordmark stub.

            Drop your own `unlock.png` and point this option at it. Changing
            the logo or greeter palette requires a rebuild — `omarchy-theme-set`
            cannot rewrite the store or the initrd.
          '';
        };

        plymouth = {
          enable = mkOption {
            type = types.bool;
            default = true;
            example = false;
            description = ''
              Plymouth boot splash and (when the initrd hooks it) the LUKS
              passphrase dialog. This is Omarchy's `unlock.png` path — not
              SDDM. The theme is baked into the initrd, so a palette change
              needs `nixos-rebuild`. nixos-unstable already uses systemd
              initrd, which is the themed dialog path. Traditional
              (non-systemd) initrd may still show the cryptsetup text
              prompt; the module warns if you turn systemd initrd off
              while a LUKS device is declared.
            '';
          };
        };
      };

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
          Upstream Walker from nixpkgs. Omarchy does not ship a separate
          `omarchy-walker` binary — branding is config, GTK CSS, and Elephant
          Lua menus (theme picker, wallpaper picker). Walker 2.x talks to
          Elephant; this flake starts a user unit rather than requiring
          `services.elephant`.
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
          without that, hyprlock cannot unlock.           Theme packs retint lock colors;
          the desktop wallpaper is set by the theme pillar (swaybg).
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
        (`Super+Ctrl+Shift+Space`) that flip GTK, Hyprland, Ghostty, icons,
        hyprlock, mako, Waybar, Walker, Neovim, btop, and wallpaper together.
        The keybind opens the Walker theme picker; `omarchy-theme-next` still
        cycles. Chromium chrome follows `theme.name` via a NixOS managed
        policy and needs a rebuild — `omarchy-theme-set` cannot rewrite `/etc`.
      '';

      name = mkOption {
        type = types.str;
        default = "tokyo-night";
        example = "catppuccin-latte";
        description = ''
          Default theme applied at login. Official packs: `catppuccin`,
          `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`,
          `gruvbox`, `hackerman`, `kanagawa`, `last-horizon`, `lumon`,
          `lupine`, `matte-black`, `miasma`, `nord`, `osaka-jade`,
          `retro-82`, `ristretto`, `rose-pine`, `solitude`, `tokyo-night`,
          `vantablack`, `white`. Each flip retints GTK, Hyprland, Ghostty,
          icons, hyprlock, mako, Waybar, Walker, Neovim, btop, and the
          wallpaper (swaybg). Chromium chrome follows this name via
          `programs.chromium.extraOpts` (BrowserThemeColor from the pack's
          `colors.toml` background). That policy is generation-bound; live
          `omarchy-theme-set` cannot rewrite `/etc`.
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
