# Chromium managed-policy fragment matching Omarchy's omarchy-theme-set-browser.
#
# Official packs do not ship chromium.theme. Omarchy generates it from
# default/themed/chromium.theme.tpl (`{{ background_rgb }}`) using the pack's
# colors.toml `background`, converts that RGB triple to hex, then writes:
#
#   {"BrowserThemeColor": "#rrggbb", "BrowserColorScheme": "device"}
#
# to /etc/chromium/policies/managed/color.json (and the Chrome / Brave
# siblings). NixOS lands the same JSON via programs.chromium.extraOpts
# (extra.json in the managed dir — Chromium reads every JSON there).
#
# The fallback grey is Omarchy's when no chromium.theme exists
# (bin/omarchy-theme-set-browser). Not an invented hue.
{ lib }:
let
  hex =
    value:
    let
      s = toString value;
    in
    if lib.hasPrefix "#" s then s else "#${s}";

  # Omarchy `hex_to_rgb`: printf "%d,%d,%d" (no spaces).
  toRgb =
    value:
    let
      h = lib.toLower (lib.removePrefix "#" (hex value));
      byte = offset: lib.fromHexString (builtins.substring offset 2 h);
    in
    "${toString (byte 0)},${toString (byte 2)},${toString (byte 4)}";

  omarchyFallbackHex = "#1c2027";

  fromColor =
    color:
    let
      themeHex = hex color;
    in
    {
      hex = themeHex;
      rgb = toRgb color;
      policy = {
        BrowserThemeColor = themeHex;
        BrowserColorScheme = "device";
      };
    };
in
{
  inherit omarchyFallbackHex fromColor;
  fromPalette = palette: fromColor palette.background;
  fallback = fromColor omarchyFallbackHex;
}
