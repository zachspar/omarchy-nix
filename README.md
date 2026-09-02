# omarchy-nix

A [Nix](https://nixos.org) flake that brings the [Omarchy](https://omarchy.org) desktop experience to NixOS.

Omarchy (DHH / [Omacom](https://omacom.io)) is an opinionated Arch desktop: Hyprland, Walker, Ghostty, one keybind that restyles the whole machine, a small curated app set, and **LUKS + Btrfs + Snapper** so you can roll back. This repository re-expresses that UX as importable NixOS and Home Manager modules under **`programs.omarchy`**.

This is a desktop experience, not a daemon. The option namespace is `programs.omarchy`, never `services.omarchy`.

The stack is a skeleton: the four pillars are stubbed, wired to nixpkgs where packages exist, and honest about gaps. Nothing here vendors unpublished Omarchy binaries.

## The four pillars

All four are **on by default** once you set `programs.omarchy.enable = true`. Each can be flipped independently.

| Pillar | What “done” looks like | This stub |
| --- | --- | --- |
| **shell** | Hyprland + Walker + Ghostty feels like Omarchy at first login | Enables `programs.hyprland` (UWSM), Ghostty, Walker, Waybar, Elephant (Walker 2.x backend, including menus/clipboard/calc/files/symbols), **hyprlock + hypridle** (lock on idle), and **mako** (notifications). Home Manager writes the Hyprland/Ghostty/lock baseline, Walker config + GTK CSS, and keybinds. |
| **theme** | One command / keybind flips GTK + Hyprland + terminal + icons + lock + notifications + bar + launcher + Neovim + btop + wallpaper together | `omarchy-theme-set <name>`, `omarchy-theme-next`, Walker theme picker on `Super+Ctrl+Shift+Space`. All official Omarchy packs. Wallpaper via swaybg. |
| **apps** | Browser, file manager, Neovim, screenshot + clipboard helpers | Chromium, Nautilus, Neovim, btop, grim/slurp/satty, wl-clipboard, cliphist. |
| **storage** | LUKS2 + Btrfs `@` / `@home` + Snapper rollback | Documents and wires Snapper; optionally opens a LUKS device you already created. **Does not reformat disks. Does not treat an unencrypted ext4 root as equivalent.** |

## Install Nix with Determinate

Use [Determinate Nix](https://docs.determinate.systems/). Do not use the classic `nixos.org/nix/install` scripts.

### Linux (not yet NixOS)

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install --determinate
```

### macOS

Install [Determinate.pkg](https://docs.determinate.systems/) from Determinate Systems (the graphical installer). Then use this flake from a Linux / NixOS machine or a remote builder — the modules are Linux-only.

### Already on NixOS

Add the Determinate module so the system runs Determinate Nix:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, determinate, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        determinate.nixosModules.default
        # ... your config, including programs.omarchy
      ];
    };
  };
}
```

First switch, point Nix at the Determinate cache so you do not compile Nix yourself:

```bash
sudo nixos-rebuild switch --flake .#your-host \
  --option extra-substituters https://install.determinate.systems \
  --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=
```

See [Determinate’s NixOS install notes](https://docs.determinate.systems/guides/advanced-installation/).

## Add this flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    omarchy-nix = {
      url = "github:zachspar/omarchy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { nixpkgs, home-manager, omarchy-nix, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        omarchy-nix.nixosModules.default
        home-manager.nixosModules.home-manager
        ./configuration.nix
        {
          programs.omarchy.enable = true;

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.youruser = {
            imports = [ omarchy-nix.homeManagerModules.default ];
            home.stateVersion = "25.11";
          };
        }
      ];
    };
  };
}
```

`nixosModules.default` and `nixosModules.omarchy` are the same module. Home Manager: `homeManagerModules.default` / `homeManagerModules.omarchy`.

A complete host sketch lives in [`examples/minimal`](examples/minimal).

Rebuild with flakes (Determinate enables them):

```bash
sudo nixos-rebuild switch --flake .#your-host
```

Do not use `nix-env`. Put packages in `environment.systemPackages`, `home.packages`, or `programs.omarchy.apps.extraPackages`.

## Enable and override

```nix
{
  programs.omarchy.enable = true;

  # All four default to true. Turn one off if you must:
  # programs.omarchy.shell.enable = false;
  # programs.omarchy.theme.enable = false;
  # programs.omarchy.apps.enable = false;
  # programs.omarchy.storage.enable = false;

  programs.omarchy.theme.name = "tokyo-night";

  # Swap the opinionated defaults for other nixpkgs packages:
  # programs.omarchy.apps.browser = pkgs.firefox;
  # programs.omarchy.shell.terminalPackage = pkgs.kitty;
}
```

Under Home Manager-as-a-NixOS-module, the HM module reads `osConfig.programs.omarchy` and enables the matching user stubs (Hyprland settings, Ghostty, theme apply-on-login). Standalone Home Manager users set `programs.omarchy.enable` themselves.

### Theme keybind and commands

| Action | How |
| --- | --- |
| Theme picker | `Super+Ctrl+Shift+Space` (Walker `menus:omarchythemes`) |
| Wallpaper picker | `Super+Ctrl+Space` (Walker `menus:omarchyBackgroundSelector`) |
| Cycle themes | `omarchy-theme-next` |
| Set a theme | `omarchy-theme-set tokyo-night` |
| List themes | `omarchy-theme-list` |
| Next wallpaper | `omarchy-theme-bg-next` |
| Set wallpaper | `omarchy-theme-bg-set ~/Pictures/wall.webp` |

Each flip updates GTK (`gsettings` color-scheme + theme), icon theme, Hyprland border colors, the Ghostty `omarchy` theme file, hyprlock color tokens, mako notification colors, Waybar CSS (`@foreground` / `@background`), Walker GTK CSS (`@selected-text` / `@text` / `@base` / `@border`), Neovim (official `neovim.lua` colorscheme, or palette highlight groups), btop (`themes/current.theme`), and the desktop wallpaper (swaybg).

Official packs, colors from basecamp/omarchy `themes/*/colors.toml`:

`catppuccin`, `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `kanagawa`, `last-horizon`, `lumon`, `lupine`, `matte-black`, `miasma`, `nord`, `osaka-jade`, `retro-82`, `ristretto`, `rose-pine`, `solitude`, `tokyo-night`, `vantablack`, `white`.

Light packs: `catppuccin-latte`, `flexoki-light`, `lupine`, `rose-pine`, `white`.

Drop extra theme directories in `~/.config/omarchy/themes/<name>/` (`colors.toml`, `hyprland.conf`, `ghostty`, `icons.theme`, `hyprlock.conf`, `mako.ini`, `waybar.css`, `walker.css`, `neovim.lua`, `btop.theme`, optional `light.mode`, optional `backgrounds/`). User themes win over the packaged packs. A theme that only ships `colors.toml` still gets lock / mako / Waybar / Walker / Neovim / btop snippets generated at apply time.

### Wallpaper

`omarchy-theme-set` points `~/.local/state/omarchy/background` at the first image for that pack and restarts swaybg. Official `backgrounds/` are fetched from [basecamp/omarchy](https://github.com/basecamp/omarchy) (MIT, David Heinemeier Hansson) at package-build time — we do not check the image binaries into this repo.

Add your own images (jpg / jpeg / png / gif / bmp / webp):

```text
~/.config/omarchy/themes/<name>/backgrounds/
~/.config/omarchy/backgrounds/<name>/
```

User images in `~/.config/omarchy/backgrounds/<name>/` are merged with the pack and sorted. `omarchy-theme-bg-next` walks that list. A pack or user theme with no images still retints every other surface; the switcher prints where to drop files.

`makoctl reload` and a Waybar `SIGUSR2` apply those surfaces without logging out. Hyprland reloads via `hyprctl`. Walker’s GTK service is restarted so it re-reads `walker.css`. Running Neovim instances are retinted in place (`nvim --server` on `omarchy-nvim-*.sock`, then `SIGUSR1`). Running btop reloads via `SIGUSR2` (same as Omarchy’s `omarchy-restart-btop`). **hyprlock has no reload IPC** — the next lock picks up the new colors; a lock already on screen keeps the old ones. The lock still uses a blurred screenshot, not the desktop wallpaper.

### Neovim and btop

Official packs that ship `neovim.lua` in [basecamp/omarchy](https://github.com/basecamp/omarchy) keep that LazyVim spec. Home Manager Neovim (apps pillar) loads it through `~/.config/nvim/lua/omarchy-theme.lua` and applies the named colorscheme when the plugin is on the runtimepath:

`tokyonight-night`, `catppuccin` / `catppuccin-latte`, `everforest`, `gruvbox`, `kanagawa`, `nordfox`, `rose-pine-dawn`, `bamboo` (osaka-jade).

Packs with no `neovim.lua`, or whose plugin is not in nixpkgs (`hackerman`, `lumon`, `matte-black`, `flexoki-light`, `retro-82`, `solitude`, plus `ethereal` / `last-horizon` / `lupine` / `miasma` / `ristretto` / `vantablack` / `white`), use highlight groups generated from that pack’s `colors.toml`. New Neovim windows pick up the theme immediately; already-open ones retint via the listen socket / `SIGUSR1` as above. If neither path reaches a live instance, the next `nvim` start is enough.

btop uses Omarchy’s `color_theme = "current"` convention: `omarchy-theme-set` points `~/.config/btop/themes/current.theme` at `~/.local/state/omarchy/current/btop.theme`. Four packs ship a hand-written `btop.theme` (`last-horizon`, `lumon`, `retro-82`, `solitude`); the rest are filled from Omarchy’s `btop.theme.tpl` and `colors.toml`. A running btop reloads on `SIGUSR2`; if none is running, the next launch reads `current`.

Chromium managed-policy theming is **not** wired. Omarchy writes `/etc/chromium/policies/managed/color.json` as root (`omarchy-theme-set-browser`). Official packs do not ship `chromium.theme` (it is generated from a template), and this flake does not add a sudoers helper. NixOS browser policies stay declarative (`programs.chromium.extraOpts`) for a later pass.

### Shell keybinds (Home Manager)

| Chord | Action |
| --- | --- |
| `Super+Return` | Ghostty |
| `Super+Space` | Walker |
| `Super+Ctrl+E` | Walker symbols (emoji) |
| `Super+Ctrl+L` | hyprlock |
| `Super+,` | Dismiss last mako notification |
| `Super+Shift+,` | Dismiss all mako notifications |
| `Super+B` | Chromium |
| `Super+Shift+F` | Nautilus |
| `Super+N` | Neovim in Ghostty |
| `Super+Shift+S` | grim + slurp + satty |
| `Super+V` | Walker clipboard provider |
| `Super+Ctrl+Space` | Wallpaper picker (Walker) |
| `Super+Ctrl+Shift+Space` | Theme picker (Walker) |

Walker is nixpkgs `walker` + `elephant`, not a private `omarchy-walker` binary. Home Manager writes Omarchy’s launcher stub:

- `~/.config/walker/config.toml` — prefixes, default providers, `omarchy-default` theme
- `~/.config/walker/themes/omarchy-default/{style.css,layout.xml}` — GTK CSS/layout from basecamp/omarchy (MIT)
- `~/.config/elephant/{desktopapplications,calc,symbols}.toml`
- `~/.config/elephant/menus/omarchy_themes.lua` and `omarchy_background_selector.lua` (theme pillar)

Prefixes match Omarchy: `/` provider list, `.` files, `:` symbols, `=` calc, `@` websearch, `$` clipboard, `;` theme picker. `omarchy-launch-walker` keeps Elephant up, uses `GSK_RENDERER=cairo`, and opens at 644×300. `omarchy-restart-walker` bounces the user units after a theme flip.

Not ported: Omarchy’s `omarchyunlocks` menu (feature-flag store), Walker logo/assets that are not in the public tree, and Omarchy 4’s native shell menu (this flake stays on Walker 2.x / Elephant, which is what nixpkgs has).

Idle (hypridle, seconds from idle — same numbers as Omarchy’s `shell.json`):

| Seconds | Action |
| --- | --- |
| 150 | DPMS off (Omarchy’s screensaver slot; we do not ship `omarchy-launch-screensaver`) |
| 300 | Lock with hyprlock |

`loginctl lock-session` / suspend also lock via hypridle’s `lock_cmd`. The NixOS module installs `security.pam.services.hyprlock` so unlock works. Standalone Home Manager users must set that PAM service on the host themselves.

## Storage (not optional for parity)

Omarchy’s installer encrypts the root disk and lays out Btrfs subvolumes so Snapper (and the bootloader) can roll back a bad update without taking `/home` with it. **That is the product.** An unencrypted ext4 (or xfs, or a single Btrfs subvolume with no Snapper) is a different machine.

Expected layout:

```text
ESP          vfat    /boot
cryptroot    LUKS2
  └─ Btrfs
       @            /          (Snapper config `root`)
       @home        /home      (Snapper config `home`)
       @.snapshots  /.snapshots   # or a `.snapshots` subvol under `@`
       @log         /var/log      # optional, matches Omarchy
       @pkg                     # optional; NixOS has no pacman cache
```

Create the LUKS container and subvolumes yourself (Calamares, disko, or by hand). Then declare them:

```nix
{
  programs.omarchy.enable = true;
  programs.omarchy.storage.luks.device = "/dev/disk/by-uuid/YOUR-LUKS-UUID";

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" ];
  };
  fileSystems."/home" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/YOUR-ESP-UUID";
    fsType = "vfat";
  };
}
```

`programs.omarchy.storage` will:

- Open that LUKS device as `cryptroot` (name overridable)
- Enable Snapper timeline + boot snapshots for `/` and `/home`
- Install `btrfs-progs`, `snapper`, and `cryptsetup`
- **Warn** if `luks.device` is unset or `/` / `/home` are not Btrfs

It will **not** run `cryptsetup luksFormat` or `mkfs.btrfs`. You still need a `.snapshots` subvolume on each Snapper target (Snapper’s own requirement). Snapper is pointed at the mount points `/` and `/home`, not at Btrfs subvolume names — those names (`@`, `@home`) belong in your `fileSystems` declarations. A later disko snippet will create that layout; unused `rootSubvolume` / `homeSubvolume` options are not exposed in the meantime.

NixOS rollbacks via `nixos-rebuild` / generation boot entries are complementary, not a substitute for filesystem snapshots. Omarchy’s story is both: generations for the store, Snapper for the live Btrfs subvolumes.

Limine + `limine-snapper-sync` (what Omarchy’s ISO uses) is **not** wired yet. systemd-boot + NixOS generations work today; boot-menu snapshot boots are a roadmap item.

## Parity roadmap

Ordered the way the pillars were stubbed.

1. **Shell**
   - [x] Hyprland via nixpkgs (`programs.hyprland`, UWSM)
   - [x] Ghostty via nixpkgs / Home Manager `programs.ghostty`
   - [x] Walker via nixpkgs `walker` + Elephant user unit
   - [x] Waybar (Omarchy’s actual status bar; Walker is the launcher)
   - [x] hyprlock + hypridle (lock on idle; PAM on NixOS)
   - [x] mako notifications
   - [x] Walker config, GTK CSS, and Elephant providers (clipboard, calc, files, symbols, menus)
   - [ ] hyprsunset / swayosd defaults
   - [ ] SDDM (or equivalent) session + unlock art
   - [ ] Omarchy screensaver (`omarchy-launch-screensaver`) and idle-inhibit toggle
   - [ ] Omarchy 4 native shell menu (Walker remains the launcher on this flake)

2. **Theme**
   - [x] `omarchy-theme-set` / `--next` / `--list`
   - [x] One keybind that retints GTK + Hyprland + Ghostty + icons + hyprlock + mako + Waybar + Walker + Neovim + btop
   - [x] Official Omarchy palettes (`catppuccin`, `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `kanagawa`, `last-horizon`, `lumon`, `lupine`, `matte-black`, `miasma`, `nord`, `osaka-jade`, `retro-82`, `ristretto`, `rose-pine`, `solitude`, `tokyo-night`, `vantablack`, `white`)
   - [x] Wallpaper: official `backgrounds/` fetched from basecamp/omarchy; apply-time switch via swaybg; user `backgrounds/` overlay
   - [x] Walker GTK CSS from `omarchy-theme-set` (`current/walker.css`)
   - [x] Theme preview picker (Elephant `menus:omarchythemes`) and wallpaper picker (`menus:omarchyBackgroundSelector`)
   - [x] Neovim retint from official `neovim.lua` (nixpkgs colorscheme plugins + `colors.toml` fallback)
   - [x] btop retint (`current.theme` symlink, official `btop.theme` where the pack ships one)
   - [ ] Chromium managed-policy retint (`/etc/chromium/policies/managed`; needs a privileged helper we do not ship)

3. **Apps**
   - [x] Chromium, Nautilus, Neovim, btop
   - [x] grim + slurp + satty; wl-clipboard + cliphist
   - [ ] Omarchy default MIME / XDG associations beyond browser + files
   - [ ] Optional extras (1Password, Obsidian, …) only when they exist in nixpkgs — never as invented blobs

4. **Storage**
   - [x] Document LUKS + `@` / `@home` as the required layout
   - [x] Snapper configs + boot snapshot (mount points `/` and `/home`)
   - [x] Optional `storage.luks.device` wiring
   - [ ] disko snippet that creates `@` / `@home` (layout names stay with disko, not unused module options)
   - [ ] Limine + snapper-sync boot-menu rollback
   - [ ] Initrd unlock theme (`unlock.png`)

## Outputs

| Output | Purpose |
| --- | --- |
| `nixosModules.default` / `nixosModules.omarchy` | `programs.omarchy` |
| `homeManagerModules.default` / `homeManagerModules.omarchy` | User Hyprland / Ghostty / theme stubs |
| `packages.<system>.omarchy-theme-tools` | Theme CLI + Walker launch/restart + wallpaper helper + screenshot helper + official palettes |
| `overlays.default` | Exposes `omarchy-theme-tools` |
| `templates.minimal` | `nix flake new -t github:zachspar/omarchy-nix#minimal` |
| `formatter` | `nixfmt-rfc-style` |

Linux systems: `x86_64-linux`, `aarch64-linux`.

## License

MIT. Omarchy itself is also MIT; this project is an independent NixOS port, not an official Omacom release.
