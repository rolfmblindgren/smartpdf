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

## Makefile

```sh
make check
make deps
make deps-admin
make link
make install
```

`make deps-admin` refreshes sudo auth first, which is useful on Linux package managers. On macOS with Homebrew, `sudo` is not needed for the install itself.

The Makefile is platform-aware for macOS (`brew`), Debian/Ubuntu (`apt-get`), and Fedora (`dnf`). `pdfcpu` is treated as optional and is installed with `go install` when that is the best fallback.

## Automatic Watching

For the BrotherDevice drop folder, the repo also ships a small `launchd` watcher.

```sh
make watch-install
```

That watcher:

- watches `~/Dropbox/From_BrotherDevice`
- runs `smartpdf` on PDFs that have settled
- writes finished files to `~/Tresorit/Scanned Documents`
- moves originals into `~/.Thrash`

To remove it later:

```sh
make watch-uninstall
```

## Notes

- `--pdfa` keeps the output in PDF/A mode.
- The `smartpdf` command in `~/bin` is a symlink to `~/src/smartpdf/smartpdf.sh`.
