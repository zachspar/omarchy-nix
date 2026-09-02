{
  # programs.omarchy is inherited from the NixOS module via osConfig.
  # Standalone Home Manager users should set programs.omarchy.enable = true.

  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "25.11";
}
