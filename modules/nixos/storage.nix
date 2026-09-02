{
  lib,
  pkgs,
  config,
  options,
  ...
}:
let
  cfg = config.programs.omarchy;
  storage = cfg.storage;
  diskoCfg = storage.disko;

  rootIsBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";
  homeIsBtrfs = config.fileSystems ? "/home" && config.fileSystems."/home".fsType == "btrfs";

  mkOmarchyDisko = import ../shared/disko-layout.nix;

  diskoOn = cfg.enable && storage.enable && diskoCfg.enable;
  limineOn = cfg.enable && storage.enable && storage.limine.enable;

  palettes = import ../shared/palettes.nix;
  fallbackPalette = palettes.tokyo-night;
  palette =
    if cfg.theme.enable && builtins.hasAttr cfg.theme.name palettes then
      palettes.${cfg.theme.name}
    else
      fallbackPalette;

  stripHash = value: lib.removePrefix "#" value;

  limineSnapper = pkgs.callPackage ../../pkgs/omarchy-limine-snapper { };

  esp = config.boot.loader.efi.efiSysMountPoint;

  defaultLimine = ''
    # Managed by programs.omarchy.storage.limine.
    #
    # NixOS writes generation entries to ${esp}/limine/limine.conf.
    # This file is for omarchy-limine-snapper (and would be what
    # upstream limine-snapper-sync reads if it ever lands in nixpkgs).
    #
    # limine-snapper-sync is a GraalVM native-image, not packaged in
    # nixpkgs. Do not vendor unpublished binaries. Snapshot kernels are
    # copied to ${esp}/omarchy-snapshots/<id>/ so nixpkgs limine-install.py
    # (which only manages ${esp}/limine/) cannot delete them.

    TARGET_OS_NAME="NixOS default profile"
    ESP_PATH="${esp}"
    ROOT_SUBVOLUME_PATH="@"
    ROOT_SNAPSHOTS_PATH="/@/.snapshots"
    SNAPPER_CONFIG_NAME="root"
    MAX_SNAPSHOT_ENTRIES=${toString storage.limine.maxSnapshotEntries}
    SNAPSHOT_WRITABLE=${if storage.limine.writableSnapshots then "yes" else "no"}
    RESTORE_METHOD=replace
    OMARCHY_SNAPSHOT_DIR="omarchy-snapshots"
  '';
in
{
  config = lib.mkMerge (
    [
      (lib.mkIf (cfg.enable && storage.enable) {
        boot.initrd.luks.devices = lib.mkIf (storage.luks.device != null && !diskoCfg.enable) {
          ${storage.luks.name}.device = storage.luks.device;
        };

        # Snapper configs target mount points (`/`, `/home`), not Btrfs
        # subvolume names. The Omarchy layout is `@` at `/` and `@home` at
        # `/home`. `storage.disko` creates those names; otherwise declare
        # them in fileSystems. Do not reintroduce unused rootSubvolume /
        # homeSubvolume options.
        services.snapper = {
          snapshotRootOnBoot = storage.snapper.snapshotRootOnBoot;
          configs =
            lib.optionalAttrs storage.snapper.snapshotRoot {
              root = {
                SUBVOLUME = "/";
                FSTYPE = "btrfs";
                TIMELINE_CREATE = true;
                TIMELINE_CLEANUP = true;
                TIMELINE_LIMIT_HOURLY = 5;
                TIMELINE_LIMIT_DAILY = 7;
                TIMELINE_LIMIT_WEEKLY = 4;
                TIMELINE_LIMIT_MONTHLY = 0;
                TIMELINE_LIMIT_YEARLY = 0;
                NUMBER_LIMIT = 20;
                NUMBER_LIMIT_IMPORTANT = 5;
              };
            }
            // lib.optionalAttrs storage.snapper.snapshotHome {
              home = {
                SUBVOLUME = "/home";
                FSTYPE = "btrfs";
                TIMELINE_CREATE = true;
                TIMELINE_CLEANUP = true;
                TIMELINE_LIMIT_HOURLY = 5;
                TIMELINE_LIMIT_DAILY = 7;
                TIMELINE_LIMIT_WEEKLY = 4;
                TIMELINE_LIMIT_MONTHLY = 0;
                TIMELINE_LIMIT_YEARLY = 0;
                NUMBER_LIMIT = 20;
                NUMBER_LIMIT_IMPORTANT = 5;
              };
            };
        };

        environment.systemPackages = [
          pkgs.btrfs-progs
          pkgs.snapper
          pkgs.cryptsetup
        ];

        warnings =
          lib.optionals (storage.luks.device == null && !diskoCfg.enable) [
            ''
              programs.omarchy.storage is enabled but programs.omarchy.storage.luks.device
              is unset. Omarchy's supported install is LUKS2 wrapping a Btrfs volume
              with `@` (root) and `@home` subvolumes, plus Snapper for rollback.
              Point `luks.device` at the encrypted partition (or set it to the same
              path you already pass to boot.initrd.luks.devices), or enable
              `programs.omarchy.storage.disko` to create that layout (this wipes
              the target disk). An unencrypted root is not an Omarchy-equivalent
              machine.
            ''
          ]
          ++ lib.optionals (storage.luks.device != null && diskoCfg.enable) [
            ''
              programs.omarchy.storage.disko.enable is on; disko already opens
              the LUKS mapping. `storage.luks.device` is ignored so the device
              is not unlocked twice. Drop the luks.device assignment.
            ''
          ]
          ++ lib.optionals (config.fileSystems ? "/" && !rootIsBtrfs) [
            ''
              `/` is not Btrfs. Omarchy rollback is Snapper on Btrfs subvolumes
              (`@`, `@home`, optionally `@log` / `@pkg` / `@.snapshots`).
              Other filesystems will not give you the same recovery story.
            ''
          ]
          ++ lib.optionals (config.fileSystems ? "/home" && !homeIsBtrfs) [
            ''
              `/home` is not Btrfs. Snapshot `/home` as its own subvolume
              (`@home`) so a root rollback cannot clobber user data — and so
              home can be rolled back independently.
            ''
          ];
      })

      (lib.mkIf limineOn {
        assertions = [
          {
            assertion = storage.snapper.snapshotRoot;
            message = ''
              programs.omarchy.storage.limine.enable needs Snapper on `/`
              (programs.omarchy.storage.snapper.snapshotRoot). The Limine
              Snapshots menu boots and restores the root subvolume only.
            '';
          }
        ];

        # Take over the bootloader. systemd-boot files may linger on the ESP
        # until GC, but they are no longer the firmware path.
        boot.loader.systemd-boot.enable = lib.mkForce false;
        boot.loader.grub.enable = lib.mkForce false;
        boot.loader.limine.enable = true;

        boot.loader.limine.extraEntries = lib.mkDefault ''
          # Snapper filesystem snapshots of @ — not NixOS generations.
          # Generations are the NixOS menu above (store closures).
          # These entries boot @/.snapshots/<id>/snapshot. Restore with
          # omarchy-snapshot restore, then reboot. /home (@home) is not
          # rolled back.
          /Snapshots
        '';

        boot.loader.limine.extraInstallCommands = ''
          ${limineSnapper}/bin/omarchy-limine-snapper sync || echo "omarchy-limine-snapper: sync skipped ($?)"
        '';

        boot.loader.limine.style = {
          wallpapers = lib.mkForce [ ];
          backdrop = lib.mkDefault (stripHash palette.background);
          wallpaperStyle = lib.mkDefault "stretched";
          interface = {
            branding = lib.mkDefault "Omarchy Bootloader";
            brandingColor = lib.mkDefault (stripHash palette.green);
            helpColor = lib.mkDefault (stripHash palette.green);
            helpColorBright = lib.mkDefault (stripHash palette.green);
          };
          graphicalTerminal = {
            palette = lib.mkDefault (
              lib.concatStringsSep ";" [
                (stripHash palette.color0)
                (stripHash palette.red)
                (stripHash palette.green)
                (stripHash palette.yellow)
                (stripHash palette.blue)
                (stripHash palette.magenta)
                (stripHash palette.cyan)
                (stripHash palette.foreground)
              ]
            );
            brightPalette = lib.mkDefault (
              lib.concatStringsSep ";" [
                (stripHash palette.muted)
                (stripHash palette.brightRed)
                (stripHash palette.brightGreen)
                (stripHash palette.brightYellow)
                (stripHash palette.brightBlue)
                (stripHash palette.brightMagenta)
                (stripHash palette.brightCyan)
                (stripHash palette.brightForeground)
              ]
            );
            foreground = lib.mkDefault (stripHash palette.brightForeground);
            background = lib.mkDefault (stripHash palette.background);
            brightForeground = lib.mkDefault (stripHash palette.brightForeground);
            brightBackground = lib.mkDefault (stripHash palette.lighterBackground);
          };
        };

        environment.etc."default/limine".text = defaultLimine;

        environment.systemPackages = [
          limineSnapper
          pkgs.limine
        ];

        systemd.paths.omarchy-limine-snapper = {
          description = "Sync Limine snapshot entries when Snapper changes /.snapshots";
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathModified = "/.snapshots";
            Unit = "omarchy-limine-snapper.service";
          };
        };

        systemd.services.omarchy-limine-snapper = {
          description = "Sync Limine /Snapshots with Snapper";
          after = [ "local-fs.target" ];
          unitConfig.RequiresMountsFor = [
            "/.snapshots"
            esp
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${limineSnapper}/bin/omarchy-limine-snapper sync";
          };
        };

        environment.etc."xdg/autostart/omarchy-snapshot-notify.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Omarchy snapshot restore prompt
          Exec=${limineSnapper}/bin/omarchy-limine-snapper notify
          NoDisplay=true
          X-GNOME-Autostart-enabled=true
        '';

        warnings =
          lib.optionals (!config.boot.initrd.systemd.enable) [
            ''
              programs.omarchy.storage.limine is on but boot.initrd.systemd.enable
              is false. Snapshot boot entries pass rootflags=subvol=@/.snapshots/<id>/snapshot
              on the kernel cmdline. systemd initrd honors that; traditional
              NixOS stage-1 may still mount @ from the generation's baked-in
              filesystems and ignore the Snapper subvolume. Keep systemd
              initrd (nixos-unstable already does).
            ''
          ]
          ++ lib.optionals (!(config.fileSystems ? "/boot")) [
            ''
              programs.omarchy.storage.limine is on but fileSystems."/boot" is
              unset. NixOS Limine writes ${esp}/limine/limine.conf. The disko
              snippet mounts the ESP at /boot; declare that mount if you laid
              out the disk by hand.
            ''
          ];
      })

      (lib.mkIf (diskoOn && !(options ? disko)) {
        assertions = [
          {
            assertion = false;
            message = ''
              programs.omarchy.storage.disko.enable is true, but the disko NixOS
              module is not imported. Add `omarchy-nix.nixosModules.disko` to
              your modules list (or nix-community/disko's nixosModules.disko).

              THIS PATH WIPES DISKS. Do not enable it until you mean to format
              programs.omarchy.storage.disko.device.
            '';
          }
        ];
      })
    ]
    ++ lib.optional (options ? disko) {
      assertions = [
        {
          assertion = !diskoOn || diskoCfg.device != null;
          message = ''
            programs.omarchy.storage.disko.enable is true but
            programs.omarchy.storage.disko.device is unset. Point it at
            the disk you are willing to wipe (e.g. /dev/nvme0n1).
          '';
        }
      ];

      # Only mention `disko.devices` when the option exists. `mkIf false`
      # still counts as a definition and would fail eval without the module.
      disko.devices = lib.mkIf (diskoOn && diskoCfg.device != null) (mkOmarchyDisko {
        inherit lib;
        device = diskoCfg.device;
        diskName = diskoCfg.diskName;
        luksName = storage.luks.name;
        efiSize = diskoCfg.efiSize;
        extraMountOptions = diskoCfg.extraMountOptions;
        passwordFile = diskoCfg.passwordFile;
        allowDiscards = diskoCfg.allowDiscards;
        snapshotRoot = storage.snapper.snapshotRoot;
        snapshotHome = storage.snapper.snapshotHome;
        includePkg = diskoCfg.includePkg;
      });
    }
  );
}
