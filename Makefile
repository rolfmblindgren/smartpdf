.DEFAULT_GOAL := check

OS_NAME ?= $(shell uname -s)
DISTRO_ID ?= $(shell sh -c '. /etc/os-release 2>/dev/null; printf "%s" "$$ID"')
BIN_DIR ?= $(HOME)/bin
SCRIPT := smartpdf.sh
LINK := $(BIN_DIR)/smartpdf
WATCHER := smartpdf-watch.sh
PLIST_SRC := launchd/com.roffe.smartpdf.watch.plist
PLIST_DST := $(HOME)/Library/LaunchAgents/com.roffe.smartpdf.watch.plist

REQUIRED_CMDS := pdfinfo pdffonts pdfimages gs ocrmypdf qpdf
OPTIONAL_CMDS := pdfcpu

.PHONY: help check deps deps-admin link watch-install watch-uninstall install

help:
	@printf '%s\n' \
		'Targets:' \
		'  make check      - show required and optional PDF dependencies' \
		'  make deps       - install missing dependencies with the local package manager' \
		'  make deps-admin - same as deps, but refresh sudo auth first' \
		'  make link       - create ~/bin/smartpdf symlink' \
		'  make watch-install   - install and boot the launchd watcher' \
		'  make watch-uninstall - unload the launchd watcher' \
		'  make install    - run deps and link'

check:
	@set -eu; \
	os_name='$(OS_NAME)'; \
	distro_id='$(DISTRO_ID)'; \
	have() { command -v "$$1" >/dev/null 2>&1; }; \
	detect_pm() { \
		if [ "$$os_name" = Darwin ]; then \
			echo brew; \
			return; \
		fi; \
		if [ "$$os_name" = Linux ]; then \
			case "$$distro_id" in \
				debian|ubuntu|linuxmint|pop|kali|raspbian) echo apt-get; return ;; \
				fedora) echo dnf; return ;; \
			esac; \
		fi; \
		if have brew; then \
			echo brew; \
			return; \
		fi; \
		echo unsupported; \
	}; \
	pkg_for() { \
		pm="$$1"; cmd="$$2"; \
		case "$$pm:$$cmd" in \
			brew:pdfinfo|brew:pdffonts|brew:pdfimages) echo poppler ;; \
			apt-get:pdfinfo|apt-get:pdffonts|apt-get:pdfimages) echo poppler-utils ;; \
			dnf:pdfinfo|dnf:pdffonts|dnf:pdfimages) echo poppler-utils ;; \
			brew:gs|apt-get:gs|dnf:gs) echo ghostscript ;; \
			brew:ocrmypdf|apt-get:ocrmypdf) echo ocrmypdf ;; \
			dnf:ocrmypdf) echo 'ocrmypdf tesseract-osd' ;; \
			brew:qpdf|apt-get:qpdf|dnf:qpdf) echo qpdf ;; \
			brew:pdfcpu) echo pdfcpu ;; \
			dnf:pdfcpu) echo golang-github-pdfcpu ;; \
			apt-get:pdfcpu) echo GO_INSTALL ;; \
			*) echo "" ;; \
		esac; \
	}; \
	pm=$$(detect_pm); \
	if [ "$$pm" = unsupported ]; then \
		echo "Ustøttet plattform: $$os_name $$distro_id"; \
		exit 2; \
	fi; \
	required_missing=""; \
	optional_note=""; \
	for cmd in $(REQUIRED_CMDS); do \
		if ! have "$$cmd"; then \
			pkgs=$$(pkg_for "$$pm" "$$cmd"); \
			if [ -z "$$pkgs" ]; then \
				required_missing="$$required_missing $$cmd"; \
			else \
				for pkg in $$pkgs; do \
					case " $$required_missing " in \
						*" $$pkg "*) ;; \
						*) required_missing="$$required_missing $$pkg" ;; \
					esac; \
				done; \
			fi; \
		fi; \
	done; \
	for cmd in $(OPTIONAL_CMDS); do \
		if ! have "$$cmd"; then \
			pkg=$$(pkg_for "$$pm" "$$cmd"); \
			case "$$pkg" in \
				GO_INSTALL) optional_note="$$optional_note go install github.com/pdfcpu/pdfcpu/cmd/pdfcpu@latest" ;; \
				"") optional_note="$$optional_note $$cmd" ;; \
				*) optional_note="$$optional_note $$pkg" ;; \
			esac; \
		fi; \
	done; \
	if [ -n "$$required_missing" ]; then \
		echo "Mangler påkrevde dependencies:$${required_missing# }"; \
		exit 1; \
	fi; \
	echo "OK: påkrevde dependencies er installert."; \
	if [ -n "$$optional_note" ]; then \
		echo "Valgfritt mangler:$${optional_note# }"; \
	fi

deps:
	@set -eu; \
	os_name='$(OS_NAME)'; \
	distro_id='$(DISTRO_ID)'; \
	bin_dir='$(BIN_DIR)'; \
	have() { command -v "$$1" >/dev/null 2>&1; }; \
	detect_pm() { \
		if [ "$$os_name" = Darwin ]; then \
			echo brew; \
			return; \
		fi; \
		if [ "$$os_name" = Linux ]; then \
			case "$$distro_id" in \
				debian|ubuntu|linuxmint|pop|kali|raspbian) echo apt-get; return ;; \
				fedora) echo dnf; return ;; \
			esac; \
		fi; \
		if have brew; then \
			echo brew; \
			return; \
		fi; \
		echo unsupported; \
	}; \
	pkg_for() { \
		pm="$$1"; cmd="$$2"; \
		case "$$pm:$$cmd" in \
			brew:pdfinfo|brew:pdffonts|brew:pdfimages) echo poppler ;; \
			apt-get:pdfinfo|apt-get:pdffonts|apt-get:pdfimages) echo poppler-utils ;; \
			dnf:pdfinfo|dnf:pdffonts|dnf:pdfimages) echo poppler-utils ;; \
			brew:gs|apt-get:gs|dnf:gs) echo ghostscript ;; \
			brew:ocrmypdf|apt-get:ocrmypdf) echo ocrmypdf ;; \
			dnf:ocrmypdf) echo 'ocrmypdf tesseract-osd' ;; \
			brew:qpdf|apt-get:qpdf|dnf:qpdf) echo qpdf ;; \
			brew:pdfcpu) echo pdfcpu ;; \
			dnf:pdfcpu) echo golang-github-pdfcpu ;; \
			apt-get:pdfcpu) echo GO_INSTALL ;; \
			*) echo "" ;; \
		esac; \
	}; \
	pm=$$(detect_pm); \
	if [ "$$pm" = unsupported ]; then \
		echo "Ustøttet plattform: $$os_name $$distro_id"; \
		exit 2; \
	fi; \
	sudo_cmd=; \
	if [ "$$(id -u)" -ne 0 ]; then \
		sudo_cmd=sudo; \
	fi; \
	required_pkgs=""; \
	optional_pkgs=""; \
	optional_go=false; \
	add_pkg() { \
		var="$$1"; val="$$2"; \
		case "$$var" in \
			required_pkgs) \
				case " $$required_pkgs " in *" $$val "*) ;; *) required_pkgs="$$required_pkgs $$val" ;; esac ;; \
			optional_pkgs) \
				case " $$optional_pkgs " in *" $$val "*) ;; *) optional_pkgs="$$optional_pkgs $$val" ;; esac ;; \
		esac; \
	}; \
	for cmd in $(REQUIRED_CMDS); do \
		if ! have "$$cmd"; then \
			pkgs=$$(pkg_for "$$pm" "$$cmd"); \
			if [ -z "$$pkgs" ]; then \
				echo "mangler: $$cmd"; \
				exit 2; \
			fi; \
			for pkg in $$pkgs; do \
				case "$$pkg" in \
					GO_INSTALL) optional_go=true ;; \
					*) add_pkg required_pkgs "$$pkg" ;; \
				esac; \
			done; \
		fi; \
	done; \
	if ! have pdfcpu; then \
		pkg=$$(pkg_for "$$pm" pdfcpu); \
		case "$$pkg" in \
			GO_INSTALL) optional_go=true ;; \
			"") : ;; \
			*) add_pkg optional_pkgs "$$pkg" ;; \
		esac; \
	fi; \
	if [ -n "$$required_pkgs" ]; then \
		if [ "$$pm" = brew ]; then \
			echo "Installerer: $${required_pkgs# }"; \
			brew install $${required_pkgs# }; \
		elif [ "$$pm" = apt-get ]; then \
			$$sudo_cmd apt-get update; \
			$$sudo_cmd apt-get install -y $${required_pkgs# }; \
		elif [ "$$pm" = dnf ]; then \
			$$sudo_cmd dnf install -y $${required_pkgs# }; \
		fi; \
	fi; \
	if [ -n "$$optional_pkgs" ]; then \
		echo "Installerer valgfritt: $${optional_pkgs# }"; \
		if [ "$$pm" = brew ]; then \
			brew install $${optional_pkgs# } || true; \
		elif [ "$$pm" = apt-get ]; then \
			$$sudo_cmd apt-get install -y $${optional_pkgs# } || true; \
		elif [ "$$pm" = dnf ]; then \
			$$sudo_cmd dnf install -y $${optional_pkgs# } || true; \
		fi; \
	fi; \
	if [ "$$optional_go" = true ]; then \
		if have go; then \
			mkdir -p "$$bin_dir"; \
			GOBIN="$$bin_dir" go install github.com/pdfcpu/pdfcpu/cmd/pdfcpu@latest; \
			echo "Installerte pdfcpu via go i $$bin_dir"; \
		else \
			echo "pdfcpu ble ikke installert fordi go mangler."; \
		fi; \
	fi

deps-admin:
	@set -eu; \
	if [ "$$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then \
		sudo -v; \
	fi; \
	$(MAKE) deps

link:
	@mkdir -p "$(BIN_DIR)"
	@ln -sfn "$(CURDIR)/$(SCRIPT)" "$(LINK)"
	@echo "Koblet $(LINK) -> $(CURDIR)/$(SCRIPT)"

watch-install: install
	@set -eu; \
	mkdir -p "$(HOME)/Library/LaunchAgents" "$(HOME)/Library/Logs"; \
	cp "$(CURDIR)/$(PLIST_SRC)" "$(PLIST_DST)"; \
	uid=$$(id -u); \
	launchctl bootout gui/$$uid "$(PLIST_DST)" >/dev/null 2>&1 || true; \
	launchctl bootstrap gui/$$uid "$(PLIST_DST)"; \
	launchctl kickstart -k gui/$$uid/com.roffe.smartpdf.watch; \
	echo "Installerte og startet com.roffe.smartpdf.watch"

watch-uninstall:
	@set -eu; \
	uid=$$(id -u); \
	launchctl bootout gui/$$uid "$(PLIST_DST)" >/dev/null 2>&1 || true; \
	rm -f "$(PLIST_DST)"; \
	echo "Fjernet com.roffe.smartpdf.watch"

install: deps link

# Local Variables:
# mode: makefile-gmake
# End:
