#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SMARTPDF_SOURCE_DIR:-$HOME/Dropbox/From_BrotherDevice}"
DEST_DIR="${SMARTPDF_DEST_DIR:-$HOME/Tresorit/Scanned Documents}"
TRASH_DIR="${SMARTPDF_TRASH_DIR:-$HOME/.Thrash}"
SMARTPDF_BIN="${SMARTPDF_BIN:-$HOME/src/smartpdf/smartpdf.sh}"
LOCK_FILE="${SMARTPDF_LOCK_FILE:-${TMPDIR:-/tmp}/smartpdf-watch.lock}"
STALE_SECONDS="${SMARTPDF_STALE_SECONDS:-15}"

have() { command -v "$1" >/dev/null 2>&1; }

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

process_one() {
  local src="$1"
  local base tmp_out final_out trash_out trash_target

  base=$(basename "$src")
  final_out="$DEST_DIR/$base"
  trash_out="$TRASH_DIR/$base"
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/smartpdf-watch.XXXXXX.pdf")"

  if ! "$SMARTPDF_BIN" "$src" "$tmp_out" >/dev/null; then
    rm -f "$tmp_out"
    log "feil: kunne ikke behandle $src"
    return 1
  fi

  mkdir -p "$DEST_DIR" "$TRASH_DIR"
  mv -f "$tmp_out" "$final_out"

  trash_target=$(unique_path "$trash_out")
  mv "$src" "$trash_target"
  log "ok: $base -> $(basename "$final_out"), original -> $(basename "$trash_target")"
}

main() {
  local src

  [[ -d "$SOURCE_DIR" ]] || {
    log "mangler mappe: $SOURCE_DIR"
    exit 1
  }

  [[ -x "$SMARTPDF_BIN" ]] || {
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
