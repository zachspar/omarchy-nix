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
}:
let
  palettes = import ../../modules/shared/palettes.nix;

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
        accent = "${hex p.accent}"
        cursor = "${hex p.cursor}"
        foreground = "${hex p.foreground}"
        background = "${hex p.background}"
        selection_foreground = "${hex p.selectionForeground}"
        selection_background = "${hex p.selectionBackground}"
        color0 = "${hex p.color0}"
        color1 = "${hex p.color1}"
        color2 = "${hex p.color2}"
        color3 = "${hex p.color3}"
        color4 = "${hex p.color4}"
        color5 = "${hex p.color5}"
        color6 = "${hex p.color6}"
        color7 = "${hex p.color7}"
        color8 = "${hex p.color8}"
        color9 = "${hex p.color9}"
        color10 = "${hex p.color10}"
        color11 = "${hex p.color11}"
        color12 = "${hex p.color12}"
        color13 = "${hex p.color13}"
        color14 = "${hex p.color14}"
        color15 = "${hex p.color15}"
      '';
      hyprland = ''
        general {
          col.active_border = rgba(${p.accent}ee)
          col.inactive_border = rgba(${p.color0}aa)
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
      ${lib.optionalString (t.mode == "light") ''
        : > "$out/share/omarchy/themes/${t.name}/light.mode"
      ''}
    '') (lib.attrValues rendered)}
  '';

  schemas = "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}";

  themeSet = writeShellApplication {
    name = "omarchy-theme-set";
    runtimeInputs = [
      coreutils
      findutils
      gnused
      glib
      procps
    ];
    text = ''
      export XDG_DATA_DIRS="${schemas}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      user_themes="$config_home/omarchy/themes"
      system_themes="''${OMARCHY_THEME_DIR:-${themesDrv}/share/omarchy/themes}"
      current_dir="$state_home/omarchy/current"
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

      # Built-in palettes ship hyprlock/mako/waybar snippets. User themes that
      # only drop colors.toml get the same files generated so one command still
      # retints lock, notifications, and the bar.
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
        if [ -f "$current_dir/light.mode" ]; then
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
          cp "$current_dir/ghostty" "$ghostty_theme"
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

        # hyprlock has no reload IPC. It sources current/hyprlock.conf the next
        # time it starts. A lock already on screen keeps its old colors.

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
        ""|-h|--help)
          echo "usage: omarchy-theme-set <theme>" >&2
          echo "       omarchy-theme-set --list|--next" >&2
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
    screenshot
    themesDrv
  ];
  meta = {
    description = "Omarchy theme switcher, theme list/next, and screenshot helper";
    license = lib.licenses.mit;
    mainProgram = "omarchy-theme-set";
    platforms = lib.platforms.linux;
  };
}
