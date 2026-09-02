# Official Omarchy greeter / unlock assets from basecamp/omarchy (MIT,
# David Heinemeier Hansson). Sparse-checkout of the SDDM theme chrome,
# the Plymouth script theme, and each pack's unlock.png — no preview art.
{
  fetchgit,
}:
let
  palettes = import ../../modules/shared/palettes.nix;
  names = builtins.attrNames palettes;
in
fetchgit {
  url = "https://github.com/basecamp/omarchy.git";
  rev = "b71dcad96e9d0b2962b7d225828a5cb6000ad720";
  sparseCheckout = [
    "default/sddm/omarchy"
    "default/plymouth"
  ]
  ++ map (name: "themes/${name}/unlock.png") names;
  hash = "sha256-vDx1EGsIpbvpBNVwEBRD7yhuKIozwojTD/BRz8q2IHA=";
}
