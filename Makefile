# ===========================================================================
# netmodem2irc — Makefile
# ===========================================================================
#
# Usage:
#   make                      build everything (tests + win32)
#   make tests                engine test suite (38 tests)
#   make win32                cross-compile NMServer.exe + NMConfig.exe
#   make resources            compile icon .rc -> .res
#   make dos                  DOS FOSSIL driver (not yet implemented)
#   make installer            build Inno installer (not yet implemented)
#   make clean                remove build artifacts
#
# Compiler selection (dual-compiler policy, see ROADMAP.md):
#   make tests                         # uses system fpc
#   make tests FPC=/opt/fpc322/bin/fpc  # explicit FPC 3.2.2
#   make win32 FPCIRC=~/fpc264irc      # fpc264irc for shipping binaries
#
# The project compiles under BOTH fpc264irc and stock FPC 3.x.
# fpc264irc produces the shipping binaries (3.6M, Win98 LCL patches).
# FPC 3.x produces verification binaries (20M, no Win98 patches).
# If a unit compiles under one and not the other, that is a finding.
# See ROADMAP.md "Dual-compiler policy".
#
# Debug builds:
#   make tests  DEFINES=-dNM_DEBUG     # enable NM_Debug logging
#   make win32  DEFINES=-dNM_DEBUG     # OutputDebugString + log file
#
# ---------------------------------------------------------------------------
# Three independent tracks. DOS doesn't feed i386.
#
#   Track 1 — i386 server:  make win32, make tests
#     NOTE: win32 = 32-bit PE. Runs on 64-bit Windows via WoW64.
#     Native x86_64 (make win64) is a future target, not yet implemented.
#   Track 2 — DOS driver:   make dos
#   Track 3 — Installer:    make installer
#
# Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)
# GPLv3 — see LICENSE
# ===========================================================================

# --- configurable paths ---
FPCIRC  ?= $(HOME)/fpc264irc
FPC     ?= fpc
WINDRES ?= i686-w64-mingw32-windres
DEFINES ?=
SHELL    = /bin/sh

# --- output directories ---
OUT_I386 = out/i386
OUT_DOS   = out/dos

# ===========================================================================
# Targets
# ===========================================================================

.PHONY: all tests win32 resources dos installer clean help

all: tests win32
	@echo
	@echo "=== all done ==="

# ---------------------------------------------------------------------------
# Track 1 — i386 server
# ---------------------------------------------------------------------------

tests:
	@echo "=== Engine Tests (38 tests, 0 failures expected) ==="
	@echo "    compiler: $(FPC)"
	@cd engine && FPC=$(FPC) sh test/run-tests.sh

win32:
	@FPCIRC=$(FPCIRC) WINDRES=$(WINDRES) ./build.sh win32

resources:
	@WINDRES=$(WINDRES) ./build.sh resources

# ---------------------------------------------------------------------------
# Track 2 — DOS driver (netfosdl.exe)
# ---------------------------------------------------------------------------

dos:
	@echo "=== DOS FOSSIL driver (netfosdl) ==="
	@echo "    NOT YET IMPLEMENTED — see ROADMAP.md Phase D1-D6"
	@echo "    The real 16550 UART does not exist yet."
	@echo "    When ready: ppcross8086 + msdos RTL only, no Watt-32."

# ---------------------------------------------------------------------------
# Track 3 — Installer (Inno Setup 5.6.1 FPC port)
# ---------------------------------------------------------------------------

installer:
	@echo "=== Installer (Inno Setup 5.6.1 FPC port) ==="
	@echo "    NOT YET IMPLEMENTED — see InnoIRC561/README.md"
	@echo "    ISCC.exe works. Setup.exe and ISCmplr.dll AV at init."
	@echo "    Use InnoIRC561/out/ISCC.exe directly for now."

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

clean:
	@./build.sh clean

help:
	@echo "netmodem2irc — build targets"
	@echo ""
	@echo "  make              build everything (tests + win32)"
	@echo "  make tests        engine test suite (38 tests)"
	@echo "  make win32        cross-compile NMServer + NMConfig"
	@echo "  make resources    compile icon .rc -> .res"
	@echo "  make dos          DOS FOSSIL driver (planned)"
	@echo "  make installer    Inno installer (planned)"
	@echo "  make clean        remove build artifacts"
	@echo "  make help         this message"
	@echo ""
	@echo "Compiler selection:"
	@echo "  FPC=path          set the compiler (default: fpc)"
	@echo "  FPCIRC=path       set fpc264irc root (default: ~/fpc264irc)"
	@echo "  DEFINES=-dFLAG    add compile defines (e.g. -dNM_DEBUG)"
	@echo ""
	@echo "See ROADMAP.md for the full project plan."
