# Omarchy installer disk layout, as a disko.devices attrset.
#
# Verified against omacom-io/omarchy-iso `configs/airootfs/root/configurator`
# (encrypted path): LUKS2, Btrfs label OMARCHY, subvolumes `@` `@home`
# `@log` `@pkg`, mount options `noatime,compress=zstd`, 2GiB FAT32 ESP
# labeled OMARCHY_EFI. Mapper name is this flake's `cryptroot` default
# (the ISO uses `omarchy_root`).
#
# Snapper on NixOS does not run `create-config`, so this also creates the
# nested `.snapshots` subvolumes Snapper requires under `@` and `@home`.
{
  lib,
  device,
  diskName ? "main",
  luksName ? "cryptroot",
  efiSize ? "2G",
  extraMountOptions ? [
    "noatime"
    "compress=zstd"
  ],
  passwordFile ? null,
  allowDiscards ? true,
  snapshotRoot ? true,
  snapshotHome ? true,
  includePkg ? true,
}:
let
  subvol = mountpoint: {
    inherit mountpoint;
    mountOptions = extraMountOptions;
  };
in
{
  disk.${diskName} = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          name = "OMARCHY_EFI";
          size = efiSize;
          type = "EF00";
          priority = 1;
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [
              "-n"
              "OMARCHY_EFI"
              "-F"
              "32"
            ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          name = "OMARCHY_ROOT";
          size = "100%";
          priority = 2;
          content = {
            type = "luks";
            name = luksName;
            extraFormatArgs = [
              "--type"
              "luks2"
              "--iter-time"
              "2000"
            ];
            inherit passwordFile;
            settings = {
              allowDiscards = allowDiscards;
            };
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-L"
                "OMARCHY"
              ];
              subvolumes = {
                "@" = subvol "/";
                "@home" = subvol "/home";
                "@log" = subvol "/var/log";
              }
              // lib.optionalAttrs includePkg {
                "@pkg" = subvol "/var/cache/pacman/pkg";
              }
              // lib.optionalAttrs snapshotRoot {
                "@/.snapshots" = subvol "/.snapshots";
              }
              // lib.optionalAttrs snapshotHome {
                "@home/.snapshots" = subvol "/home/.snapshots";
              };
            };
          };
        };
      };
    };
  };
}
