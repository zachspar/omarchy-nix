{
  self,
  lib,
  pkgs,
  system,
  home-manager,
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

  eval-shell-osd =
    let
      host = mkHost [
        self.nixosModules.omarchy
        {
          programs.omarchy.enable = true;
          programs.omarchy.theme.enable = false;
          programs.omarchy.apps.enable = false;
          programs.omarchy.storage.enable = false;
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
        }
      ];
      cfg = host.config;
      pkgNames = map (p: p.pname or p.name or "") cfg.environment.systemPackages;
      hasPkg = needle: lib.any (n: lib.hasPrefix needle n) pkgNames;
      exec = toString (cfg.systemd.services.swayosd-libinput-backend.serviceConfig.ExecStart or "");
      ok =
        cfg.programs.omarchy.shell.enable
        && hasPkg "hyprsunset"
        && hasPkg "swayosd"
        && cfg.systemd.services ? swayosd-libinput-backend
        && lib.hasInfix "swayosd-libinput-backend" exec
        && cfg.security.pam.services ? hyprlock;
    in
    if ok then
      pkgs.runCommand "omarchy-eval-shell-osd" { } "touch $out"
    else
      throw ''
        shell pillar should install hyprsunset + swayosd and the libinput backend
        hyprsunset=${toString (hasPkg "hyprsunset")}
        swayosd=${toString (hasPkg "swayosd")}
        has-backend=${toString (cfg.systemd.services ? swayosd-libinput-backend)}
        exec=${exec}
        pam-hyprlock=${toString (cfg.security.pam.services ? hyprlock)}
      '';

  eval-hm-shell-osd =
    let
      hm = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeManagerModules.omarchy
          {
            home.username = "eval";
            home.homeDirectory = "/home/eval";
            home.stateVersion = "25.11";
            programs.omarchy.enable = true;
            programs.omarchy.storage.enable = false;
          }
        ];
      };
      cfg = hm.config;
      binds = cfg.wayland.windowManager.hyprland.settings.bind or [ ];
      bindel = cfg.wayland.windowManager.hyprland.settings.bindel or [ ];
      bindl = cfg.wayland.windowManager.hyprland.settings.bindl or [ ];
      profiles = cfg.services.hyprsunset.settings.profile or [ ];
      identity = lib.any (p: (p.identity or false) && (p.time or "") == "07:00") profiles;
      layers = cfg.wayland.windowManager.hyprland.settings.layerrule or [ ];
      ok =
        cfg.wayland.windowManager.hyprland.enable
        && cfg.wayland.windowManager.hyprland.configType == "hyprlang"
        && !cfg.wayland.windowManager.hyprland.systemd.enable
        && (cfg.xdg.configFile."hypr/hyprland.conf".force or false)
        && cfg.programs.waybar.enable
        && cfg.programs.waybar.systemd.enable
        && cfg.xdg.configFile ? "uwsm/env"
        && identity
        && cfg.services.hyprsunset.enable
        && cfg.services.swayosd.enable
        && cfg.services.hypridle.enable
        && lib.any (b: lib.hasInfix "SUPER, Return" b) binds
        && lib.any (b: lib.hasInfix "SUPER, Space" b) binds
        && lib.any (b: lib.hasInfix "omarchy-toggle-nightlight" b) binds
        && lib.any (b: lib.hasInfix "XF86AudioRaiseVolume" b) bindel
        && lib.any (b: lib.hasInfix "XF86AudioPlay" b) bindl
        && lib.any (r: lib.hasInfix "match:namespace walker" r) layers
        && !(lib.any (r: r == "noanim, walker") layers)
        && cfg.xdg.configFile ? "swayosd/config.toml"
        && cfg.xdg.configFile ? "swayosd/style.css";
    in
    if ok then
      pkgs.runCommand "omarchy-eval-hm-shell-osd" { } "touch $out"
    else
      throw ''
        Home Manager shell should wire managed Hyprland + hyprsunset + swayosd
        hyprland=${toString cfg.wayland.windowManager.hyprland.enable}
        configType=${cfg.wayland.windowManager.hyprland.configType or "MISSING"}
        force-conf=${toString (cfg.xdg.configFile."hypr/hyprland.conf".force or false)}
        waybar-systemd=${toString cfg.programs.waybar.systemd.enable}
        hyprsunset=${toString cfg.services.hyprsunset.enable}
        identity=${toString identity}
        swayosd=${toString cfg.services.swayosd.enable}
        hypridle=${toString cfg.services.hypridle.enable}
        binds=${toString binds}
        bindel=${toString bindel}
      '';

  greeter-hyprland-conf =
    let
      conf = builtins.readFile ../pkgs/omarchy-greeter/hyprland.conf;
      ok =
        lib.hasInfix "float on" conf
        && lib.hasInfix "pin on" conf
        && lib.hasInfix "stay_focused on" conf
        && lib.hasInfix "no_anim on" conf
        && lib.hasInfix "border_size 0" conf
        && lib.hasInfix "no_shadow on" conf
        && lib.hasInfix "match:class" conf
        && !(lib.hasInfix "windowrule = float," conf)
        && !(lib.hasInfix "windowrule = pin," conf)
        && !(lib.hasInfix "stayfocused" conf)
        && !(lib.hasInfix "noborder" conf)
        && !(lib.hasInfix "noshadow" conf);
    in
    if ok then
      pkgs.runCommand "omarchy-greeter-hyprland-conf" { } "touch $out"
    else
      throw ''
        SDDM greeter hyprland.conf must use Hyprland 0.53+ windowrule syntax
        conf=${conf}
      '';

  eval-shell-requires-hm =
    let
      host = mkHost [
        self.nixosModules.omarchy
        {
          programs.omarchy.enable = true;
          programs.omarchy.theme.enable = false;
          programs.omarchy.apps.enable = false;
          programs.omarchy.storage.enable = false;
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
        }
      ];
      failed = lib.filter (a: !a.assertion) host.config.assertions;
      ok = lib.any (a: lib.hasInfix "autogenerated stub" a.message) failed;
    in
    if ok then
      pkgs.runCommand "omarchy-eval-shell-requires-hm" { } "touch $out"
    else
      throw ''
        shell pillar without Home Manager must fail the Hyprland-managed assertion
        failed=${toString (map (a: a.message) failed)}
      '';

  eval-nixos-hm-hyprland =
    let
      host = mkHost [
        self.nixosModules.omarchy
        home-manager.nixosModules.home-manager
        {
          programs.omarchy.enable = true;
          programs.omarchy.theme.enable = false;
          programs.omarchy.apps.enable = false;
          programs.omarchy.storage.enable = false;
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
          users.users.eval = {
            isNormalUser = true;
            home = "/home/eval";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.users.eval = {
            home.stateVersion = "25.11";
          };
        }
      ];
      user = host.config.home-manager.users.eval;
      binds = user.wayland.windowManager.hyprland.settings.bind or [ ];
      failed = lib.filter (a: !a.assertion) host.config.assertions;
      ok =
        user.wayland.windowManager.hyprland.enable
        && user.wayland.windowManager.hyprland.configType == "hyprlang"
        && !user.wayland.windowManager.hyprland.systemd.enable
        && (user.xdg.configFile."hypr/hyprland.conf".force or false)
        && user.programs.waybar.systemd.enable
        && lib.any (b: lib.hasInfix "SUPER, Return" b) binds
        && lib.any (b: lib.hasInfix "SUPER, Space" b) binds
        && failed == [ ];
    in
    if ok then
      pkgs.runCommand "omarchy-eval-nixos-hm-hyprland" { } "touch $out"
    else
      throw ''
        NixOS + Home Manager composition must manage Hyprland via sharedModules
        hyprland=${toString user.wayland.windowManager.hyprland.enable}
        configType=${user.wayland.windowManager.hyprland.configType or "MISSING"}
        binds=${toString binds}
        failed=${toString (map (a: a.message) failed)}
      '';
}
