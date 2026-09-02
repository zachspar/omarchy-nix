{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  storage = cfg.storage;

  rootIsBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";
  homeIsBtrfs = config.fileSystems ? "/home" && config.fileSystems."/home".fsType == "btrfs";
in
{
  config = lib.mkIf (cfg.enable && storage.enable) {
    boot.initrd.luks.devices = lib.mkIf (storage.luks.device != null) {
      ${storage.luks.name}.device = storage.luks.device;
    };

    # Snapper configs target mount points (`/`, `/home`), not Btrfs subvolume
    # names. The Omarchy layout is `@` at `/` and `@home` at `/home` — declare
    # those in fileSystems. disko will own creating that layout later; do not
    # reintroduce unused rootSubvolume/homeSubvolume options until then.
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
      lib.optionals (storage.luks.device == null) [
        ''
          programs.omarchy.storage is enabled but programs.omarchy.storage.luks.device
          is unset. Omarchy's supported install is LUKS2 wrapping a Btrfs volume
          with `@` (root) and `@home` subvolumes, plus Snapper for rollback.
          Point `luks.device` at the encrypted partition (or set it to the same
          path you already pass to boot.initrd.luks.devices). An unencrypted
          root is not an Omarchy-equivalent machine.
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
  };
}
