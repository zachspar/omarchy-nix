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
