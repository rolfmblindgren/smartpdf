#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "bruk: $0 INN.pdf UT.pdf [--pdfa]"
}

die() {
  echo "$*" >&2
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

IN="$1"
OUT="$2"
PDFA="${3:-}"

[[ -f "$IN" ]] || die "mangler fil: $IN"
[[ "$IN" != "$OUT" ]] || die "input og output kan ikke være samme fil"

have() { command -v "$1" >/dev/null 2>&1; }

for cmd in pdfinfo pdffonts pdfimages gs; do
  have "$cmd" || die "mangler: $cmd (installer via Homebrew)"
done

PDFCPU=false
if have pdfcpu; then
  PDFCPU=true
fi

maybe_pdfcpu_optimize() {
  [[ "$PDFCPU" == true ]] || return 0
  [[ "${PDFA}" == "--pdfa" ]] && return 0

  local input="$1"
  local tmp in_size out_size
  tmp="$(mktemp "${TMPDIR:-/tmp}/smartpdf-pdfcpu.XXXXXX.pdf")"

  if pdfcpu optimize "$input" "$tmp" >/dev/null 2>&1; then
    in_size=$(stat -f%z "$input")
    out_size=$(stat -f%z "$tmp")

    if (( out_size < in_size )); then
      mv "$tmp" "$input"
      echo "modus: pdfcpu etteroptimalisering (${in_size} -> ${out_size} bytes)"
    else
      rm -f "$tmp"
    fi
  else
    rm -f "$tmp"
    echo "advarsel: pdfcpu optimize feilet, beholder eksisterende utgave" >&2
  fi
}

# Hent enkel diagnostikk
PDFIMAGES_LIST=$(pdfimages -list "$IN" 2>/dev/null || true)
PAGES=$(pdfinfo "$IN" 2>/dev/null | awk -F': *' '/^Pages/{print $2+0}')
FONTS=$(pdffonts "$IN" 2>/dev/null | awk 'NR>2{c++} END{print c+0}')
# pdfimages -list har fargen i kolonne 6.
IMAGES=$(printf '%s\n' "$PDFIMAGES_LIST" | awk 'NR>2{c++} END{print c+0}')
COLOR_IMAGES=$(printf '%s\n' "$PDFIMAGES_LIST" | awk 'NR>2 {if (tolower($6) ~ /rgb|cmyk|icc/) c++} END{print c+0}')

# Tomt fallback
PAGES=${PAGES:-0}; FONTS=${FONTS:-0}; IMAGES=${IMAGES:-0}; COLOR_IMAGES=${COLOR_IMAGES:-0}

echo "sider=$PAGES, fonter=$FONTS, bilder=$IMAGES, fargebilder=$COLOR_IMAGES"

# Velg profil
JPEG_QUALITY=45
PNG_QUALITY=70
OPTLVL=3

# Heuristikk:
# - Har tekst og nesten ingen bilder → kun komprimering (Ghostscript)
# - Ellers → ocrmypdf (deskew/clean/optimize). Ved mye fargebilder: JPEG; ellers: JBIG2/PNG.
if (( FONTS > 0 && IMAGES <= 2 )); then
  echo "modus: bare komprimering (ghostscript)"
  gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
     -dPDFSETTINGS=/ebook \
     -dDetectDuplicateImages=true \
     -dDownsampleColorImages=true -dColorImageResolution=150 \
     -dDownsampleGrayImages=true  -dGrayImageResolution=150 \
     -dDownsampleMonoImages=true  -dMonoImageResolution=300 \
     -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$OUT" "$IN"
  maybe_pdfcpu_optimize "$OUT"
  exit 0
fi

# Mixed/scannet ⇒ OCRmyPDF
for cmd in ocrmypdf qpdf; do
  have "$cmd" || die "mangler: $cmd (installer via Homebrew)"
done

# Mye fargebilder? terskel 20 % av sidene eller >5 fargebilder
if (( COLOR_IMAGES >= 5 )) || { (( PAGES > 0 )) && (( COLOR_IMAGES*100/PAGES >= 20 )); }; then
  # foto/brosjyrer: prioriter JPEG
  echo "modus: OCR + optimalisering (foto/brosjyre-profil)"
  ARGS=(--rotate-pages --deskew --clean --skip-text --optimize "$OPTLVL" --jpeg-quality "$JPEG_QUALITY")
else
  # tekst/gråtoner: prioriter JBIG2/PNG
  echo "modus: OCR + optimalisering (tekst/grå-profil)"
  ARGS=(--rotate-pages --deskew --clean --skip-text --optimize "$OPTLVL" --jbig2-lossy --png-quality "$PNG_QUALITY")
fi

# PDF/A hvis ønsket
if [[ "${PDFA}" == "--pdfa" ]]; then
  ARGS+=(--output-type pdfa-2)
fi

# Kjør OCRmyPDF (OCR kun der det ikke finnes tekst; ellers hopper den over)
ocrmypdf "${ARGS[@]}" "$IN" "$OUT"
maybe_pdfcpu_optimize "$OUT"

# Local Variables:
# mode: sh
# sh-basic-offset: 2
# End:
