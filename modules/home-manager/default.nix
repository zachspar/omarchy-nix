{
  lib,
  osConfig ? { },
  ...
}:
let
  osOmarchy = osConfig.programs.omarchy or { };
  osEnabled = osOmarchy.enable or false;
in
{
  imports = [
    ../shared/options.nix
    ./hyprland.nix
    ./shell.nix
    ./walker.nix
    ./theme.nix
    ./terminal.nix
    ./apps.nix
    ./neovim.nix
  ];

  # When composed under NixOS, inherit the host's programs.omarchy flags so
  # the user module stays in lockstep. Standalone Home Manager users set
  # programs.omarchy.enable themselves. withUWSM and the package knobs must
  # follow the host — Super+Return and systemd-vs-UWSM are those values.
  config = lib.mkIf osEnabled {
    programs.omarchy = {
      enable = lib.mkDefault true;
      shell.enable = lib.mkDefault osOmarchy.shell.enable;
      shell.withUWSM = lib.mkDefault osOmarchy.shell.withUWSM;
      shell.terminalPackage = lib.mkDefault osOmarchy.shell.terminalPackage;
      shell.launcherPackage = lib.mkDefault osOmarchy.shell.launcherPackage;
      shell.barPackage = lib.mkDefault osOmarchy.shell.barPackage;
      shell.lockPackage = lib.mkDefault osOmarchy.shell.lockPackage;
      shell.idlePackage = lib.mkDefault osOmarchy.shell.idlePackage;
      shell.notificationPackage = lib.mkDefault osOmarchy.shell.notificationPackage;
      shell.nightlightPackage = lib.mkDefault osOmarchy.shell.nightlightPackage;
      shell.osdPackage = lib.mkDefault osOmarchy.shell.osdPackage;
      theme.enable = lib.mkDefault osOmarchy.theme.enable;
      theme.name = lib.mkDefault osOmarchy.theme.name;
      apps.enable = lib.mkDefault osOmarchy.apps.enable;
      apps.browser = lib.mkDefault osOmarchy.apps.browser;
      apps.fileManager = lib.mkDefault osOmarchy.apps.fileManager;
      apps.editor = lib.mkDefault osOmarchy.apps.editor;
      storage.enable = lib.mkDefault osOmarchy.storage.enable;
    };
  };
}
