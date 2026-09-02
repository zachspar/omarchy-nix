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
        && !cfg.programs.omarchy.storage.limine.enable
        && !cfg.boot.loader.limine.enable
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
        limine.enable=${toString cfg.programs.omarchy.storage.limine.enable}
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
        && cfg.services.snapper.configs.home.SUBVOLUME == "/home"
        && !cfg.programs.omarchy.storage.limine.enable
        && !cfg.boot.loader.limine.enable;
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
        limine=${toString cfg.programs.omarchy.storage.limine.enable}
        options=/ ${toString (fs."/".options or [ ])}
        warnings=${warnText}
      '';

  eval-storage-limine =
    let
      host = mkHost [
        self.nixosModules.omarchy
        self.nixosModules.disko
        pillarsOff
        {
          programs.omarchy.enable = true;
          programs.omarchy.storage.disko.enable = true;
          programs.omarchy.storage.disko.device = "/dev/vda";
          programs.omarchy.storage.limine.enable = true;
        }
      ];
      cfg = host.config;
      etcLimine = cfg.environment.etc."default/limine".text;
      extra = cfg.boot.loader.limine.extraEntries;
      install = cfg.boot.loader.limine.extraInstallCommands;
      warnText = lib.concatStringsSep "\n" cfg.warnings;
      ok =
        cfg.programs.omarchy.storage.limine.enable
        && cfg.boot.loader.limine.enable
        && !cfg.boot.loader.systemd-boot.enable
        && !cfg.boot.loader.grub.enable
        && lib.hasInfix "/Snapshots" extra
        && lib.hasInfix "omarchy-snapshot restore" extra
        && lib.hasInfix "omarchy-limine-snapper sync" install
        && lib.hasInfix "ESP_PATH=" etcLimine
        && lib.hasInfix "ROOT_SNAPSHOTS_PATH=\"/@/.snapshots\"" etcLimine
        && lib.hasInfix "MAX_SNAPSHOT_ENTRIES=5" etcLimine
        && cfg.boot.loader.limine.style.interface.branding == "Omarchy Bootloader"
        && cfg.systemd.services ? omarchy-limine-snapper
        && cfg.systemd.paths ? omarchy-limine-snapper
        && cfg.environment.etc ? "xdg/autostart/omarchy-snapshot-notify.desktop"
        && cfg.fileSystems."/boot".fsType == "vfat"
        && cfg.services.snapper.configs.root.SUBVOLUME == "/"
        && !(lib.hasInfix "boot.initrd.systemd.enable" warnText);
    in
    if ok then
      pkgs.runCommand "omarchy-eval-storage-limine" { } "touch $out"
    else
      throw ''
        limine + snapper-sync path should take over the bootloader and leave /Snapshots
        limine.enable=${toString cfg.boot.loader.limine.enable}
        systemd-boot=${toString cfg.boot.loader.systemd-boot.enable}
        extra=${extra}
        install=${install}
        branding=${cfg.boot.loader.limine.style.interface.branding or "MISSING"}
        has-service=${toString (cfg.systemd.services ? omarchy-limine-snapper)}
        etc-limine=${etcLimine}
        warnings=${warnText}
      '';
}
