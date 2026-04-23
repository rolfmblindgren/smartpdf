#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${SMARTPDF_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/smartpdf/watch.conf}"
if [[ -e "$CONFIG_FILE" && ! -r "$CONFIG_FILE" ]]; then
  printf '%s %s\n' "$(date '+%F %T')" "kan ikke lese config: $CONFIG_FILE" >&2
  exit 1
fi
if [[ -r "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
fi

SOURCE_DIR="${SMARTPDF_SOURCE_DIR:-$HOME/Dropbox/From_BrotherDevice}"
DEST_DIR="${SMARTPDF_DEST_DIR:-$HOME/Tresorit/Scanned Documents}"
SMARTPDF_BIN="${SMARTPDF_BIN:-$HOME/bin/smartpdf}"
LOCK_FILE="${SMARTPDF_LOCK_FILE:-${TMPDIR:-/tmp}/smartpdf-watch.lock}"
STALE_SECONDS="${SMARTPDF_STALE_SECONDS:-15}"

have() { command -v "$1" >/dev/null 2>&1; }

default_trash_dir() {
  case "$(uname -s)" in
    Darwin)
      printf '%s\n' "$HOME/.Trash"
      ;;
    Linux)
      if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        printf '%s\n' "$XDG_DATA_HOME/Trash/files"
      else
        printf '%s\n' "$HOME/.local/share/Trash/files"
      fi
      ;;
    *)
      printf '%s\n' "$HOME/.Trash"
      ;;
  esac
}

TRASH_DIR="${SMARTPDF_TRASH_DIR:-$(default_trash_dir)}"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*"
}

unique_path() {
  local path="$1"
  local candidate="$path"
  local n=1

  while [[ -e "$candidate" ]]; do
    candidate="${path}.${n}"
    n=$((n + 1))
  done

  printf '%s\n' "$candidate"
}

is_stable() {
  local file="$1"
  local now mtime age

  now=$(date +%s)
  mtime=$(stat -f '%m' "$file")
  age=$((now - mtime))

  (( age >= STALE_SECONDS ))
}

trash_source() {
  local src="$1"
  local base="$2"
  local trash_target

  if have trash; then
    if trash "$src"; then
      printf '%s\n' "original -> system trash"
      return 0
    fi
    log "advarsel: trash feilet, prøver fallback"
  fi

  if have gio; then
    if gio trash "$src"; then
      printf '%s\n' "original -> system trash"
      return 0
    fi
    log "advarsel: gio trash feilet, prøver fallback"
  fi

  mkdir -p "$TRASH_DIR"
  trash_target=$(unique_path "$TRASH_DIR/$base")
  mv "$src" "$trash_target"
  printf '%s\n' "original -> $(basename "$trash_target")"
}

process_one() {
  local src="$1"
  local base tmp_out final_out trash_note

  base=$(basename "$src")
  final_out="$DEST_DIR/$base"
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/smartpdf-watch.XXXXXX.pdf")"

  if ! "$SMARTPDF_BIN" "$src" "$tmp_out" >/dev/null; then
    rm -f "$tmp_out"
    log "feil: kunne ikke behandle $src"
    return 1
  fi

  mkdir -p "$DEST_DIR"
  mv -f "$tmp_out" "$final_out"

  trash_note=$(trash_source "$src" "$base")
  log "ok: $base -> $(basename "$final_out"), $trash_note"
}

main() {
  local src

  [[ -d "$SOURCE_DIR" ]] || {
    log "mangler mappe: $SOURCE_DIR"
    exit 1
  }

  have "$SMARTPDF_BIN" || {
    log "mangler smartpdf: $SMARTPDF_BIN"
    exit 1
  }

  mkdir -p "$DEST_DIR" "$TRASH_DIR"

  for src in "$SOURCE_DIR"/*.pdf "$SOURCE_DIR"/*.PDF; do
    [[ -e "$src" ]] || continue
    [[ -f "$src" ]] || continue
    is_stable "$src" || continue
    process_one "$src" || true
  done
}

if [[ -f "$LOCK_FILE" ]]; then
  old_pid=$(<"$LOCK_FILE")
  if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi

printf '%s\n' "$$" >"$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

main

# Local Variables:
# mode: sh
# sh-basic-offset: 2
# End:
