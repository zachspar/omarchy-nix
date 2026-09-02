{
  lib,
  writeText,
  writeShellApplication,
  runCommand,
  symlinkJoin,
  coreutils,
  findutils,
  gnused,
  glib,
  gsettings-desktop-schemas,
  grim,
  slurp,
  satty,
  wl-clipboard,
  procps,
  swaybg,
  fetchgit,
  walker,
  elephant,
}:
let
  palettes = import ../../modules/shared/palettes.nix;
  officialBackgrounds = import ./official-backgrounds.nix { inherit fetchgit; };

  hex = value: if lib.hasPrefix "#" value then value else "#${value}";

  # "1a1b26" / "#1a1b26" -> "26, 27, 38" for hyprlock rgba().
  hexToRgb =
    value:
    let
      h = lib.toLower (lib.removePrefix "#" value);
      byte = offset: lib.fromHexString (builtins.substring offset 2 h);
    in
    "${toString (byte 0)}, ${toString (byte 2)}, ${toString (byte 4)}";

  render =
    name: p:
    let
      colorsToml = ''
        mode = "${p.mode}"

        accent = "${hex p.accent}"
        selection = "${hex p.selection}"
        muted = "${hex p.muted}"

        background = "${hex p.background}"
        dark_background = "${hex p.darkBackground}"
        darker_background = "${hex p.darkerBackground}"
        lighter_background = "${hex p.lighterBackground}"

        foreground = "${hex p.foreground}"
        dark_foreground = "${hex p.darkForeground}"
        light_foreground = "${hex p.lightForeground}"
        bright_foreground = "${hex p.brightForeground}"

        red = "${hex p.red}"
        yellow = "${hex p.yellow}"
        orange = "${hex p.orange}"
        green = "${hex p.green}"
        cyan = "${hex p.cyan}"
        blue = "${hex p.blue}"
        magenta = "${hex p.magenta}"
        brown = "${hex p.brown}"

        bright_red = "${hex p.brightRed}"
        bright_yellow = "${hex p.brightYellow}"
        bright_green = "${hex p.brightGreen}"
        bright_cyan = "${hex p.brightCyan}"
        bright_blue = "${hex p.brightBlue}"
        bright_magenta = "${hex p.brightMagenta}"
      ''
      + lib.optionalString (p.hyprlandActiveBorder != null) ''

        hyprland_active_border = "${p.hyprlandActiveBorder}"
      ''
      + lib.optionalString (p.hyprlandInactiveBorder != null) ''
        hyprland_inactive_border = "${p.hyprlandInactiveBorder}"
      '';
      activeBorder =
        if p.hyprlandActiveBorder != null then p.hyprlandActiveBorder else "rgba(${p.accent}ee)";
      inactiveBorder =
        if p.hyprlandInactiveBorder != null then p.hyprlandInactiveBorder else "rgba(595959aa)";
      hyprland = ''
        general {
          col.active_border = ${activeBorder}
          col.inactive_border = ${inactiveBorder}
        }
      '';
      ghostty = ''
        background = ${hex p.background}
        foreground = ${hex p.foreground}
        cursor-color = ${hex p.cursor}
        selection-background = ${hex p.selectionBackground}
        selection-foreground = ${hex p.selectionForeground}
        palette = 0=${hex p.color0}
        palette = 1=${hex p.color1}
        palette = 2=${hex p.color2}
        palette = 3=${hex p.color3}
        palette = 4=${hex p.color4}
        palette = 5=${hex p.color5}
        palette = 6=${hex p.color6}
        palette = 7=${hex p.color7}
        palette = 8=${hex p.color8}
        palette = 9=${hex p.color9}
        palette = 10=${hex p.color10}
        palette = 11=${hex p.color11}
        palette = 12=${hex p.color12}
        palette = 13=${hex p.color13}
        palette = 14=${hex p.color14}
        palette = 15=${hex p.color15}
      '';
      gtk = ''
        mode=${p.mode}
        gtk-theme=${p.gtkTheme}
        icon-theme=${p.iconTheme}
      '';
      # Color tokens only — Home Manager owns lock layout and sources this file.
      hyprlock = ''
        $color = rgba(${hexToRgb p.background}, 1.0)
        $inner_color = rgba(${hexToRgb p.background}, 0.8)
        $outer_color = rgba(${hexToRgb p.foreground}, 1.0)
        $font_color = rgba(${hexToRgb p.foreground}, 1.0)
        $check_color = rgba(${hexToRgb p.accent}, 1.0)
      '';
      # Color keys only — mako includes this after the structural HM config.
      mako = ''
        text-color=${hex p.foreground}
        border-color=${hex p.accent}
        background-color=${hex p.background}
      '';
      waybar = ''
        @define-color foreground ${hex p.foreground};
        @define-color background ${hex p.background};
      '';
      # GTK CSS tokens consumed by Walker’s omarchy-default theme.
      walkerCss = ''
        @define-color selected-text ${hex p.accent};
        @define-color text ${hex p.foreground};
        @define-color base ${hex p.background};
        @define-color border ${hex p.foreground};
        @define-color foreground ${hex p.foreground};
        @define-color background ${hex p.background};
      '';
      # Omarchy default/themed/btop.theme.tpl, filled from colors.toml.
      # Hand-written themes/*/btop.theme win when present.
      generatedBtop = ''
        # Main background, empty for terminal default, need to be empty if you want transparent background
        theme[main_bg]="${hex p.background}"

        # Main text color
        theme[main_fg]="${hex p.foreground}"

        # Title color for boxes
        theme[title]="${hex p.foreground}"

        # Highlight color for keyboard shortcuts
        theme[hi_fg]="${hex p.accent}"

        # Background color of selected item in processes box
        theme[selected_bg]="${hex p.selection}"

        # Foreground color of selected item in processes box
        theme[selected_fg]="${hex p.accent}"

        # Color of inactive/disabled text
        theme[inactive_fg]="${hex p.muted}"

        # Color of text appearing on top of graphs, i.e uptime and current network graph scaling
        theme[graph_text]="${hex p.lightForeground}"

        # Background color of the percentage meters
        theme[meter_bg]="${hex p.selection}"

        # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
        theme[proc_misc]="${hex p.lightForeground}"

        # CPU, Memory, Network, Proc box outline colors
        theme[cpu_box]="${hex p.magenta}"
        theme[mem_box]="${hex p.green}"
        theme[net_box]="${hex p.red}"
        theme[proc_box]="${hex p.accent}"

        # Box divider line and small boxes line color
        theme[div_line]="${hex p.muted}"

        # Temperature graph color (Green -> Yellow -> Red)
        theme[temp_start]="${hex p.green}"
        theme[temp_mid]="${hex p.yellow}"
        theme[temp_end]="${hex p.red}"

        # CPU graph colors (Teal -> Blue -> Magenta)
        theme[cpu_start]="${hex p.cyan}"
        theme[cpu_mid]="${hex p.blue}"
        theme[cpu_end]="${hex p.magenta}"

        # Mem/Disk free meter
        theme[free_start]="${hex p.magenta}"
        theme[free_mid]="${hex p.blue}"
        theme[free_end]="${hex p.cyan}"

        # Mem/Disk cached meter
        theme[cached_start]="${hex p.blue}"
        theme[cached_mid]="${hex p.cyan}"
        theme[cached_end]="${hex p.magenta}"

        # Mem/Disk available meter
        theme[available_start]="${hex p.yellow}"
        theme[available_mid]="${hex p.red}"
        theme[available_end]="${hex p.red}"

        # Mem/Disk used meter (Green -> Teal -> Blue)
        theme[used_start]="${hex p.green}"
        theme[used_mid]="${hex p.cyan}"
        theme[used_end]="${hex p.blue}"

        # Download graph colors
        theme[download_start]="${hex p.yellow}"
        theme[download_mid]="${hex p.red}"
        theme[download_end]="${hex p.red}"

        # Upload graph colors (Green -> Teal -> Blue)
        theme[upload_start]="${hex p.green}"
        theme[upload_mid]="${hex p.cyan}"
        theme[upload_end]="${hex p.blue}"

        # Process box color gradient for threads, mem and cpu usage
        theme[process_start]="${hex p.cyan}"
        theme[process_mid]="${hex p.blue}"
        theme[process_end]="${hex p.magenta}"

        # Graph gradient colors (spectrum shades from background to foreground)
        theme[gradient_color_0]="${hex p.background}"
        theme[gradient_color_1]="${hex p.lighterBackground}"
        theme[gradient_color_2]="${hex p.selection}"
        theme[gradient_color_3]="${hex p.muted}"
        theme[gradient_color_4]="${hex p.darkForeground}"
        theme[gradient_color_5]="${hex p.foreground}"
        theme[gradient_color_6]="${hex p.lightForeground}"
        theme[gradient_color_7]="${hex p.brightForeground}"
      '';
      officialDir = ../../modules/shared/official-themes + "/${name}";
      neovimLua =
        if builtins.pathExists (officialDir + "/neovim.lua") then
          officialDir + "/neovim.lua"
        else
          writeText "${name}-neovim.lua" ''
            -- No official neovim.lua in this pack (basecamp/omarchy).
            -- omarchy-theme.lua applies highlight groups from neovim-palette.lua.
            return {
              {
                "LazyVim/LazyVim",
                opts = {
                  colorscheme = "omarchy",
                },
              },
            }
          '';
      btopTheme =
        if builtins.pathExists (officialDir + "/btop.theme") then
          officialDir + "/btop.theme"
        else
          writeText "${name}-btop.theme" generatedBtop;
      neovimPalette = writeText "${name}-neovim-palette.lua" ''
        -- Generated from official colors.toml.
        return {
          mode = "${p.mode}",
          background = "${hex p.background}",
          dark_background = "${hex p.darkBackground}",
          darker_background = "${hex p.darkerBackground}",
          lighter_background = "${hex p.lighterBackground}",
          foreground = "${hex p.foreground}",
          dark_foreground = "${hex p.darkForeground}",
          light_foreground = "${hex p.lightForeground}",
          bright_foreground = "${hex p.brightForeground}",
          muted = "${hex p.muted}",
          accent = "${hex p.accent}",
          selection = "${hex p.selection}",
          selection_foreground = "${hex p.selectionForeground}",
          selection_background = "${hex p.selectionBackground}",
          red = "${hex p.red}",
          yellow = "${hex p.yellow}",
          orange = "${hex p.orange}",
          green = "${hex p.green}",
          cyan = "${hex p.cyan}",
          blue = "${hex p.blue}",
          magenta = "${hex p.magenta}",
          brown = "${hex p.brown}",
          bright_red = "${hex p.brightRed}",
          bright_yellow = "${hex p.brightYellow}",
          bright_green = "${hex p.brightGreen}",
          bright_cyan = "${hex p.brightCyan}",
          bright_blue = "${hex p.brightBlue}",
          bright_magenta = "${hex p.brightMagenta}",
          cursor = "${hex p.cursor}",
        }
      '';
    in
    {
      inherit name;
      inherit (p) mode;
      colors = writeText "${name}-colors.toml" colorsToml;
      hyprland = writeText "${name}-hyprland.conf" hyprland;
      ghostty = writeText "${name}-ghostty" ghostty;
      gtk = writeText "${name}-gtk.conf" gtk;
      icons = writeText "${name}-icons.theme" "${p.iconTheme}\n";
      hyprlock = writeText "${name}-hyprlock.conf" hyprlock;
      mako = writeText "${name}-mako.ini" mako;
      waybar = writeText "${name}-waybar.css" waybar;
      walker = writeText "${name}-walker.css" walkerCss;
      neovim = neovimLua;
      neovimPalette = neovimPalette;
      btop = btopTheme;
    };

  rendered = lib.mapAttrs render palettes;

  themesDrv = runCommand "omarchy-themes" { } ''
    ${lib.concatMapStringsSep "\n" (t: ''
      mkdir -p "$out/share/omarchy/themes/${t.name}"
      cp ${t.colors} "$out/share/omarchy/themes/${t.name}/colors.toml"
      cp ${t.hyprland} "$out/share/omarchy/themes/${t.name}/hyprland.conf"
      cp ${t.ghostty} "$out/share/omarchy/themes/${t.name}/ghostty"
      cp ${t.gtk} "$out/share/omarchy/themes/${t.name}/gtk.conf"
      cp ${t.icons} "$out/share/omarchy/themes/${t.name}/icons.theme"
      cp ${t.hyprlock} "$out/share/omarchy/themes/${t.name}/hyprlock.conf"
      cp ${t.mako} "$out/share/omarchy/themes/${t.name}/mako.ini"
      cp ${t.waybar} "$out/share/omarchy/themes/${t.name}/waybar.css"
      cp ${t.walker} "$out/share/omarchy/themes/${t.name}/walker.css"
      cp ${t.neovim} "$out/share/omarchy/themes/${t.name}/neovim.lua"
      cp ${t.neovimPalette} "$out/share/omarchy/themes/${t.name}/neovim-palette.lua"
      cp ${t.btop} "$out/share/omarchy/themes/${t.name}/btop.theme"
      ${lib.optionalString (t.mode == "light") ''
        : > "$out/share/omarchy/themes/${t.name}/light.mode"
      ''}
      if [ -d ${officialBackgrounds}/themes/${t.name}/backgrounds ]; then
        cp -a ${officialBackgrounds}/themes/${t.name}/backgrounds \
          "$out/share/omarchy/themes/${t.name}/backgrounds"
      fi
    '') (lib.attrValues rendered)}
  '';

  schemas = "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}";

  restartWalker = writeShellApplication {
    name = "omarchy-restart-walker";
    runtimeInputs = [ procps ];
    text = ''
      restarted=0
      if command -v systemctl >/dev/null; then
        if systemctl --user restart omarchy-elephant.service >/dev/null 2>&1; then
          restarted=1
        fi
        if systemctl --user restart omarchy-walker.service >/dev/null 2>&1; then
          restarted=1
        fi
      fi
      if [ "$restarted" -eq 0 ]; then
        pkill -x elephant >/dev/null 2>&1 || true
        pkill -f "walker --gapplication-service" >/dev/null 2>&1 || true
      fi
    '';
  };

  launchWalker = writeShellApplication {
    name = "omarchy-launch-walker";
    runtimeInputs = [
      procps
      walker
      elephant
    ];
    text = ''
      if ! pgrep -x elephant >/dev/null; then
        elephant &
      fi
      if ! pgrep -f "walker --gapplication-service" >/dev/null; then
        GSK_RENDERER=cairo walker --gapplication-service &
      fi
      exec env GSK_RENDERER=cairo walker --width 644 --maxheight 300 --minheight 300 "$@"
    '';
  };

  themeSet = writeShellApplication {
    name = "omarchy-theme-set";
    runtimeInputs = [
      coreutils
      findutils
      gnused
      glib
      procps
      swaybg
      restartWalker
    ];
    text = ''
      export XDG_DATA_DIRS="${schemas}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      user_themes="$config_home/omarchy/themes"
      system_themes="''${OMARCHY_THEME_DIR:-${themesDrv}/share/omarchy/themes}"
      current_dir="$state_home/omarchy/current"
      wallpaper_link="$state_home/omarchy/background"
      ghostty_theme="$config_home/ghostty/themes/omarchy"

      list_themes() {
        {
          if [ -d "$user_themes" ]; then
            find "$user_themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
          fi
          if [ -n "$system_themes" ] && [ -d "$system_themes" ]; then
            find "$system_themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
          fi
        } | sort -u
      }

      resolve_theme() {
        name="$1"
        if [ -d "$user_themes/$name" ]; then
          printf '%s\n' "$user_themes/$name"
          return
        fi
        if [ -n "$system_themes" ] && [ -d "$system_themes/$name" ]; then
          printf '%s\n' "$system_themes/$name"
          return
        fi
        echo "omarchy-theme-set: unknown theme '$name'" >&2
        echo "Available:" >&2
        list_themes >&2
        exit 1
      }

      toml_color() {
        key="$1"
        file="$2"
        sed -n "s/^''${key}[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -n1
      }

      hex_to_rgb() {
        hex="''${1#\#}"
        printf '%d, %d, %d' "0x''${hex:0:2}" "0x''${hex:2:2}" "0x''${hex:4:2}"
      }

      is_image() {
        case "''${1,,}" in
          *.jpg|*.jpeg|*.png|*.gif|*.bmp|*.webp) return 0 ;;
          *) return 1 ;;
        esac
      }

      list_backgrounds() {
        name="$1"
        src="$2"
        {
          if [ -d "$config_home/omarchy/backgrounds/$name" ]; then
            find -L "$config_home/omarchy/backgrounds/$name" -maxdepth 1 -type f -print
          fi
          if [ -d "$current_dir/backgrounds" ]; then
            find -L "$current_dir/backgrounds" -maxdepth 1 -type f -print
          elif [ -n "$src" ] && [ -d "$src/backgrounds" ]; then
            find -L "$src/backgrounds" -maxdepth 1 -type f -print
          elif [ -d "$user_themes/$name/backgrounds" ]; then
            find -L "$user_themes/$name/backgrounds" -maxdepth 1 -type f -print
          fi
        } | while IFS= read -r file; do
          if is_image "$file"; then
            printf '%s\n' "$file"
          fi
        done | sort -u
      }

      current_wallpaper() {
        if [ -e "$wallpaper_link" ]; then
          readlink -f "$wallpaper_link" 2>/dev/null || true
        fi
      }

      start_wallpaper() {
        file="$1"
        [ -n "$file" ] && [ -f "$file" ] || return 0
        mkdir -p "$(dirname "$wallpaper_link")"
        ln -nsf "$file" "$wallpaper_link"
        if [ -d "$current_dir" ]; then
          ln -nsf "$file" "$current_dir/background"
        fi
        if command -v systemctl >/dev/null; then
          if systemctl --user restart omarchy-wallpaper.service >/dev/null 2>&1; then
            return 0
          fi
        fi
        if command -v swaybg >/dev/null; then
          pkill -x swaybg >/dev/null 2>&1 || true
          swaybg -i "$file" -m fill >/dev/null 2>&1 &
          disown || true
        fi
      }

      apply_theme_wallpaper() {
        name="$1"
        src="$2"
        mapfile -t backgrounds < <(list_backgrounds "$name" "$src")
        if [ "''${#backgrounds[@]}" -eq 0 ]; then
          echo "omarchy: no wallpaper for $name (drop images in ~/.config/omarchy/themes/$name/backgrounds/ or ~/.config/omarchy/backgrounds/$name/)" >&2
          return 0
        fi
        current="$(current_wallpaper)"
        chosen="''${backgrounds[0]}"
        if [ -n "$current" ]; then
          for i in "''${!backgrounds[@]}"; do
            resolved="$(readlink -f "''${backgrounds[$i]}" 2>/dev/null || true)"
            if [ "''${backgrounds[$i]}" = "$current" ] || [ "$resolved" = "$current" ]; then
              chosen="''${backgrounds[$i]}"
              break
            fi
          done
        fi
        start_wallpaper "$chosen"
      }

      next_wallpaper() {
        name=""
        if [ -f "$current_dir/theme.name" ]; then
          name="$(tr -d '[:space:]' < "$current_dir/theme.name")"
        fi
        src=""
        if [ -n "$name" ]; then
          src="$(resolve_theme "$name" 2>/dev/null || true)"
        fi
        mapfile -t backgrounds < <(list_backgrounds "$name" "$src")
        if [ "''${#backgrounds[@]}" -eq 0 ]; then
          echo "omarchy-theme-bg-next: no wallpapers for ''${name:-current theme}" >&2
          echo "Drop jpg/png/webp files in ~/.config/omarchy/themes/<name>/backgrounds/ or ~/.config/omarchy/backgrounds/<name>/" >&2
          exit 1
        fi
        current="$(current_wallpaper)"
        idx=0
        for i in "''${!backgrounds[@]}"; do
          resolved="$(readlink -f "''${backgrounds[$i]}" 2>/dev/null || true)"
          if [ "''${backgrounds[$i]}" = "$current" ] || [ "$resolved" = "$current" ]; then
            idx=$((i + 1))
            break
          fi
        done
        if [ "$idx" -ge "''${#backgrounds[@]}" ]; then
          idx=0
        fi
        start_wallpaper "''${backgrounds[$idx]}"
        echo "omarchy: wallpaper ''${backgrounds[$idx]}"
      }

      # Built-in palettes ship hyprlock/mako/waybar/walker/neovim/btop snippets.
      # User themes that only drop colors.toml get the same files generated so
      # one command still retints lock, notifications, the bar, launcher,
      # Neovim, and btop.
      ensure_surface_snippets() {
        colors="$current_dir/colors.toml"
        if [ ! -f "$colors" ]; then
          return
        fi

        if [ ! -f "$current_dir/mako.ini" ] && [ -f "$current_dir/mako" ]; then
          cp "$current_dir/mako" "$current_dir/mako.ini"
        fi

        bg="$(toml_color background "$colors")"
        fg="$(toml_color foreground "$colors")"
        accent="$(toml_color accent "$colors")"
        if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
          return
        fi

        muted="$(toml_color muted "$colors")"
        selection="$(toml_color selection "$colors")"
        dark_bg="$(toml_color dark_background "$colors")"
        darker_bg="$(toml_color darker_background "$colors")"
        lighter_bg="$(toml_color lighter_background "$colors")"
        dark_fg="$(toml_color dark_foreground "$colors")"
        light_fg="$(toml_color light_foreground "$colors")"
        bright_fg="$(toml_color bright_foreground "$colors")"
        red="$(toml_color red "$colors")"
        yellow="$(toml_color yellow "$colors")"
        orange="$(toml_color orange "$colors")"
        green="$(toml_color green "$colors")"
        cyan="$(toml_color cyan "$colors")"
        blue="$(toml_color blue "$colors")"
        magenta="$(toml_color magenta "$colors")"
        brown="$(toml_color brown "$colors")"
        bright_red="$(toml_color bright_red "$colors")"
        bright_yellow="$(toml_color bright_yellow "$colors")"
        bright_green="$(toml_color bright_green "$colors")"
        bright_cyan="$(toml_color bright_cyan "$colors")"
        bright_blue="$(toml_color bright_blue "$colors")"
        bright_magenta="$(toml_color bright_magenta "$colors")"
        mode="$(toml_color mode "$colors")"
        muted="''${muted:-$bg}"
        selection="''${selection:-$accent}"
        dark_bg="''${dark_bg:-$bg}"
        darker_bg="''${darker_bg:-$bg}"
        lighter_bg="''${lighter_bg:-$bg}"
        dark_fg="''${dark_fg:-$muted}"
        light_fg="''${light_fg:-$fg}"
        bright_fg="''${bright_fg:-$fg}"
        red="''${red:-$fg}"
        yellow="''${yellow:-$fg}"
        orange="''${orange:-$yellow}"
        green="''${green:-$fg}"
        cyan="''${cyan:-$fg}"
        blue="''${blue:-$accent}"
        magenta="''${magenta:-$fg}"
        brown="''${brown:-$orange}"
        bright_red="''${bright_red:-$red}"
        bright_yellow="''${bright_yellow:-$yellow}"
        bright_green="''${bright_green:-$green}"
        bright_cyan="''${bright_cyan:-$cyan}"
        bright_blue="''${bright_blue:-$blue}"
        bright_magenta="''${bright_magenta:-$magenta}"
        mode="''${mode:-dark}"

        if [ ! -f "$current_dir/hyprlock.conf" ]; then
          bg_rgb="$(hex_to_rgb "$bg")"
          fg_rgb="$(hex_to_rgb "$fg")"
          accent_rgb="$(hex_to_rgb "$accent")"
          printf '%s\n' \
            "\$color = rgba(''${bg_rgb}, 1.0)" \
            "\$inner_color = rgba(''${bg_rgb}, 0.8)" \
            "\$outer_color = rgba(''${fg_rgb}, 1.0)" \
            "\$font_color = rgba(''${fg_rgb}, 1.0)" \
            "\$check_color = rgba(''${accent_rgb}, 1.0)" \
            > "$current_dir/hyprlock.conf"
        fi

        if [ ! -f "$current_dir/mako.ini" ]; then
          printf '%s\n' \
            "text-color=''${fg}" \
            "border-color=''${accent}" \
            "background-color=''${bg}" \
            > "$current_dir/mako.ini"
        fi

        if [ ! -f "$current_dir/waybar.css" ]; then
          printf '%s\n' \
            "@define-color foreground ''${fg};" \
            "@define-color background ''${bg};" \
            > "$current_dir/waybar.css"
        fi

        if [ ! -f "$current_dir/walker.css" ]; then
          printf '%s\n' \
            "@define-color selected-text ''${accent};" \
            "@define-color text ''${fg};" \
            "@define-color base ''${bg};" \
            "@define-color border ''${fg};" \
            "@define-color foreground ''${fg};" \
            "@define-color background ''${bg};" \
            > "$current_dir/walker.css"
        fi

        if [ ! -f "$current_dir/neovim-palette.lua" ]; then
          printf '%s\n' \
            "return {" \
            "  mode = \"''${mode}\"," \
            "  background = \"''${bg}\"," \
            "  dark_background = \"''${dark_bg}\"," \
            "  darker_background = \"''${darker_bg}\"," \
            "  lighter_background = \"''${lighter_bg}\"," \
            "  foreground = \"''${fg}\"," \
            "  dark_foreground = \"''${dark_fg}\"," \
            "  light_foreground = \"''${light_fg}\"," \
            "  bright_foreground = \"''${bright_fg}\"," \
            "  muted = \"''${muted}\"," \
            "  accent = \"''${accent}\"," \
            "  selection = \"''${selection}\"," \
            "  selection_foreground = \"''${bright_fg}\"," \
            "  selection_background = \"''${selection}\"," \
            "  red = \"''${red}\"," \
            "  yellow = \"''${yellow}\"," \
            "  orange = \"''${orange}\"," \
            "  green = \"''${green}\"," \
            "  cyan = \"''${cyan}\"," \
            "  blue = \"''${blue}\"," \
            "  magenta = \"''${magenta}\"," \
            "  brown = \"''${brown}\"," \
            "  bright_red = \"''${bright_red}\"," \
            "  bright_yellow = \"''${bright_yellow}\"," \
            "  bright_green = \"''${bright_green}\"," \
            "  bright_cyan = \"''${bright_cyan}\"," \
            "  bright_blue = \"''${bright_blue}\"," \
            "  bright_magenta = \"''${bright_magenta}\"," \
            "  cursor = \"''${bright_fg}\"," \
            "}" \
            > "$current_dir/neovim-palette.lua"
        fi

        if [ ! -f "$current_dir/neovim.lua" ]; then
          printf '%s\n' \
            "return {" \
            "  {" \
            "    \"LazyVim/LazyVim\"," \
            "    opts = {" \
            "      colorscheme = \"omarchy\"," \
            "    }," \
            "  }," \
            "}" \
            > "$current_dir/neovim.lua"
        fi

        if [ ! -f "$current_dir/btop.theme" ]; then
          printf '%s\n' \
            "theme[main_bg]=\"''${bg}\"" \
            "theme[main_fg]=\"''${fg}\"" \
            "theme[title]=\"''${fg}\"" \
            "theme[hi_fg]=\"''${accent}\"" \
            "theme[selected_bg]=\"''${selection}\"" \
            "theme[selected_fg]=\"''${accent}\"" \
            "theme[inactive_fg]=\"''${muted}\"" \
            "theme[graph_text]=\"''${light_fg}\"" \
            "theme[meter_bg]=\"''${selection}\"" \
            "theme[proc_misc]=\"''${light_fg}\"" \
            "theme[cpu_box]=\"''${magenta}\"" \
            "theme[mem_box]=\"''${green}\"" \
            "theme[net_box]=\"''${red}\"" \
            "theme[proc_box]=\"''${accent}\"" \
            "theme[div_line]=\"''${muted}\"" \
            "theme[temp_start]=\"''${green}\"" \
            "theme[temp_mid]=\"''${yellow}\"" \
            "theme[temp_end]=\"''${red}\"" \
            "theme[cpu_start]=\"''${cyan}\"" \
            "theme[cpu_mid]=\"''${blue}\"" \
            "theme[cpu_end]=\"''${magenta}\"" \
            "theme[free_start]=\"''${magenta}\"" \
            "theme[free_mid]=\"''${blue}\"" \
            "theme[free_end]=\"''${cyan}\"" \
            "theme[cached_start]=\"''${blue}\"" \
            "theme[cached_mid]=\"''${cyan}\"" \
            "theme[cached_end]=\"''${magenta}\"" \
            "theme[available_start]=\"''${yellow}\"" \
            "theme[available_mid]=\"''${red}\"" \
            "theme[available_end]=\"''${red}\"" \
            "theme[used_start]=\"''${green}\"" \
            "theme[used_mid]=\"''${cyan}\"" \
            "theme[used_end]=\"''${blue}\"" \
            "theme[download_start]=\"''${yellow}\"" \
            "theme[download_mid]=\"''${red}\"" \
            "theme[download_end]=\"''${red}\"" \
            "theme[upload_start]=\"''${green}\"" \
            "theme[upload_mid]=\"''${cyan}\"" \
            "theme[upload_end]=\"''${blue}\"" \
            "theme[process_start]=\"''${cyan}\"" \
            "theme[process_mid]=\"''${blue}\"" \
            "theme[process_end]=\"''${magenta}\"" \
            "theme[gradient_color_0]=\"''${bg}\"" \
            "theme[gradient_color_1]=\"''${lighter_bg}\"" \
            "theme[gradient_color_2]=\"''${selection}\"" \
            "theme[gradient_color_3]=\"''${muted}\"" \
            "theme[gradient_color_4]=\"''${dark_fg}\"" \
            "theme[gradient_color_5]=\"''${fg}\"" \
            "theme[gradient_color_6]=\"''${light_fg}\"" \
            "theme[gradient_color_7]=\"''${bright_fg}\"" \
            > "$current_dir/btop.theme"
        fi
      }

      reload_nvim() {
        runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        lua='lua require("omarchy-theme").apply()'
        if command -v nvim >/dev/null; then
          shopt -s nullglob
          for sock in "$runtime"/omarchy-nvim-*.sock "$runtime"/nvim.*.0 "$runtime"/nvim*.sock; do
            nvim --server "$sock" --remote-send "<Cmd>''${lua}<CR>" >/dev/null 2>&1 || true
          done
          shopt -u nullglob
        fi
        # SIGUSR1 is the Omarchy-compatible fallback when no listen socket exists.
        pkill -USR1 -x nvim >/dev/null 2>&1 || true
      }

      reload_btop() {
        mkdir -p "$config_home/btop/themes"
        if [ -f "$current_dir/btop.theme" ]; then
          ln -nsf "$current_dir/btop.theme" "$config_home/btop/themes/current.theme"
        fi
        pkill -USR2 -x btop >/dev/null 2>&1 || true
      }

      apply_theme() {
        name="$1"
        src="$(resolve_theme "$name")"
        mkdir -p "$(dirname "$current_dir")" "$(dirname "$ghostty_theme")"

        staging="$(mktemp -d)"
        cp -a "$src/." "$staging/"
        # Store themes are 555/444; make the staging copy writable so we can
        # record theme.name and generate missing lock/mako/waybar snippets.
        chmod -R u+w "$staging"
        printf '%s\n' "$name" > "$staging/theme.name"
        rm -rf "$current_dir"
        mv "$staging" "$current_dir"

        ensure_surface_snippets

        gtk_theme="Adwaita-dark"
        icon_theme="Yaru-blue"
        color_scheme="prefer-dark"
        if [ -f "$current_dir/light.mode" ] \
          || grep -q '^mode[[:space:]]*=[[:space:]]*"light"' "$current_dir/colors.toml" 2>/dev/null; then
          gtk_theme="Adwaita"
          color_scheme="prefer-light"
        fi
        if [ -f "$current_dir/icons.theme" ]; then
          icon_theme="$(tr -d '[:space:]' < "$current_dir/icons.theme")"
        fi
        if [ -f "$current_dir/gtk.conf" ]; then
          gtk_from_conf="$(sed -n 's/^gtk-theme=//p' "$current_dir/gtk.conf")"
          icon_from_conf="$(sed -n 's/^icon-theme=//p' "$current_dir/gtk.conf")"
          if [ -n "$gtk_from_conf" ]; then
            gtk_theme="$gtk_from_conf"
          fi
          if [ -n "$icon_from_conf" ]; then
            icon_theme="$icon_from_conf"
          fi
        fi

        if command -v gsettings >/dev/null; then
          gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" || true
          gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" || true
          gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" || true
        fi

        if [ -f "$current_dir/ghostty" ]; then
          mkdir -p "$(dirname "$ghostty_theme")"
          rm -f "$ghostty_theme"
          cp "$current_dir/ghostty" "$ghostty_theme"
          chmod u+w "$ghostty_theme" 2>/dev/null || true
          if command -v ghostty >/dev/null; then
            ghostty +reload-config >/dev/null 2>&1 || true
          fi
        fi

        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
          hyprctl reload >/dev/null 2>&1 || true
        fi

        # mako include= picks up current/mako.ini; reload in place (no restart).
        if command -v makoctl >/dev/null; then
          makoctl reload >/dev/null 2>&1 || true
        fi

        # SIGUSR2 re-parses Waybar CSS, including the @import of waybar.css.
        # Full restart is the fallback if the bar ignores imported-file changes.
        if command -v pkill >/dev/null; then
          pkill -USR2 -x waybar >/dev/null 2>&1 || true
        fi

        # Walker keeps a GTK service alive; CSS @import of walker.css is
        # re-read when that service restarts. Skip if Walker is not running.
        if command -v omarchy-restart-walker >/dev/null; then
          omarchy-restart-walker >/dev/null 2>&1 || true
        fi

        reload_nvim
        reload_btop

        # hyprlock has no reload IPC. It sources current/hyprlock.conf the next
        # time it starts. A lock already on screen keeps its old colors.

        # Chromium: Omarchy writes /etc/chromium/policies/managed/color.json as
        # root. We do not ship a sudoers helper; NixOS policies are declarative.

        apply_theme_wallpaper "$name" "$src"

        echo "omarchy: theme set to $name"
      }

      next_theme() {
        current=""
        if [ -f "$current_dir/theme.name" ]; then
          current="$(tr -d '[:space:]' < "$current_dir/theme.name")"
        fi
        mapfile -t themes < <(list_themes)
        if [ "''${#themes[@]}" -eq 0 ]; then
          echo "omarchy-theme-next: no themes installed" >&2
          exit 1
        fi
        idx=0
        for i in "''${!themes[@]}"; do
          if [ "''${themes[$i]}" = "$current" ]; then
            idx=$((i + 1))
            break
          fi
        done
        if [ "$idx" -ge "''${#themes[@]}" ]; then
          idx=0
        fi
        apply_theme "''${themes[$idx]}"
      }

      case "''${1:-}" in
        --list)
          list_themes
          ;;
        --next)
          next_theme
          ;;
        --bg-next)
          next_wallpaper
          ;;
        --bg-set)
          if [ -z "''${2:-}" ]; then
            echo "usage: omarchy-theme-set --bg-set <image>" >&2
            exit 1
          fi
          if [ ! -f "$2" ]; then
            echo "omarchy-theme-set: no such file: $2" >&2
            exit 1
          fi
          start_wallpaper "$2"
          echo "omarchy: wallpaper $2"
          ;;
        ""|-h|--help)
          echo "usage: omarchy-theme-set <theme>" >&2
          echo "       omarchy-theme-set --list|--next|--bg-next" >&2
          echo "       omarchy-theme-set --bg-set <image>" >&2
          echo "themes:" >&2
          list_themes >&2
          exit 1
          ;;
        *)
          apply_theme "$1"
          ;;
      esac
    '';
  };

  themeNext = writeShellApplication {
    name = "omarchy-theme-next";
    runtimeInputs = [ themeSet ];
    text = ''
      exec omarchy-theme-set --next
    '';
  };

  themeList = writeShellApplication {
    name = "omarchy-theme-list";
    runtimeInputs = [ themeSet ];
    text = ''
      exec omarchy-theme-set --list
    '';
  };

  themeBgNext = writeShellApplication {
    name = "omarchy-theme-bg-next";
    runtimeInputs = [ themeSet ];
    text = ''
      exec omarchy-theme-set --bg-next
    '';
  };

  themeBgSet = writeShellApplication {
    name = "omarchy-theme-bg-set";
    runtimeInputs = [ themeSet ];
    text = ''
      exec omarchy-theme-set --bg-set "$@"
    '';
  };

  wallpaper = writeShellApplication {
    name = "omarchy-wallpaper";
    runtimeInputs = [
      coreutils
      swaybg
    ];
    text = ''
      link="''${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/background"
      if [ ! -e "$link" ]; then
        echo "omarchy-wallpaper: no background set yet" >&2
        exit 0
      fi
      target="$(readlink -f "$link" || true)"
      if [ ! -f "$target" ]; then
        target="$link"
      fi
      if [ ! -f "$target" ]; then
        echo "omarchy-wallpaper: background path is not a file" >&2
        exit 0
      fi
      exec swaybg -i "$target" -m fill
    '';
  };

  screenshot = writeShellApplication {
    name = "omarchy-screenshot";
    runtimeInputs = [
      coreutils
      grim
      slurp
      satty
      wl-clipboard
    ];
    text = ''
      outdir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
      mkdir -p "$outdir"
      geom="$(slurp)" || exit 1
      grim -g "$geom" - | satty \
        --filename - \
        --fullscreen \
        --output-filename "$outdir/satty-$(date +%Y%m%d-%H%M%S).png"
    '';
  };
in
symlinkJoin {
  name = "omarchy-theme-tools";
  pname = "omarchy-theme-tools";
  version = "0.1.0";
  paths = [
    themeSet
    themeNext
    themeList
    themeBgNext
    themeBgSet
    wallpaper
    screenshot
    launchWalker
    restartWalker
    themesDrv
  ];
  meta = {
    description = "Omarchy theme switcher, Walker helpers, wallpaper helper, and screenshot helper";
    license = lib.licenses.mit;
    mainProgram = "omarchy-theme-set";
    platforms = lib.platforms.linux;
  };
}
