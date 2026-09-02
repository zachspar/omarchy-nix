{
  pkgs,
  ...
}:
{
  networking.hostName = "omarchy";
  time.timeZone = "UTC";

  # Import hardware-configuration.nix and set boot.loader on a real host.

  # Master switch. All four pillars default to on; override any of them.
  programs.omarchy.enable = true;
  # programs.omarchy.shell.enable = true;
  # SDDM greeter + Plymouth unlock art are on with the shell pillar.
  # Autologin stays off. FDE unlock is Plymouth / cryptsetup, not SDDM.
  # programs.omarchy.shell.greeter.autoLogin.enable = true;
  # programs.omarchy.shell.greeter.autoLogin.user = "alice";
  # programs.omarchy.shell.greeter.compositor = "weston";
  # programs.omarchy.shell.greeter.logo = ./unlock.png;
  # programs.omarchy.theme.enable = true;
  # programs.omarchy.theme.name = "tokyo-night";
  # programs.omarchy.apps.enable = true;
  # programs.omarchy.storage.enable = true;

  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [ pkgs.git ];
  };

  # REQUIRED for an Omarchy-equivalent machine: LUKS2 + Btrfs `@` / `@home`
  # + Snapper. This module will not reformat disks. Uncomment and fill in
  # your UUIDs (see README "Storage").
  #
  # programs.omarchy.storage.luks.device = "/dev/disk/by-uuid/YOUR-LUKS-UUID";
  # fileSystems."/" = {
  #   device = "/dev/mapper/cryptroot";
  #   fsType = "btrfs";
  #   options = [ "subvol=@" "compress=zstd" ];
  # };
  # fileSystems."/home" = {
  #   device = "/dev/mapper/cryptroot";
  #   fsType = "btrfs";
  #   options = [ "subvol=@home" "compress=zstd" ];
  # };
  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/YOUR-ESP-UUID";
  #   fsType = "vfat";
  # };
  #
  # Create `.snapshots` under `@` and `@home` (or mount `@.snapshots` at
  # `/.snapshots`) before Snapper will take rollbacks.

  system.stateVersion = "25.11";
}
