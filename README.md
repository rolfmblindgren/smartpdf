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

The Makefile is platform-aware for macOS (`brew`), Debian/Ubuntu (`apt-get`), and Fedora (`dnf`). `pdfcpu` is treated as optional and is installed with `go install` when that is the best fallback. `make link` creates both `~/bin/smartpdf` and `~/bin/smartpdf-watch`.

## Automatic Watching

The watcher reads a small shell config file at `~/.config/smartpdf/watch.conf`.

```sh
make watch-config
```

That installs a starter file from `config/smartpdf-watch.conf.example` if you do not already have one. Edit it if your source, destination, trash, or `smartpdf` path differs.

```sh
make watch-install
```

That watcher:

- runs from `~/bin/smartpdf-watch`
- watches the configured source folder
- runs `smartpdf` on PDFs that have settled
- writes finished files to the configured destination
- moves originals into the configured trash folder

To remove it later:

```sh
make watch-uninstall
```

## Notes

- `--pdfa` keeps the output in PDF/A mode.
- The `smartpdf` command in `~/bin` is a symlink to `~/src/smartpdf/smartpdf.sh`.
