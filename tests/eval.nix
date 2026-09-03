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
      greeterCmd = cfg.services.displayManager.sddm.settings.Wayland.CompositorCommand or "";
      ok =
        cfg.programs.omarchy.shell.enable
        && hasPkg "hyprsunset"
        && hasPkg "swayosd"
        && cfg.systemd.services ? swayosd-libinput-backend
        && lib.hasInfix "swayosd-libinput-backend" exec
        && cfg.security.pam.services ? hyprlock
        && cfg.services.displayManager.defaultSession == "hyprland-uwsm"
        && cfg.programs.hyprland.withUWSM
        && lib.hasInfix "start-hyprland" greeterCmd
        && lib.hasInfix "-- --config" greeterCmd
        && !(lib.hasInfix "bin/Hyprland --config" greeterCmd);
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
        defaultSession=${cfg.services.displayManager.defaultSession or "MISSING"}
        greeterCmd=${greeterCmd}
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
      binds = cfg.wayland.windowManager.hyprland.settings.bindd or [ ];
      bindel = cfg.wayland.windowManager.hyprland.settings.bindel or [ ];
      bindl = cfg.wayland.windowManager.hyprland.settings.bindl or [ ];
      profiles = cfg.services.hyprsunset.settings.profile or [ ];
      identity = lib.any (p: (p.identity or false) && (p.time or "") == "07:00") profiles;
      layers = cfg.wayland.windowManager.hyprland.settings.layerrule or [ ];
      execOnce = cfg.wayland.windowManager.hyprland.settings.exec-once or [ ];
      waybarBars =
        if builtins.isList cfg.programs.waybar.settings then
          cfg.programs.waybar.settings
        else
          lib.attrValues cfg.programs.waybar.settings;
      waybar = builtins.head waybarBars;
      ok =
        cfg.wayland.windowManager.hyprland.enable
        && cfg.wayland.windowManager.hyprland.configType == "hyprlang"
        && !cfg.wayland.windowManager.hyprland.systemd.enable
        && (cfg.xdg.configFile."hypr/hyprland.conf".force or false)
        && cfg.home.activation ? omarchyRemoveHyprlandLua
        && cfg.gtk.gtk2.force
        && (cfg.xdg.configFile."gtk-3.0/settings.ini".force or false)
        && (cfg.xdg.configFile."gtk-4.0/settings.ini".force or false)
        && (cfg.xdg.configFile."user-dirs.dirs".force or false)
        && cfg.programs.waybar.enable
        && cfg.programs.waybar.systemd.enable
        && builtins.elem "hyprland/workspaces" waybar.modules-left
        && builtins.elem "clock" waybar.modules-center
        && builtins.elem "network" waybar.modules-right
        && builtins.elem "bluetooth" waybar.modules-right
        && builtins.elem "pulseaudio" waybar.modules-right
        && builtins.elem "battery" waybar.modules-right
        && waybar ? "hyprland/workspaces"
        && waybar.clock ? calendar
        && cfg.xdg.configFile ? "uwsm/env"
        && identity
        && cfg.services.hyprsunset.enable
        && cfg.services.swayosd.enable
        && cfg.services.hypridle.enable
        && cfg.systemd.user.services.omarchy-theme-apply.Service.Type == "oneshot"
        && cfg.systemd.user.services.omarchy-theme-apply.Service.RemainAfterExit
        && !(lib.elem "omarchy-theme-apply.service" (
          cfg.systemd.user.services.omarchy-walker.Unit.After or [ ]
        ))
        && lib.any (e: e == "OMARCHY_SKIP_UNIT_RESTART=1") (
          lib.toList (cfg.systemd.user.services.omarchy-theme-apply.Service.Environment or [ ])
        )
        && lib.any (b: lib.hasInfix "SUPER, Return" b && lib.hasInfix "uwsm-app -- $terminal" b) binds
        && lib.any (b: lib.hasInfix "SUPER, Space" b && lib.hasInfix "uwsm-app -- $launcher" b) binds
        && lib.any (b: lib.hasInfix "SUPER, W," b) binds
        && lib.any (
          b: lib.hasInfix "SUPER, K," b && lib.hasInfix "uwsm-app -- omarchy-menu-keybindings" b
        ) binds
        && lib.any (b: lib.hasInfix "SUPER SHIFT, B," b && lib.hasInfix "uwsm-app -- $browser" b) binds
        && lib.any (b: lib.hasInfix "SUPER SHIFT, F," b && lib.hasInfix "uwsm-app -- $fileManager" b) binds
        && lib.any (b: lib.hasInfix "SUPER SHIFT, N," b && lib.hasInfix "uwsm-app -- $terminal -e" b) binds
        && lib.any (b: lib.hasInfix "SUPER SHIFT, Return," b && lib.hasInfix "uwsm-app -- $browser" b) binds
        && lib.any (
          b: lib.hasInfix "SUPER SHIFT, S," b && lib.hasInfix "uwsm-app -- omarchy-screenshot" b
        ) binds
        && lib.any (b: lib.hasInfix "code:10" b) binds
        && lib.any (b: lib.hasInfix "code:19" b) binds
        && lib.any (b: lib.hasInfix "movefocus, l" b) binds
        && lib.any (b: lib.hasInfix "omarchy-toggle-nightlight" b) binds
        && !(lib.any (b: lib.hasInfix "uwsm-app" b && lib.hasInfix "omarchy-toggle-nightlight" b) binds)
        && lib.any (e: lib.hasPrefix "uwsm-app -- " e) execOnce
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
        gtk2-force=${toString cfg.gtk.gtk2.force}
        waybar-left=${toString (waybar.modules-left or [ ])}
        waybar-center=${toString (waybar.modules-center or [ ])}
        waybar-right=${toString (waybar.modules-right or [ ])}
        waybar-systemd=${toString cfg.programs.waybar.systemd.enable}
        hyprsunset=${toString cfg.services.hyprsunset.enable}
        identity=${toString identity}
        swayosd=${toString cfg.services.swayosd.enable}
        hypridle=${toString cfg.services.hypridle.enable}
        binds=${toString binds}
        bindel=${toString bindel}
        execOnce=${toString execOnce}
      '';

  greeter-hyprland-conf =
    let
      conf = builtins.readFile ../pkgs/omarchy-greeter/hyprland.conf;
      ok =
        lib.hasInfix "disable_hyprland_logo = true" conf
        && lib.hasInfix "disable_splash_rendering = true" conf
        && lib.hasInfix "force_default_wallpaper = 0" conf
        && lib.hasInfix "enabled = false" conf
        && !(lib.hasInfix "windowrule" conf)
        && !(lib.hasInfix "decoration" conf);
    in
    if ok then
      pkgs.runCommand "omarchy-greeter-hyprland-conf" { } "touch $out"
    else
      throw ''
        SDDM greeter hyprland.conf must match upstream (misc + animations only)
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
      binds = user.wayland.windowManager.hyprland.settings.bindd or [ ];
      greeterCmd = host.config.services.displayManager.sddm.settings.Wayland.CompositorCommand or "";
      failed = lib.filter (a: !a.assertion) host.config.assertions;
      waybarBars =
        if builtins.isList user.programs.waybar.settings then
          user.programs.waybar.settings
        else
          lib.attrValues user.programs.waybar.settings;
      waybar = builtins.head waybarBars;
      ok =
        user.wayland.windowManager.hyprland.enable
        && user.wayland.windowManager.hyprland.configType == "hyprlang"
        && !user.wayland.windowManager.hyprland.systemd.enable
        && (user.xdg.configFile."hypr/hyprland.conf".force or false)
        && user.home.activation ? omarchyRemoveHyprlandLua
        && host.config.home-manager.backupFileExtension == "bak"
        && host.config.hardware.bluetooth.enable
        && host.config.services.blueman.enable
        && user.programs.waybar.systemd.enable
        && builtins.elem "hyprland/workspaces" waybar.modules-left
        && builtins.elem "clock" waybar.modules-center
        && builtins.elem "network" waybar.modules-right
        && builtins.elem "bluetooth" waybar.modules-right
        && host.config.services.displayManager.defaultSession == "hyprland-uwsm"
        && lib.hasInfix "start-hyprland" greeterCmd
        && lib.hasInfix "-- --config" greeterCmd
        && lib.any (b: lib.hasInfix "SUPER, Return" b && lib.hasInfix "uwsm-app -- $terminal" b) binds
        && lib.any (b: lib.hasInfix "SUPER, Space" b && lib.hasInfix "uwsm-app -- $launcher" b) binds
        && lib.any (b: lib.hasInfix "SUPER, W," b) binds
        && lib.any (b: lib.hasInfix "omarchy-menu-keybindings" b) binds
        && lib.any (b: lib.hasInfix "code:10" b) binds
        && failed == [ ];
    in
    if ok then
      pkgs.runCommand "omarchy-eval-nixos-hm-hyprland" { } "touch $out"
    else
      throw ''
        NixOS + Home Manager composition must manage Hyprland via sharedModules
        hyprland=${toString user.wayland.windowManager.hyprland.enable}
        configType=${user.wayland.windowManager.hyprland.configType or "MISSING"}
        backup=${host.config.home-manager.backupFileExtension or "MISSING"}
        bluetooth=${toString host.config.hardware.bluetooth.enable}
        waybar-left=${toString (waybar.modules-left or [ ])}
        binds=${toString binds}
        failed=${toString (map (a: a.message) failed)}
        defaultSession=${host.config.services.displayManager.defaultSession or "MISSING"}
        greeterCmd=${greeterCmd}
      '';

  eval-hm-no-uwsm =
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
            programs.omarchy.shell.withUWSM = false;
            programs.omarchy.storage.enable = false;
          }
        ];
      };
      cfg = hm.config;
      binds = cfg.wayland.windowManager.hyprland.settings.bindd or [ ];
      execOnce = cfg.wayland.windowManager.hyprland.settings.exec-once or [ ];
      ok =
        cfg.wayland.windowManager.hyprland.enable
        && cfg.wayland.windowManager.hyprland.systemd.enable
        && !(cfg.xdg.configFile ? "uwsm/env")
        && lib.any (b: lib.hasInfix "SUPER, Return, Terminal, exec, $terminal" b) binds
        && lib.any (b: lib.hasInfix "SUPER, Space, Launch apps, exec, $launcher" b) binds
        && lib.any (b: lib.hasInfix "SUPER SHIFT, B, Browser, exec, $browser" b) binds
        && !(lib.any (b: lib.hasInfix "uwsm-app" b) binds)
        && !(lib.any (e: lib.hasInfix "uwsm-app" e) execOnce);
    in
    if ok then
      pkgs.runCommand "omarchy-eval-hm-no-uwsm" { } "touch $out"
    else
      throw ''
        withUWSM = false must keep bare exec binds and HM hyprland systemd
        systemd=${toString cfg.wayland.windowManager.hyprland.systemd.enable}
        binds=${toString binds}
        execOnce=${toString execOnce}
      '';

  eval-shell-no-uwsm =
    let
      host = mkHost [
        self.nixosModules.omarchy
        {
          programs.omarchy.enable = true;
          programs.omarchy.shell.withUWSM = false;
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
      greeterCmd = cfg.services.displayManager.sddm.settings.Wayland.CompositorCommand or "";
      ok =
        cfg.services.displayManager.defaultSession == "hyprland"
        && !cfg.programs.hyprland.withUWSM
        && lib.hasInfix "start-hyprland" greeterCmd
        && lib.hasInfix "-- --config" greeterCmd;
    in
    if ok then
      pkgs.runCommand "omarchy-eval-shell-no-uwsm" { } "touch $out"
    else
      throw ''
        withUWSM = false must default SDDM to bare hyprland; greeter still uses start-hyprland
        defaultSession=${cfg.services.displayManager.defaultSession or "MISSING"}
        withUWSM=${toString cfg.programs.hyprland.withUWSM}
        greeterCmd=${greeterCmd}
      '';
}
