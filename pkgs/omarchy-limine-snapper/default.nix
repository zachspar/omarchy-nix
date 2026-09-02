{
  lib,
  writeShellApplication,
  symlinkJoin,
  coreutils,
  util-linux,
  gnused,
  gawk,
  gnugrep,
  btrfs-progs,
  snapper,
  libnotify,
}:
let
  snapperTool = writeShellApplication {
    name = "omarchy-limine-snapper";
    runtimeInputs = [
      coreutils
      util-linux
      gnused
      gawk
      gnugrep
      btrfs-progs
      snapper
      libnotify
    ];
    text = builtins.readFile ./omarchy-limine-snapper.sh;
  };

  snapshotCli = writeShellApplication {
    name = "omarchy-snapshot";
    runtimeInputs = [
      snapperTool
      snapper
    ];
    text = ''
      cmd="''${1:-}"
      if [[ -z "$cmd" ]]; then
        echo "Usage: omarchy-snapshot <create|restore>" >&2
        exit 1
      fi
      if ! command -v snapper >/dev/null; then
        exit 127
      fi
      case "$cmd" in
        create)
          shift
          exec omarchy-limine-snapper create "$@"
          ;;
        restore)
          shift
          exec omarchy-limine-snapper restore "$@"
          ;;
        *)
          echo "Usage: omarchy-snapshot <create|restore>" >&2
          exit 1
          ;;
      esac
    '';
  };
in
symlinkJoin {
  name = "omarchy-limine-snapper";
  pname = "omarchy-limine-snapper";
  version = "0.1.0";
  paths = [
    snapperTool
    snapshotCli
  ];
  meta = {
    description = "NixOS equivalent of limine-snapper-sync: Limine /Snapshots menu and Btrfs @ rollback";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "omarchy-limine-snapper";
  };
}
