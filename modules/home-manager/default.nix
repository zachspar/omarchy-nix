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
  # programs.omarchy.enable themselves.
  config = lib.mkIf osEnabled {
    programs.omarchy = {
      enable = lib.mkDefault true;
      shell.enable = lib.mkDefault (osOmarchy.shell.enable or true);
      theme.enable = lib.mkDefault (osOmarchy.theme.enable or true);
      theme.name = lib.mkDefault (osOmarchy.theme.name or "tokyo-night");
      apps.enable = lib.mkDefault (osOmarchy.apps.enable or true);
      storage.enable = lib.mkDefault (osOmarchy.storage.enable or true);
    };
  };
}
