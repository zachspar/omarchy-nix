# omarchy-nix

A [Nix](https://nixos.org) flake that brings the [Omarchy](https://omarchy.org) desktop experience to NixOS.

Omarchy (DHH / [Omacom](https://omacom.io)) is an opinionated Arch desktop: Hyprland, Walker, Ghostty, one keybind that restyles the whole machine, a small curated app set, and **LUKS + Btrfs + Snapper** so you can roll back. This repository re-expresses that UX as importable NixOS and Home Manager modules under **`programs.omarchy`**.

This is a desktop experience, not a daemon. The option namespace is `programs.omarchy`, never `services.omarchy`.

The stack is a skeleton: the four pillars are stubbed, wired to nixpkgs where packages exist, and honest about gaps. Nothing here vendors unpublished Omarchy binaries.

## The four pillars

All four are **on by default** once you set `programs.omarchy.enable = true`. Each can be flipped independently.

| Pillar | What “done” looks like | This stub |
| --- | --- | --- |
| **shell** | Hyprland + Walker + Ghostty feels like Omarchy at first login | Enables `programs.hyprland` (UWSM), Ghostty, Walker, Waybar, Elephant (Walker 2.x backend, including menus/clipboard/calc/files/symbols), **hyprlock + hypridle** (lock on idle), **mako** (notifications), **hyprsunset** (night light) + **swayosd** (volume/brightness/caps OSD), and **SDDM + Plymouth** (greeter / unlock art). Home Manager writes the Hyprland/Ghostty/lock/OSD baseline, Walker config + GTK CSS, and keybinds. |
| **theme** | One command / keybind flips GTK + Hyprland + terminal + icons + lock + notifications + bar + launcher + Neovim + btop + wallpaper together; Chromium chrome follows `theme.name` | `omarchy-theme-set <name>`, `omarchy-theme-next`, Walker theme picker on `Super+Ctrl+Shift+Space`. All official Omarchy packs. Wallpaper via swaybg. Chromium chrome is generation-bound (managed policy). |
| **apps** | Browser, file manager, Neovim, screenshot + clipboard helpers | Chromium, Nautilus, Neovim, btop, grim/slurp/satty, wl-clipboard, cliphist. |
| **storage** | LUKS2 + Btrfs `@` / `@home` + Snapper rollback, Limine snapshot menu | Documents and wires Snapper; optionally opens a LUKS device you already created; opt-in disko formats a disk; **opt-in Limine** puts Snapper `@` snapshots on the boot menu. **Does not reformat disks unless `storage.disko.enable`.** Does not treat an unencrypted ext4 root as equivalent. |

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

`nixosModules.default` and `nixosModules.omarchy` are the same module. Home Manager: `homeManagerModules.default` / `homeManagerModules.omarchy`. `nixosModules.disko` is **not** in the default import — it is the formatting path (see [Storage](#storage-not-optional-for-parity)).

A complete host sketch lives in [`examples/minimal`](examples/minimal). A new-install sketch that **wipes a disk** lives in [`examples/disko`](examples/disko).

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
  # programs.omarchy.shell.greeter.autoLogin.enable = true;
  # programs.omarchy.shell.greeter.autoLogin.user = "youruser";
  # programs.omarchy.shell.greeter.compositor = "weston";
  # programs.omarchy.shell.greeter.logo = ./unlock.png;
  # programs.omarchy.shell.greeter.plymouth.enable = false;
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

Each flip updates GTK (`gsettings` color-scheme + theme), icon theme, Hyprland border colors, the Ghostty `omarchy` theme file, hyprlock color tokens, mako notification colors, Waybar CSS (`@foreground` / `@background`), Walker GTK CSS (`@selected-text` / `@text` / `@base` / `@border`), swayosd CSS (`@background-color` / `@border-color` / `@label` / `@image` / `@progress`), Neovim (official `neovim.lua` colorscheme, or palette highlight groups), btop (`themes/current.theme`), and the desktop wallpaper (swaybg). Chromium chrome follows `programs.omarchy.theme.name` via a managed policy and does **not** live-retint — see [Chromium chrome](#chromium-chrome). hyprsunset is a temperature toggle, not a palette.

Official packs, colors from basecamp/omarchy `themes/*/colors.toml`:

`catppuccin`, `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `kanagawa`, `last-horizon`, `lumon`, `lupine`, `matte-black`, `miasma`, `nord`, `osaka-jade`, `retro-82`, `ristretto`, `rose-pine`, `solitude`, `tokyo-night`, `vantablack`, `white`.

Light packs: `catppuccin-latte`, `flexoki-light`, `lupine`, `rose-pine`, `white`.

Drop extra theme directories in `~/.config/omarchy/themes/<name>/` (`colors.toml`, `hyprland.conf`, `ghostty`, `icons.theme`, `hyprlock.conf`, `mako.ini`, `waybar.css`, `walker.css`, `swayosd.css`, `neovim.lua`, `btop.theme`, `chromium.theme`, optional `light.mode`, optional `backgrounds/`). User themes win over the packaged packs. A theme that only ships `colors.toml` still gets lock / mako / Waybar / Walker / swayosd / Neovim / btop / `chromium.theme` snippets generated at apply time. User `chromium.theme` does not rewrite `/etc` — Chromium chrome stays on the generation-declared `theme.name`.

### Wallpaper

`omarchy-theme-set` points `~/.local/state/omarchy/background` at the first image for that pack and restarts swaybg. Official `backgrounds/` are fetched from [basecamp/omarchy](https://github.com/basecamp/omarchy) (MIT, David Heinemeier Hansson) at package-build time — we do not check the image binaries into this repo.

Add your own images (jpg / jpeg / png / gif / bmp / webp):

```text
~/.config/omarchy/themes/<name>/backgrounds/
~/.config/omarchy/backgrounds/<name>/
```

User images in `~/.config/omarchy/backgrounds/<name>/` are merged with the pack and sorted. `omarchy-theme-bg-next` walks that list. A pack or user theme with no images still retints every other surface; the switcher prints where to drop files.

`makoctl reload` and a Waybar `SIGUSR2` apply those surfaces without logging out. Hyprland reloads via `hyprctl`. Walker’s GTK service is restarted so it re-reads `walker.css`. `omarchy-restart-swayosd` bounces the user unit so `current/swayosd.css` is re-read. Running Neovim instances are retinted in place (`nvim --server` on `omarchy-nvim-*.sock`, then `SIGUSR1`). Running btop reloads via `SIGUSR2` (same as Omarchy’s `omarchy-restart-btop`). **hyprlock has no reload IPC** — the next lock picks up the new colors; a lock already on screen keeps the old ones. The lock still uses a blurred screenshot, not the desktop wallpaper.

### Neovim and btop

Official packs that ship `neovim.lua` in [basecamp/omarchy](https://github.com/basecamp/omarchy) keep that LazyVim spec. Home Manager Neovim (apps pillar) loads it through `~/.config/nvim/lua/omarchy-theme.lua` and applies the named colorscheme when the plugin is on the runtimepath:

`tokyonight-night`, `catppuccin` / `catppuccin-latte`, `everforest`, `gruvbox`, `kanagawa`, `nordfox`, `rose-pine-dawn`, `bamboo` (osaka-jade).

Packs with no `neovim.lua`, or whose plugin is not in nixpkgs (`hackerman`, `lumon`, `matte-black`, `flexoki-light`, `retro-82`, `solitude`, plus `ethereal` / `last-horizon` / `lupine` / `miasma` / `ristretto` / `vantablack` / `white`), use highlight groups generated from that pack’s `colors.toml`. New Neovim windows pick up the theme immediately; already-open ones retint via the listen socket / `SIGUSR1` as above. If neither path reaches a live instance, the next `nvim` start is enough.

btop uses Omarchy’s `color_theme = "current"` convention: `omarchy-theme-set` points `~/.config/btop/themes/current.theme` at `~/.local/state/omarchy/current/btop.theme`. Four packs ship a hand-written `btop.theme` (`last-horizon`, `lumon`, `retro-82`, `solitude`); the rest are filled from Omarchy’s `btop.theme.tpl` and `colors.toml`. A running btop reloads on `SIGUSR2`; if none is running, the next launch reads `current`.

### Chromium chrome

Omarchy’s `omarchy-theme-set-browser` writes `/etc/chromium/policies/managed/color.json` as root, then asks a running browser to `chromium --refresh-platform-policy --no-startup-window`. Official packs do not ship `chromium.theme`; it is generated from `default/themed/chromium.theme.tpl` (`{{ background_rgb }}`) using that pack’s `colors.toml` `background`. The JSON is:

```json
{"BrowserThemeColor": "#1a1b26", "BrowserColorScheme": "device"}
```

(`#1a1b26` is tokyo-night’s background. Missing `chromium.theme` falls back to Omarchy’s `#1c2027`.)

NixOS owns `/etc`. This flake does **not** world-write the managed-policy directory and does **not** ship a sudoers helper. With the theme and apps pillars on, the NixOS module sets `programs.chromium.enable` and `programs.chromium.extraOpts` from `programs.omarchy.theme.name`. NixOS writes that JSON to `/etc/chromium/policies/managed/extra.json` (and the Chrome / Brave siblings). Chromium reads every JSON in the managed dir; extra.json is the NixOS name for Omarchy’s color.json.

```nix
{
  programs.omarchy.enable = true;
  programs.omarchy.theme.name = "tokyo-night";
  # Rebuild. Chromium chrome is now #1a1b26.
}
```

`omarchy-theme-set` still writes `~/.local/state/omarchy/current/chromium.theme` (template fill, or a user-supplied file) and calls `--refresh-platform-policy` if Chromium is running. That refresh re-reads `/etc`. It cannot change the chrome color until you rebuild with a new `theme.name`.

After `nixos-rebuild switch`, restart Chromium or run:

```bash
chromium --refresh-platform-policy --no-startup-window
```

#### Honest limits

- Live theme cycle / Walker picker retints GTK, Hyprland, Ghostty, lock, mako, Waybar, Walker, swayosd, Neovim, btop, and wallpaper. Chromium chrome stays on the last rebuilt `theme.name`. hyprsunset does not follow the palette.
- `BrowserThemeColor` is the Linux-supported key (toolbar / frame seed from the pack background). `BrowserColorScheme = "device"` is copied from Omarchy’s JSON; on Linux it may show as unknown in `chrome://policy` and is ignored per-key. We do not invent a Linux `BrowserColorScheme` integer.
- A custom `theme.name` that is not an official pack uses Omarchy’s fallback `#1c2027` until you override `programs.chromium.extraOpts.BrowserThemeColor` yourself.
- Standalone Home Manager cannot install managed policies (no `/etc`). The user module still seeds `chromium.theme` so the file exists; the browser will not read it.
- There is no user-level Chromium managed-policy directory that stock Chromium honors. Writing `~/.config/chromium/policies/` does not theme the chrome. Preferences-file hacking is not Omarchy’s path and is not wired here.

### Shell keybinds (Home Manager)

| Chord | Action |
| --- | --- |
| `Super+Return` | Ghostty |
| `Super+Space` | Walker |
| `Super+Ctrl+E` | Walker symbols (emoji) |
| `Super+Ctrl+L` | hyprlock |
| `Super+Ctrl+N` | Toggle night light (hyprsunset 4000K / 6000K) |
| `XF86Audio*` / `XF86MonBrightness*` | Volume / brightness via swayosd (works on the lock screen) |
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

hyprsunset and swayosd are systemd user units, same as hypridle. They are **not** Hyprland `exec-once` lines, so they do not fight the lock/idle stack after suspend. Media binds use Hyprland `bindel` / `bindl` and still fire on hyprlock.

### Night light and OSD

Omarchy’s night light is a toggle, not a schedule. `~/.config/hypr/hyprsunset.conf` ships an identity profile at 07:00 so hyprsunset does not tint the display until you ask. `Super+Ctrl+N` / `omarchy-toggle-nightlight` warms to 4000K and back to 6000K — that pair is what Omarchy’s script uses (the manual says 6500K). Clock-based night light is a user override of `services.hyprsunset.settings`; this flake does not invent a sunrise/sunset scheduler.

Volume, brightness, and media keys go through `omarchy-swayosd-client` (swayosd on the focused monitor). Caps / Num / Scroll Lock feedback is the NixOS `swayosd-libinput-backend` system unit — it needs `/dev/input`, so standalone Home Manager cannot own it. Style tokens live in `current/swayosd.css` and follow `omarchy-theme-set`.

Quattro’s native shell OSD is **not** what we ship. Same reason as Walker 2.x: nixpkgs has swayosd, not Omarchy’s in-process shell.

### Greeter and unlock art

Omarchy’s first-login path is two screens, not one:

| When | What Omarchy uses | This flake |
| --- | --- | --- |
| After the kernel, before `/` is mounted | Plymouth + `unlock.png` (LUKS passphrase) | `boot.plymouth` theme `omarchy` |
| After the disk is open, and after logout | SDDM theme `omarchy` (logo, lock, entry) | `services.displayManager.sddm` |

Both are on by default with the shell pillar (`programs.omarchy.shell.greeter`). Autologin is **off**. The session SDDM starts is `hyprland-uwsm` when `shell.withUWSM` is on (same UWSM wrap Omarchy’s `omarchy.desktop` uses).

The greeter theme is fetched at package-build time from [basecamp/omarchy](https://github.com/basecamp/omarchy) (MIT, David Heinemeier Hansson): `default/sddm`, `default/plymouth`, and each pack’s `unlock.png`. We do not check the PNGs into this repo. Colors follow the **declared** `programs.omarchy.theme.name` (or tokyo-night if the theme pillar is off). `omarchy-theme-set` cannot retint SDDM or Plymouth — those files live in the Nix store, and Plymouth is copied into the initrd.

Drop your own unlock art:

```nix
{
  programs.omarchy.shell.greeter.logo = ./unlock.png;
}
```

If a pack has no `unlock.png` and you do not set `logo`, the package uses Omarchy’s default `logo.png`, then a generated wordmark stub so the screen still looks intentional.

The greeter compositor defaults to Hyprland with Omarchy’s tiny `/usr/share/sddm/hyprland.conf`. nixpkgs first-class supports weston (and kwin) as the SDDM Wayland compositor; Hyprland is best-effort. If the greeter is black or crashes:

```nix
{
  programs.omarchy.shell.greeter.compositor = "weston";
}
```

#### LUKS unlock theming (honest limits)

`unlock.png` is a **Plymouth** asset, not an SDDM one. NixOS will show that themed passphrase dialog only when Plymouth is in the initrd and the initrd actually hands the prompt to it.

- Current nixos-unstable already enables `boot.initrd.systemd.enable`, which is the systemd-ask-password-plymouth path. If you turn systemd initrd off, traditional initrd may still print the cryptsetup text prompt before Plymouth starts; the module warns when `storage.luks.device` is set in that case.
- A theme or logo change needs `nixos-rebuild` (initrd rebuild). There is no `omarchy-plymouth-set` equivalent that mutates `/usr/share` at runtime.
- TPM / FIDO2 unlock (`systemd-cryptenroll`) skips the visual prompt entirely.
- Early KMS is required for a real splash; a black or late splash is usually a GPU/modeset problem, not a missing PNG.
- Turning `programs.omarchy.shell.greeter.plymouth.enable` off leaves you with the stock cryptsetup prompt. That is not an Omarchy-equivalent unlock screen.

SDDM never sees the disk passphrase. Do not expect the greeter to replace FDE unlock.

## Storage (not optional for parity)

Omarchy’s installer encrypts the root disk and lays out Btrfs subvolumes so Snapper (and the bootloader) can roll back a bad update without taking `/home` with it. **That is the product.** An unencrypted ext4 (or xfs, or a single Btrfs subvolume with no Snapper) is a different machine.

Verified against the Omarchy ISO configurator (`omacom-io/omarchy-iso`, encrypted path): LUKS2, Btrfs label `OMARCHY`, subvolumes `@` `@home` `@log` `@pkg`, mount `-o noatime,compress=zstd`, 2GiB FAT32 ESP labeled `OMARCHY_EFI`. The ISO does not create `.snapshots` at format time — `snapper create-config` does that later. NixOS Snapper does not run `create-config`, so the disko snippet adds nested `.snapshots` under `@` and `@home`.

Expected layout:

```text
ESP          vfat    /boot     (2G, OMARCHY_EFI)
cryptroot    LUKS2
  └─ Btrfs   label OMARCHY
       @                 /                    (Snapper config `root`)
       @/.snapshots      /.snapshots
       @home             /home                (Snapper config `home`)
       @home/.snapshots  /home/.snapshots
       @log              /var/log
       @pkg              /var/cache/pacman/pkg   # installer parity; NixOS has no pacman
```

### Default: warn, do not format

Create the LUKS container and subvolumes yourself (Calamares, disko by hand, or this flake’s opt-in snippet). Then declare them:

```nix
{
  programs.omarchy.enable = true;
  programs.omarchy.storage.luks.device = "/dev/disk/by-uuid/YOUR-LUKS-UUID";

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" ];
  };
  fileSystems."/home" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/YOUR-ESP-UUID";
    fsType = "vfat";
  };
}
```

`programs.omarchy.storage` will:

- Open that LUKS device as `cryptroot` (name overridable; the ISO uses `omarchy_root`)
- Enable Snapper timeline + boot snapshots for `/` and `/home`
- Install `btrfs-progs`, `snapper`, and `cryptsetup`
- **Warn** if `luks.device` is unset or `/` / `/home` are not Btrfs

It will **not** run `cryptsetup luksFormat` or `mkfs.btrfs`. You still need a `.snapshots` subvolume on each Snapper target (Snapper’s own requirement). Snapper is pointed at the mount points `/` and `/home`, not at Btrfs subvolume names — those names (`@`, `@home`) belong in your `fileSystems` declarations or in the disko snippet below.

NixOS generations (systemd-boot or Limine’s NixOS menu) are not Snapper rollback. For boot-menu snapshot restore, enable `storage.limine` below.

### Opt-in: disko snippet (wipes the disk)

`programs.omarchy.storage.disko.enable` is **off by default**. Turning it on writes `disko.devices` for the layout above. The next `disko` / `nixos-install` **destroys every partition** on `storage.disko.device`.

1. Import `omarchy-nix.nixosModules.disko` (re-exports [nix-community/disko](https://github.com/nix-community/disko); not part of `nixosModules.default`).
2. Set the disk you are willing to lose.
3. Do **not** also set `storage.luks.device` or a `hardware-configuration.nix` that restates `fileSystems` / LUKS — disko owns those.

```nix
{
  programs.omarchy.enable = true;

  programs.omarchy.storage.disko.enable = true;
  programs.omarchy.storage.disko.device = "/dev/nvme0n1"; # WILL BE WIPED
  # programs.omarchy.storage.disko.efiSize = "2G";         # ISO default
  # programs.omarchy.storage.luks.name = "cryptroot";
  # programs.omarchy.storage.disko.passwordFile = "/tmp/luks-password"; # else prompt
}
```

From a NixOS installer (Determinate Nix, flakes on):

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#your-host
sudo nixos-install --flake .#your-host
```

A full host sketch is [`examples/disko`](examples/disko) (`nix flake new -t github:zachspar/omarchy-nix#disko`). The layout function is also `omarchy-nix.lib.mkOmarchyDisko { device = "/dev/vda"; }` if you want the attrset without the module.

NixOS rollbacks via `nixos-rebuild` / generation boot entries are complementary, not a substitute for filesystem snapshots. Omarchy’s story is both: generations for the store, Snapper for the live Btrfs subvolumes.

### Opt-in: Limine + snapshot boot-menu rollback

`programs.omarchy.storage.limine.enable` is **off by default**. Turning it on switches the bootloader to nixpkgs `boot.loader.limine` (systemd-boot and GRUB are forced off) and installs a NixOS equivalent of Omarchy’s Limine + snapper-sync path.

Two different menus, two different rollbacks:

| Limine menu | What it is | What it restores |
| --- | --- | --- |
| **NixOS** (generations) | `nixos-rebuild` closures. Kernel + initrd + `init=` for that generation. | The Nix store profile / activation. Live Btrfs `@` is unchanged. |
| **Snapshots** | Snapper snapshots of `@`, taken on boot and on a timeline (and via `omarchy-snapshot create`). | The live root subvolume. `/home` (`@home`) is **not** rolled back — same as Omarchy. |

How to roll back a bad update the Omarchy way:

1. At the Limine menu, open **Snapshots** (not a NixOS generation).
2. Pick a snapshot by date. That boot mounts `@/.snapshots/<id>/snapshot` as `/` (`rootflags=` on the cmdline). systemd initrd is required so those flags win.
3. A notification offers restore. Or run `omarchy-snapshot restore`.
4. That **replaces `@`** with the snapshot (`replace` method). Previous `@` is kept as `@-pre-restore-<timestamp>`. Reboot.

```nix
{
  programs.omarchy.enable = true;
  programs.omarchy.storage.disko.enable = true;
  programs.omarchy.storage.disko.device = "/dev/nvme0n1";

  # Replaces systemd-boot. ESP stays at /boot (disko default).
  programs.omarchy.storage.limine.enable = true;
  # programs.omarchy.storage.limine.maxSnapshotEntries = 5;
}
```

Drop `boot.loader.systemd-boot.enable` from the host config — this option force-disables it. After the first rebuild, reboot through firmware if Limine is not already the first EFI entry.

`omarchy-limine-snapper sync` runs after every bootloader install and whenever Snapper changes `/.snapshots`. Kernel/initrd copies live under `/boot/omarchy-snapshots/<id>/`, **outside** `/boot/limine/`, so nixpkgs `limine-install.py` cannot delete them when it rewrites generation entries.

`/etc/default/limine` is written for the same knobs Omarchy ships (`ESP_PATH`, `ROOT_SNAPSHOTS_PATH=/@/.snapshots`, `MAX_SNAPSHOT_ENTRIES=5`). The Limine menu chrome follows `programs.omarchy.theme.name` at rebuild time (same constraint as Plymouth).

#### Honest limits

- **Not upstream `limine-snapper-sync`.** That tool is a GraalVM native-image and is **not in nixpkgs**. This flake ships `omarchy-limine-snapper` instead of vendoring a binary or pinning GraalVM 25. If nixpkgs ever packages it, the `/etc/default/limine` keys are already the ones it reads.
- **No `btrfs-overlayfs`.** Omarchy’s mkinitcpio hook overlays `/` on every snapshot boot; `limine-snapper-sync --restore` then exits because `/` is not Btrfs. We leave snapshots as Btrfs and clear `ro` so NixOS activation can write (`storage.limine.writableSnapshots`, default on). A snapshot you boot is no longer a 1:1 frozen copy — restore immediately.
- **systemd initrd.** Snapshot entries pass `rootflags=subvol=@/.snapshots/<id>/snapshot`. Traditional NixOS stage-1 may ignore that and mount `@` from the generation’s baked-in filesystems. nixos-unstable already enables systemd initrd; keep it.
- **`/nix` must live on `@`.** A separate `@nix` subvolume is not the Omarchy layout; booting an old snapshot would see today’s store.
- **UKI / Direct Boot** (Omarchy’s EFI skip-the-menu path) is not ported. Timeout stays the NixOS Limine default so you can actually pick a snapshot.
- **`omarchy-snapshot restore` is root `@` only.** Home snapshots exist for Snapper; they are not a Limine menu and are not applied by restore.

Unlock *art* for the LUKS prompt is Plymouth (`programs.omarchy.shell.greeter.plymouth`), not this storage module. See [Greeter and unlock art](#greeter-and-unlock-art).

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
   - [x] hyprsunset / swayosd defaults (identity night light + Super+Ctrl+N; volume/brightness OSD; Caps via NixOS libinput backend)
   - [x] SDDM greeter + Hyprland/UWSM session (`programs.omarchy.shell.greeter`; autologin off)
   - [x] Plymouth unlock art (`unlock.png` from official packs; initrd rebuild; systemd initrd recommended)
   - [ ] Live greeter / Plymouth retint from `omarchy-theme-set` (store + initrd are immutable)
   - [ ] Omarchy screensaver (`omarchy-launch-screensaver`) and idle-inhibit toggle
   - [ ] Omarchy 4 native shell menu (Walker remains the launcher on this flake)

2. **Theme**
   - [x] `omarchy-theme-set` / `--next` / `--list`
   - [x] One keybind that retints GTK + Hyprland + Ghostty + icons + hyprlock + mako + Waybar + Walker + swayosd + Neovim + btop
   - [x] Official Omarchy palettes (`catppuccin`, `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `kanagawa`, `last-horizon`, `lumon`, `lupine`, `matte-black`, `miasma`, `nord`, `osaka-jade`, `retro-82`, `ristretto`, `rose-pine`, `solitude`, `tokyo-night`, `vantablack`, `white`)
   - [x] Wallpaper: official `backgrounds/` fetched from basecamp/omarchy; apply-time switch via swaybg; user `backgrounds/` overlay
   - [x] Walker GTK CSS from `omarchy-theme-set` (`current/walker.css`)
   - [x] swayosd CSS from `omarchy-theme-set` (`current/swayosd.css`; server restart)
   - [x] Theme preview picker (Elephant `menus:omarchythemes`) and wallpaper picker (`menus:omarchyBackgroundSelector`)
   - [x] Neovim retint from official `neovim.lua` (nixpkgs colorscheme plugins + `colors.toml` fallback)
   - [x] btop retint (`current.theme` symlink, official `btop.theme` where the pack ships one)
   - [x] Chromium managed-policy theming (`programs.chromium.extraOpts` from `theme.name`; rebuild to retint; no sudoers helper)

3. **Apps**
   - [x] Chromium, Nautilus, Neovim, btop
   - [x] grim + slurp + satty; wl-clipboard + cliphist
   - [ ] Omarchy default MIME / XDG associations beyond browser + files
   - [ ] Optional extras (1Password, Obsidian, …) only when they exist in nixpkgs — never as invented blobs

4. **Storage**
   - [x] Document LUKS + `@` / `@home` as the required layout
   - [x] Snapper configs + boot snapshot (mount points `/` and `/home`)
   - [x] Optional `storage.luks.device` wiring
   - [x] Opt-in `storage.disko` snippet (`@` / `@home` / `@log` / `@pkg` + Snapper `.snapshots`; wipes the disk)
   - [x] Opt-in Limine + snapshot boot-menu rollback (`storage.limine`; NixOS equivalent of snapper-sync — see limits above)
   - [ ] Swap `omarchy-limine-snapper` for nixpkgs `limine-snapper-sync` if/when it is packaged
   - [ ] Omarchy Direct Boot (EFI entry that skips the Limine menu)
   - [x] Initrd unlock theme (`unlock.png` via Plymouth; see greeter limits above)

## Outputs

| Output | Purpose |
| --- | --- |
| `nixosModules.default` / `nixosModules.omarchy` | `programs.omarchy` (does **not** format disks) |
| `nixosModules.disko` | nix-community/disko — required only for `storage.disko.enable` |
| `lib.mkOmarchyDisko` | Pure `disko.devices` attrset for the Omarchy layout |
| `homeManagerModules.default` / `homeManagerModules.omarchy` | User Hyprland / Ghostty / theme stubs |
| `packages.<system>.omarchy-theme-tools` | Theme CLI + Walker launch/restart + wallpaper helper + screenshot helper + nightlight/OSD helpers + official palettes |
| `packages.<system>.omarchy-greeter` | SDDM theme + Plymouth unlock theme (official `unlock.png`, recolored chrome) |
| `packages.<system>.omarchy-limine-snapper` | `omarchy-snapshot` / `omarchy-limine-snapper` — Limine `/Snapshots` sync and `@` restore |
| `overlays.default` | Exposes `omarchy-theme-tools`, `omarchy-greeter`, and `omarchy-limine-snapper` |
| `templates.minimal` | `nix flake new -t github:zachspar/omarchy-nix#minimal` |
| `templates.disko` | Same, with `storage.disko` on — **wipes the named disk** |
| `formatter` | `nixfmt-rfc-style` |

Linux systems: `x86_64-linux`, `aarch64-linux`.

## License

MIT. Omarchy itself is also MIT; this project is an independent NixOS port, not an official Omacom release.
