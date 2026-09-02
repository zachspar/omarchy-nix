# Omarchy-on-NixOS equivalent of limine-snapper-sync.
# Upstream is a GraalVM native-image and is not in nixpkgs. This script
# composes with NixOS's Limine generator: generations stay in
# /boot/limine/limine.conf; snapshot kernels live outside that tree so
# limine-install.py does not delete them.

set -euo pipefail

readonly SCRIPT_NAME="omarchy-limine-snapper"
readonly DEFAULT_CONFIG="/etc/default/limine"
readonly LOCKFILE="/run/lock/omarchy-limine-snapper.lock"
readonly TOPLEVEL_MOUNT="/run/omarchy-btrfs"

ESP_PATH="/boot"
LIMINE_CONF=""
ROOT_SUBVOLUME="@"
ROOT_SNAPSHOTS_PATH="/@/.snapshots"
SNAPPER_CONFIG="root"
MAX_SNAPSHOT_ENTRIES=5
SNAPSHOT_WRITABLE="yes"
SNAPSHOT_DIR_NAME="omarchy-snapshots"

load_config() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local line var val
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      var="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      val="${val%%#*}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%"${val##*[![:space:]]}"}"
      val="${val#"${val%%[![:space:]]*}"}"
      case "$var" in
        ESP_PATH) ESP_PATH="$val" ;;
        ROOT_SUBVOLUME_PATH) ROOT_SUBVOLUME="${val#/}" ;;
        ROOT_SNAPSHOTS_PATH) ROOT_SNAPSHOTS_PATH="$val" ;;
        SNAPPER_CONFIG_NAME) SNAPPER_CONFIG="$val" ;;
        MAX_SNAPSHOT_ENTRIES) MAX_SNAPSHOT_ENTRIES="$val" ;;
        SNAPSHOT_WRITABLE) SNAPSHOT_WRITABLE="$val" ;;
        OMARCHY_SNAPSHOT_DIR) SNAPSHOT_DIR_NAME="$val" ;;
      esac
    fi
  done <"$file"
}

resolve_limine_conf() {
  if [[ -n "${LIMINE_CONF}" && -f "${LIMINE_CONF}" ]]; then
    return 0
  fi
  if [[ -f "${ESP_PATH}/limine/limine.conf" ]]; then
    LIMINE_CONF="${ESP_PATH}/limine/limine.conf"
  elif [[ -f "${ESP_PATH}/limine.conf" ]]; then
    LIMINE_CONF="${ESP_PATH}/limine.conf"
  else
    LIMINE_CONF="${ESP_PATH}/limine/limine.conf"
  fi
}

load_config "${DEFAULT_CONFIG}"
resolve_limine_conf

usage() {
  cat <<'EOF'
usage: omarchy-limine-snapper <sync|restore|create|list|notify|status> [args]

  sync              Copy current Limine kernel/initrd into ESP snapshot dirs
                    and rewrite the /Snapshots menu in limine.conf
  restore [--yes]   Replace Btrfs @ with the snapshot this boot mounted
  create [desc]     snapper create on every config, then sync
  list              Show Snapper root snapshots and ESP boot copies
  notify            If this boot is a snapshot, send a restore notification
  status            Print whether this boot is a Snapper snapshot

NixOS generations (nixos-rebuild) are the other Limine menu — they do not
roll back the live @ / @home subvolumes. Snapshot restore does not touch @home.
EOF
}

with_lock() {
  if [[ -n "${OMARCHY_SNAPPER_LOCKED:-}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$LOCKFILE")"
  exec 9>"$LOCKFILE"
  flock -w 60 9
  OMARCHY_SNAPPER_LOCKED=1
}

is_snapshot_boot() {
  [[ "$(tr ' ' '\n' </proc/cmdline)" == *".snapshots/"*"/snapshot"* ]]
}

snapshot_id_from_cmdline() {
  local cmd id
  cmd="$(tr '\0' ' ' </proc/cmdline)"
  if [[ "$cmd" =~ \.snapshots/([0-9]+)/snapshot ]]; then
    id="${BASH_REMATCH[1]}"
    printf '%s\n' "$id"
    return 0
  fi
  return 1
}

strip_hash() {
  local uri="$1"
  printf '%s\n' "${uri%%#*}"
}

uri_to_path() {
  local uri rel
  uri="$(strip_hash "$1")"
  uri="${uri#"${uri%%[![:space:]]*}"}"
  uri="${uri%"${uri##*[![:space:]]}"}"
  case "$uri" in
    boot\(\):*)
      rel="${uri#boot():}"
      rel="/${rel#/}"
      printf '%s\n' "${ESP_PATH}${rel}"
      ;;
    /*)
      printf '%s\n' "$uri"
      ;;
    *)
      printf '%s\n' "$uri"
      ;;
  esac
}

path_to_uri() {
  local path="$1"
  local rel="${path#"$ESP_PATH"}"
  printf 'boot():%s\n' "$rel"
}

rewrite_rootflags() {
  local cmdline="$1"
  local subvol="$2"
  local flags prefix rest

  if [[ "$cmdline" =~ (^|[[:space:]])rootflags= ]]; then
    prefix="${cmdline%%rootflags=*}"
    rest="${cmdline#*rootflags=}"
    flags="${rest%% *}"
    rest="${rest#"$flags"}"
    if [[ "$flags" == *subvol=* ]]; then
      flags="$(printf '%s\n' "$flags" | sed -E "s#(^|,)subvol=[^ ,]*#\1subvol=${subvol}#")"
    else
      flags="${flags},subvol=${subvol}"
    fi
    if [[ "$flags" != *rw* ]]; then
      flags="${flags},rw"
    fi
    printf '%srootflags=%s%s\n' "$prefix" "$flags" "$rest"
  else
    printf '%s rootflags=subvol=%s,rw\n' "$cmdline" "$subvol"
  fi
}

# Print: kernel_path<TAB>cmdline<TAB>module_path [TAB module_path...]
extract_template() {
  local conf="$1"
  [[ -f "$conf" ]] || return 1
  awk '
    BEGIN { inblk=0; kernel=""; cmdline=""; mods="" }
    /^[\/]/ {
      if (inblk && kernel != "") {
        print kernel "\t" cmdline "\t" mods
        exit
      }
      if ($0 !~ /^\/\//) {
        inblk=0
        kernel=""; cmdline=""; mods=""
      }
      next
    }
    /^[[:space:]]*protocol:[[:space:]]*linux[[:space:]]*$/ { inblk=1; next }
    inblk && /^[[:space:]]*kernel_path:[[:space:]]*/ {
      sub(/^[[:space:]]*kernel_path:[[:space:]]*/, "")
      kernel=$0
      next
    }
    inblk && /^[[:space:]]*cmdline:[[:space:]]*/ {
      sub(/^[[:space:]]*cmdline:[[:space:]]*/, "")
      cmdline=$0
      next
    }
    inblk && /^[[:space:]]*module_path:[[:space:]]*/ {
      sub(/^[[:space:]]*module_path:[[:space:]]*/, "")
      if (mods != "") mods = mods "\t" $0
      else mods = $0
      next
    }
    END {
      if (inblk && kernel != "") print kernel "\t" cmdline "\t" mods
    }
  ' "$conf"
}

snapper_rows() {
  # number|date|description  newest first, skip current (0)
  snapper --csvout -c "$SNAPPER_CONFIG" list 2>/dev/null | awk -F, '
    NR==1 {
      for (i = 1; i <= NF; i++) {
        if ($i == "number") n = i
        if ($i == "date") d = i
        if ($i == "description") desc = i
      }
      next
    }
    n == 0 { next }
    $(n)+0 == 0 { next }
    { print $(n) "|" $(d) "|" $(desc) }
  ' | sort -t'|' -k1,1nr
}

ensure_writable() {
  local snap="$1"
  [[ "$SNAPSHOT_WRITABLE" == "yes" ]] || return 0
  [[ -e "$snap" ]] || return 0
  btrfs property set -ts "$snap" ro false 2>/dev/null || true
}

copy_boot_files() {
  local id="$1"
  local kernel_uri="$2"
  local mods="$3"
  local dest="${ESP_PATH}/${SNAPSHOT_DIR_NAME}/${id}"
  local src path i=0 first_initrd=""

  mkdir -p "$dest"
  src="$(uri_to_path "$kernel_uri")"
  if [[ ! -f "$src" ]]; then
    echo "${SCRIPT_NAME}: kernel not on ESP: $src" >&2
    return 1
  fi
  cp -f "$src" "$dest/bzImage"

  if [[ -n "$mods" ]]; then
    IFS=$'\t' read -r -a mod_arr <<<"$mods"
    for path in "${mod_arr[@]}"; do
      [[ -n "$path" ]] || continue
      src="$(uri_to_path "$path")"
      if [[ ! -f "$src" ]]; then
        echo "${SCRIPT_NAME}: initrd/module not on ESP: $src" >&2
        continue
      fi
      if [[ -z "$first_initrd" ]]; then
        cp -f "$src" "$dest/initrd"
        first_initrd="$dest/initrd"
      else
        i=$((i + 1))
        cp -f "$src" "$dest/extra-${i}"
      fi
    done
  fi
  [[ -f "$dest/bzImage" ]]
}

write_snapshot_block() {
  local id="$1" date="$2" desc="$3" cmdline="$4"
  local dest_uri_k dest_uri_i extra
  dest_uri_k="$(path_to_uri "${ESP_PATH}/${SNAPSHOT_DIR_NAME}/${id}/bzImage")"
  printf '  //%s\n' "${date}"
  printf '  comment: snapper #%s %s\n' "$id" "$desc"
  printf '  protocol: linux\n'
  printf '  kernel_path: %s\n' "$dest_uri_k"
  printf '  cmdline: %s\n' "$cmdline"
  if [[ -f "${ESP_PATH}/${SNAPSHOT_DIR_NAME}/${id}/initrd" ]]; then
    dest_uri_i="$(path_to_uri "${ESP_PATH}/${SNAPSHOT_DIR_NAME}/${id}/initrd")"
    printf '  module_path: %s\n' "$dest_uri_i"
  fi
  local n
  for extra in "${ESP_PATH}/${SNAPSHOT_DIR_NAME}/${id}"/extra-*; do
    [[ -f "$extra" ]] || continue
    n="$(path_to_uri "$extra")"
    printf '  module_path: %s\n' "$n"
  done
  printf '\n'
}

cmd_sync() {
  with_lock
  resolve_limine_conf
  if [[ ! -f "$LIMINE_CONF" ]]; then
    echo "${SCRIPT_NAME}: no Limine config at $LIMINE_CONF (rebuild with boot.loader.limine.enable)" >&2
    return 1
  fi

  local template kernel_uri cmdline mods
  template="$(extract_template "$LIMINE_CONF" || true)"
  if [[ -z "$template" ]]; then
    echo "${SCRIPT_NAME}: no protocol: linux generation entry in $LIMINE_CONF" >&2
    echo "${SCRIPT_NAME}: snapshot menu needs a NixOS generation to copy kernels from" >&2
    return 1
  fi
  IFS=$'\t' read -r kernel_uri cmdline mods <<<"$template"

  local prefix
  prefix="$(awk '
    /^\/Snapshots[[:space:]]*$/ { exit }
    { print }
  ' "$LIMINE_CONF")"

  local kept=0 id date desc snap_path subvol block=""
  local -a keep_ids=()

  if command -v snapper >/dev/null && [[ -d /.snapshots ]]; then
    while IFS='|' read -r id date desc; do
      [[ -n "$id" ]] || continue
      if [[ "$MAX_SNAPSHOT_ENTRIES" != "auto" && "$kept" -ge "$MAX_SNAPSHOT_ENTRIES" ]]; then
        break
      fi
      snap_path="/.snapshots/${id}/snapshot"
      [[ -d "$snap_path" ]] || continue
      ensure_writable "$snap_path"
      if ! copy_boot_files "$id" "$kernel_uri" "$mods"; then
        echo "${SCRIPT_NAME}: skipping snapshot ${id} (missing kernel copy)" >&2
        continue
      fi
      subvol="${ROOT_SNAPSHOTS_PATH#/}/${id}/snapshot"
      block+="$(write_snapshot_block "$id" "$date" "$desc" "$(rewrite_rootflags "$cmdline" "$subvol")")"
      keep_ids+=("$id")
      kept=$((kept + 1))
    done < <(snapper_rows)
  fi

  {
    printf '%s\n' "$prefix"
    printf '\n'
    printf '# Snapper filesystem snapshots of @ — not NixOS generations.\n'
    printf '# Boot one of these, then run: omarchy-snapshot restore\n'
    printf '/Snapshots\n'
    printf '%s' "$block"
  } >"${LIMINE_CONF}.omarchy-tmp"
  mv -f "${LIMINE_CONF}.omarchy-tmp" "$LIMINE_CONF"

  # Drop ESP copies that are no longer in the menu.
  local dir sid
  if [[ -d "${ESP_PATH}/${SNAPSHOT_DIR_NAME}" ]]; then
    for dir in "${ESP_PATH}/${SNAPSHOT_DIR_NAME}"/*; do
      [[ -d "$dir" ]] || continue
      sid="$(basename "$dir")"
      [[ "$sid" =~ ^[0-9]+$ ]] || continue
      local found=0 k
      for k in "${keep_ids[@]+"${keep_ids[@]}"}"; do
        if [[ "$k" == "$sid" ]]; then
          found=1
          break
        fi
      done
      if [[ "$found" -eq 0 ]]; then
        rm -rf "$dir"
      fi
    done
  fi

  echo "${SCRIPT_NAME}: updated ${LIMINE_CONF} (${kept} snapshot entries)"
}

root_device() {
  local src
  src="$(findmnt -nvo SOURCE -T /)"
  src="${src%%\[*}"
  printf '%s\n' "$src"
}

cmd_restore() {
  local yes=0
  if [[ "${1:-}" == "--yes" || "${OMARCHY_SNAPSHOT_RESTORE:-}" == "yes" ]]; then
    yes=1
  fi

  local fstype
  fstype="$(findmnt -nvo FSTYPE -T / || true)"
  if [[ "$fstype" == "overlay" ]]; then
    echo "${SCRIPT_NAME}: / is overlayfs. Snapshot restore needs a real Btrfs /." >&2
    echo "NixOS Omarchy does not enable btrfs-overlayfs (it breaks restore on Omarchy too)." >&2
    exit 1
  fi
  if [[ "$fstype" != "btrfs" ]]; then
    echo "${SCRIPT_NAME}: / is ${fstype:-unknown}, not btrfs." >&2
    exit 1
  fi

  local id
  if ! id="$(snapshot_id_from_cmdline)"; then
    echo "${SCRIPT_NAME}: this boot is not a Snapper snapshot." >&2
    echo "Pick an entry under Limine → Snapshots, boot it, then run omarchy-snapshot restore." >&2
    exit 1
  fi

  echo "Replace Btrfs subvolume ${ROOT_SUBVOLUME} with snapshot #${id}."
  echo "/home stays on @home (not rolled back). NixOS generation entries are unrelated."
  if [[ "$yes" -ne 1 ]]; then
    printf 'Continue? [y/N] '
    read -r answer
    case "$answer" in
      y | Y | yes | YES) ;;
      *)
        echo "aborted"
        exit 1
        ;;
    esac
  fi

  with_lock
  local dev ts backup
  dev="$(root_device)"
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="${ROOT_SUBVOLUME}-pre-restore-${ts}"
  mkdir -p "$TOPLEVEL_MOUNT"
  if findmnt "$TOPLEVEL_MOUNT" >/dev/null 2>&1; then
    umount "$TOPLEVEL_MOUNT" || true
  fi
  mount -t btrfs -o subvol=/ "$dev" "$TOPLEVEL_MOUNT"
  trap 'umount "${TOPLEVEL_MOUNT}" 2>/dev/null || true' EXIT

  local old="${TOPLEVEL_MOUNT}/${ROOT_SUBVOLUME}"
  local new_backup="${TOPLEVEL_MOUNT}/${backup}"
  local snap="${TOPLEVEL_MOUNT}/${ROOT_SUBVOLUME}/.snapshots/${id}/snapshot"
  if [[ ! -e "$old" ]]; then
    echo "${SCRIPT_NAME}: ${old} does not exist on the toplevel" >&2
    exit 1
  fi
  if [[ ! -e "$snap" ]]; then
    # After we rename @, the snapshot path moves with it. Check the live mount too.
    snap="/.snapshots/${id}/snapshot"
  fi

  echo "${SCRIPT_NAME}: renaming ${ROOT_SUBVOLUME} → ${backup}"
  mv "$old" "$new_backup"

  local snap_after="${new_backup}/.snapshots/${id}/snapshot"
  if [[ ! -e "$snap_after" ]]; then
    echo "${SCRIPT_NAME}: snapshot #${id} not found at ${snap_after}" >&2
    echo "Moving ${backup} back to ${ROOT_SUBVOLUME}" >&2
    mv "$new_backup" "$old"
    exit 1
  fi

  echo "${SCRIPT_NAME}: snapshotting #${id} onto ${ROOT_SUBVOLUME}"
  btrfs subvolume snapshot "$snap_after" "$old"

  # Re-parent the nested Snapper subvolume (disko: @/.snapshots).
  # Do not mv every directory under backup — those are @'s files.
  if [[ -d "${new_backup}/.snapshots" ]]; then
    if [[ -e "${old}/.snapshots" ]]; then
      echo "${SCRIPT_NAME}: new @ already has .snapshots; leaving backup copy on ${backup}" >&2
    else
      echo "${SCRIPT_NAME}: re-parenting .snapshots onto new ${ROOT_SUBVOLUME}"
      mv "${new_backup}/.snapshots" "${old}/.snapshots"
    fi
  fi

  echo "${SCRIPT_NAME}: previous root kept as subvolume ${backup}"
  echo "Reboot to boot the restored @. Delete the backup later with:"
  echo "  btrfs subvolume delete ${TOPLEVEL_MOUNT}/${backup}"
  echo "  (mount toplevel first: mount -o subvol=/ ${dev} ${TOPLEVEL_MOUNT})"
}

cmd_create() {
  local desc="${*:-}"
  if [[ -z "$desc" ]]; then
    desc="omarchy-nix $(nixos-version 2>/dev/null || echo unknown) $(date '+%Y-%m-%d %H:%M:%S')"
  fi
  if ! command -v snapper >/dev/null; then
    echo "${SCRIPT_NAME}: snapper not installed" >&2
    exit 127
  fi
  local configs config
  mapfile -t configs < <(snapper --csvout list-configs | awk -F, 'NR>1 { print $1 }')
  if [[ "${#configs[@]}" -eq 0 ]]; then
    echo "${SCRIPT_NAME}: no snapper configs" >&2
    exit 1
  fi
  echo "Create system snapshot"
  for config in "${configs[@]}"; do
    snapper -c "$config" create -c number -d "$desc"
    snapper -c "$config" cleanup number || true
  done
  cmd_sync || true
}

cmd_list() {
  echo "Snapper config ${SNAPPER_CONFIG}:"
  snapper -c "$SNAPPER_CONFIG" list || true
  echo
  echo "ESP snapshot copies (${ESP_PATH}/${SNAPSHOT_DIR_NAME}):"
  if [[ -d "${ESP_PATH}/${SNAPSHOT_DIR_NAME}" ]]; then
    ls -1 "${ESP_PATH}/${SNAPSHOT_DIR_NAME}" 2>/dev/null || echo "(none)"
  else
    echo "(none)"
  fi
}

cmd_status() {
  local id
  if id="$(snapshot_id_from_cmdline)"; then
    echo "snapshot ${id}"
    return 0
  fi
  echo "live"
  return 1
}

cmd_notify() {
  local id
  if ! id="$(snapshot_id_from_cmdline)"; then
    exit 0
  fi
  local title="Booted into snapshot #${id}"
  local body="This is a Snapper filesystem snapshot of @, not a NixOS generation. Click restore or run: omarchy-snapshot restore"
  if command -v notify-send >/dev/null; then
    local action
    action="$(notify-send -u critical --app-name="Omarchy snapshot" --action="restore=Restore now" "$title" "$body" -t 0 || true)"
    if [[ "$action" == "restore" ]]; then
      exec omarchy-limine-snapper restore
    fi
  else
    echo "${title}: ${body}"
  fi
}

case "${1:-}" in
  sync)
    shift
    cmd_sync "$@"
    ;;
  restore)
    shift
    cmd_restore "$@"
    ;;
  create)
    shift
    cmd_create "$@"
    ;;
  list)
    cmd_list
    ;;
  notify)
    cmd_notify
    ;;
  status)
    cmd_status
    ;;
  -h | --help | help | "")
    usage
    [[ -n "${1:-}" ]]
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
