# Official Omarchy palettes.
# Color keys come from public basecamp/omarchy `themes/*/colors.toml` (master
# @ b71dcad96e9d0b2962b7d225828a5cb6000ad720, MIT). Icon names come from each
# pack's `icons.theme`. We do not invent hues; ANSI color0..15 follow
# Omarchy's published alias map (background/red/green/…/bright_foreground).
# GTK theme is derived from `mode`. Hyprland border overrides are copied when
# the upstream file defines them.
#
# Source files live in ./official-themes/<name>/{colors.toml,icons.theme,
# neovim.lua?, btop.theme?}. neovim.lua is copied from basecamp/omarchy when
# the pack ships one; btop.theme likewise, otherwise generated from the
# official template and colors.toml.
let
  names = [
    "catppuccin"
    "catppuccin-latte"
    "ethereal"
    "everforest"
    "flexoki-light"
    "gruvbox"
    "hackerman"
    "kanagawa"
    "last-horizon"
    "lumon"
    "lupine"
    "matte-black"
    "miasma"
    "nord"
    "osaka-jade"
    "retro-82"
    "ristretto"
    "rose-pine"
    "solitude"
    "tokyo-night"
    "vantablack"
    "white"
  ];

  stripHash =
    value:
    if builtins.isString value && builtins.substring 0 1 value == "#" then
      builtins.substring 1 (builtins.stringLength value - 1) value
    else
      value;

  get =
    raw: key: default:
    if builtins.hasAttr key raw then builtins.getAttr key raw else default;

  hexOf =
    raw: key: default:
    stripHash (get raw key default);

  readIcon =
    name:
    let
      raw = builtins.readFile (./official-themes + "/${name}/icons.theme");
    in
    builtins.replaceStrings [ "\n" "\r" " " "\t" ] [ "" "" "" "" ] raw;

  load =
    name:
    let
      raw = builtins.fromTOML (builtins.readFile (./official-themes + "/${name}/colors.toml"));
      mode = raw.mode;
      accent = stripHash raw.accent;
      background = stripHash raw.background;
      foreground = stripHash raw.foreground;
      brightForeground = hexOf raw "bright_foreground" foreground;
      muted = hexOf raw "muted" background;
      selection = hexOf raw "selection" accent;
      red = stripHash raw.red;
      yellow = stripHash raw.yellow;
      green = stripHash raw.green;
      cyan = stripHash raw.cyan;
      blue = stripHash raw.blue;
      magenta = stripHash raw.magenta;
      orange = hexOf raw "orange" yellow;
      brown = hexOf raw "brown" orange;
      brightRed = hexOf raw "bright_red" red;
      brightYellow = hexOf raw "bright_yellow" yellow;
      brightGreen = hexOf raw "bright_green" green;
      brightCyan = hexOf raw "bright_cyan" cyan;
      brightBlue = hexOf raw "bright_blue" blue;
      brightMagenta = hexOf raw "bright_magenta" magenta;
    in
    {
      inherit
        name
        mode
        accent
        background
        foreground
        brightForeground
        muted
        selection
        red
        yellow
        orange
        green
        cyan
        blue
        magenta
        brown
        brightRed
        brightYellow
        brightGreen
        brightCyan
        brightBlue
        brightMagenta
        ;
      gtkTheme = if mode == "light" then "Adwaita" else "Adwaita-dark";
      iconTheme = readIcon name;
      cursor = brightForeground;
      selectionForeground = brightForeground;
      selectionBackground = selection;
      darkBackground = hexOf raw "dark_background" background;
      darkerBackground = hexOf raw "darker_background" background;
      lighterBackground = hexOf raw "lighter_background" background;
      darkForeground = hexOf raw "dark_foreground" muted;
      lightForeground = hexOf raw "light_foreground" foreground;
      # Official ANSI aliases from omarchy-theme-color.
      color0 = background;
      color1 = red;
      color2 = green;
      color3 = yellow;
      color4 = blue;
      color5 = magenta;
      color6 = cyan;
      color7 = foreground;
      color8 = muted;
      color9 = brightRed;
      color10 = brightGreen;
      color11 = brightYellow;
      color12 = brightBlue;
      color13 = brightMagenta;
      color14 = brightCyan;
      color15 = brightForeground;
      hyprlandActiveBorder = get raw "hyprland_active_border" null;
      hyprlandInactiveBorder = get raw "hyprland_inactive_border" null;
    };
in
builtins.listToAttrs (
  map (name: {
    inherit name;
    value = load name;
  }) names
)
