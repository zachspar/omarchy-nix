{
  self,
  lib,
  pkgs,
  system,
}:
let
  mkHost =
    modules:
    lib.nixosSystem {
      inherit system;
      modules = [
        {
          nixpkgs.hostPlatform = system;
          system.stateVersion = "25.11";
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = false;
          networking.hostName = "eval";
        }
      ]
      ++ modules;
    };

  hasSubvol =
    fs: mount: name:
    lib.any (o: o == "subvol=${name}") fs.${mount}.options;

  pillarsOff = {
    programs.omarchy.shell.enable = false;
    programs.omarchy.theme.enable = false;
    programs.omarchy.apps.enable = false;
  };
in
{
  disko-layout =
    let
      layout = import ../modules/shared/disko-layout.nix {
        inherit lib;
        device = "/dev/vda";
      };
      luks = layout.disk.main.content.partitions.root.content;
      sub = luks.content.subvolumes;
      ok =
        layout.disk.main.device == "/dev/vda"
        && luks.name == "cryptroot"
        &&
          luks.extraFormatArgs == [
            "--type"
            "luks2"
            "--iter-time"
            "2000"
          ]
        && sub."@".mountpoint == "/"
        && sub."@home".mountpoint == "/home"
        && sub."@log".mountpoint == "/var/log"
        && sub."@pkg".mountpoint == "/var/cache/pacman/pkg"
        && sub."@/.snapshots".mountpoint == "/.snapshots"
        && sub."@home/.snapshots".mountpoint == "/home/.snapshots"
        && builtins.elem "compress=zstd" sub."@".mountOptions
        && builtins.elem "noatime" sub."@".mountOptions
        && layout.disk.main.content.partitions.ESP.size == "2G"
        && layout.disk.main.content.partitions.ESP.content.mountpoint == "/boot";
    in
    assert lib.assertMsg ok
      "Omarchy disko layout does not match the installer subvolumes / mount options";
    pkgs.runCommand "omarchy-disko-layout" { } "touch $out";

  eval-storage-warn =
    let
      host = mkHost [
        self.nixosModules.omarchy
        pillarsOff
        {
          programs.omarchy.enable = true;
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
        }
      ];
      cfg = host.config;
      warnText = lib.concatStringsSep "\n" cfg.warnings;
      ok =
        !cfg.programs.omarchy.storage.disko.enable
        && cfg.services.snapper.configs.root.SUBVOLUME == "/"
        && cfg.services.snapper.configs.home.SUBVOLUME == "/home"
        && lib.hasInfix "storage.luks.device" warnText
        && lib.hasInfix "is not Btrfs" warnText
        && !(cfg.boot.initrd.luks.devices ? cryptroot);
    in
    if ok then
      pkgs.runCommand "omarchy-eval-storage-warn" { } "touch $out"
    else
      throw ''
        default storage path should warn and never format
        disko.enable=${toString cfg.programs.omarchy.storage.disko.enable}
        snapper.root=${cfg.services.snapper.configs.root.SUBVOLUME or "MISSING"}
        snapper.home=${cfg.services.snapper.configs.home.SUBVOLUME or "MISSING"}
        has-luks-warn=${toString (lib.hasInfix "storage.luks.device" warnText)}
        has-btrfs-warn=${toString (lib.hasInfix "is not Btrfs" warnText)}
        has-cryptroot=${toString (cfg.boot.initrd.luks.devices ? cryptroot)}
        warnings=${warnText}
      '';

  eval-storage-disko =
    let
      host = mkHost [
        self.nixosModules.omarchy
        self.nixosModules.disko
        pillarsOff
        {
          programs.omarchy.enable = true;
          programs.omarchy.storage.disko.enable = true;
          programs.omarchy.storage.disko.device = "/dev/vda";
        }
      ];
      cfg = host.config;
      fs = cfg.fileSystems;
      warnText = lib.concatStringsSep "\n" cfg.warnings;
      ok =
        fs."/".fsType == "btrfs"
        && hasSubvol fs "/" "@"
        && hasSubvol fs "/home" "@home"
        && hasSubvol fs "/var/log" "@log"
        && hasSubvol fs "/var/cache/pacman/pkg" "@pkg"
        && hasSubvol fs "/.snapshots" "@/.snapshots"
        && hasSubvol fs "/home/.snapshots" "@home/.snapshots"
        && builtins.elem "compress=zstd" fs."/".options
        && builtins.elem "noatime" fs."/".options
        && fs."/boot".fsType == "vfat"
        && cfg.boot.initrd.luks.devices ? cryptroot
        && !(lib.hasInfix "storage.luks.device" warnText)
        && cfg.services.snapper.configs.root.SUBVOLUME == "/"
        && cfg.services.snapper.configs.home.SUBVOLUME == "/home";
    in
    if ok then
      pkgs.runCommand "omarchy-eval-storage-disko" { } "touch $out"
    else
      throw ''
        disko + storage pillar should produce the Omarchy layout and Snapper wiring
        / fsType=${fs."/".fsType or "MISSING"}
        /boot fsType=${fs."/boot".fsType or "MISSING"}
        has-cryptroot=${toString (cfg.boot.initrd.luks.devices ? cryptroot)}
        luks-warn=${toString (lib.hasInfix "storage.luks.device" warnText)}
        snapper.root=${cfg.services.snapper.configs.root.SUBVOLUME or "MISSING"}
        options=/ ${toString (fs."/".options or [ ])}
        warnings=${warnText}
      '';
}
