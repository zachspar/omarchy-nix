# Official Omarchy theme wallpapers from basecamp/omarchy (MIT).
# Sparse-checkout of `themes/*/backgrounds` only — no preview art, no Lua.
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
  sparseCheckout = map (name: "themes/${name}/backgrounds") names;
  hash = "sha256-s3c3MKL8dqiEKi4C6JEJtoSQ6SnyD8X1Y0Cclq5V+XE=";
}
