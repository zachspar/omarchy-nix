# omarchy-nix

A [Nix](https://nixos.org) flake that brings the [Omarchy](https://omarchy.org) desktop experience to NixOS.

Omarchy (DHH / [Omacom](https://omacom.io)) is an opinionated Arch desktop: Hyprland, Walker, Ghostty, one keybind that restyles the whole machine, a small curated app set, and **LUKS + Btrfs + Snapper** so you can roll back. This repository re-expresses that UX as importable NixOS and Home Manager modules under **`programs.omarchy`**.

This is a desktop experience, not a daemon. The option namespace is `programs.omarchy`, never `services.omarchy`.

The stack is a skeleton: the four pillars are stubbed, wired to nixpkgs where packages exist, and honest about gaps. Nothing here vendors unpublished Omarchy binaries.

## The four pillars

All four are **on by default** once you set `programs.omarchy.enable = true`. Each can be flipped independently.

| Pillar | What “done” looks like | This stub |
| --- | --- | --- |
| **shell** | Hyprland + Walker + Ghostty feels like Omarchy at first login | Enables `programs.hyprland` (UWSM), Ghostty, Walker, Waybar, Elephant (Walker 2.x backend), **hyprlock + hypridle** (lock on idle), and **mako** (notifications). Home Manager writes the Hyprland/Ghostty/lock baseline and keybinds. |
| **theme** | One command / keybind flips GTK + Hyprland + terminal + icons together | `omarchy-theme-set <name>`, `omarchy-theme-next`, `Super+Ctrl+Shift+Space`. Built-in palettes: `tokyo-night`, `catppuccin-latte`. |
| **apps** | Browser, file manager, Neovim, screenshot + clipboard helpers | Chromium, Nautilus, Neovim, grim/slurp/satty, wl-clipboard, cliphist. |
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
| Cycle themes | `omarchy-theme-next` or `Super+Ctrl+Shift+Space` |
| Set a theme | `omarchy-theme-set tokyo-night` |
| List themes | `omarchy-theme-list` |

Each flip updates GTK (`gsettings` color-scheme + theme), icon theme, Hyprland border colors, and the Ghostty `omarchy` theme file.

Drop extra theme directories in `~/.config/omarchy/themes/<name>/` (`colors.toml`, `hyprland.conf`, `ghostty`, `icons.theme`, optional `light.mode`). User themes win over the packaged stubs.

### Shell keybinds (Home Manager)

| Chord | Action |
| --- | --- |
| `Super+Return` | Ghostty |
| `Super+Space` | Walker |
| `Super+Ctrl+L` | hyprlock |
| `Super+,` | Dismiss last mako notification |
| `Super+Shift+,` | Dismiss all mako notifications |
| `Super+B` | Chromium |
| `Super+Shift+F` | Nautilus |
| `Super+N` | Neovim in Ghostty |
| `Super+Shift+S` | grim + slurp + satty |
| `Super+V` | Walker clipboard provider |
| `Super+Ctrl+Shift+Space` | Next theme |

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
   - [x] Walker via nixpkgs `walker` + `services.elephant`
   - [x] Waybar (Omarchy’s actual status bar; Walker is the launcher)
   - [x] hyprlock + hypridle (lock on idle; PAM on NixOS)
   - [x] mako notifications
   - [ ] Omarchy `omarchy-walker` branding, providers, and Walker GTK CSS
   - [ ] hyprsunset / swayosd defaults
   - [ ] SDDM (or equivalent) session + unlock art
   - [ ] Omarchy screensaver (`omarchy-launch-screensaver`) and idle-inhibit toggle

2. **Theme**
   - [x] `omarchy-theme-set` / `--next` / `--list`
   - [x] One keybind that retints GTK + Hyprland + Ghostty + icons
   - [x] Two stub palettes (`tokyo-night`, `catppuccin-latte`)
   - [ ] Remaining official Omarchy palettes as first-class packs
   - [ ] Waybar, hyprlock, Neovim, btop, Chromium, Walker, wallpaper retint
   - [ ] Theme preview picker (Walker/Elephant `omarchythemes` provider)

3. **Apps**
   - [x] Chromium, Nautilus, Neovim
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
| `packages.<system>.omarchy-theme-tools` | Theme CLI + screenshot helper + stub palettes |
| `overlays.default` | Exposes `omarchy-theme-tools` |
| `templates.minimal` | `nix flake new -t github:zachspar/omarchy-nix#minimal` |
| `formatter` | `nixfmt-rfc-style` |

Linux systems: `x86_64-linux`, `aarch64-linux`.

## License

MIT. Omarchy itself is also MIT; this project is an independent NixOS port, not an official Omacom release.
