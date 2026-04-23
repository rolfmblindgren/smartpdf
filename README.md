# smartpdf

A small shell script for choosing a reasonable PDF processing path on macOS.

## Usage

```sh
smartpdf INN.pdf UT.pdf [--pdfa]
```

## What it does

- Uses Ghostscript for text-heavy PDFs with few images.
- Uses OCRmyPDF for scanned or mixed PDFs.
- Optionally runs pdfcpu as a final optimization pass when it makes the file smaller.

## Notes

- `--pdfa` keeps the output in PDF/A mode.
- The `smartpdf` command in `~/bin` is a symlink to `~/src/smartpdf/smartpdf.sh`.
