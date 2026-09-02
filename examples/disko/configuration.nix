{
  pkgs,
  ...
}:
{
  networking.hostName = "omarchy";
  time.timeZone = "UTC";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  programs.omarchy.enable = true;

  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [ pkgs.git ];
  };

  # =====================================================================
  # DANGER: this formats the disk named below. Every partition is wiped.
  # Point `device` at a throwaway disk or VM image, then run:
  #
  #   sudo nix run github:nix-community/disko -- \
  #     --mode destroy,format,mount --flake .#omarchy
  #   sudo nixos-install --flake .#omarchy
  #
  # Leave `storage.disko.enable` off (the default) unless you mean it.
  # =====================================================================
  programs.omarchy.storage.disko.enable = true;
  programs.omarchy.storage.disko.device = "/dev/vda"; # CHANGE THIS

  # Opt-in Limine + Snapper boot-menu rollback (replaces systemd-boot):
  # programs.omarchy.storage.limine.enable = true;

  # disko owns fileSystems and boot.initrd.luks.devices. Do not also set
  # storage.luks.device or a hardware-configuration.nix that restates them.

  system.stateVersion = "25.11";
}
