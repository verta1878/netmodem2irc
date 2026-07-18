# netmodem2irc — Makefile
# Requires: fpc264irc r6.1+ (github.com/verta1878/fpc264irc)
#           i686-w64-mingw32-windres for icon resources

FPCIRC  ?= $(HOME)/fpc264irc
WINDRES ?= i686-w64-mingw32-windres
SHELL    = /bin/sh

.PHONY: all tests resources win32 server config cpl fossil clean

all: tests win32 fossil

tests:
	@FPCIRC=$(FPCIRC) ./build.sh tests

resources:
	@WINDRES=$(WINDRES) ./build.sh resources

win32:
	@FPCIRC=$(FPCIRC) WINDRES=$(WINDRES) ./build.sh win32

server: resources
	@FPCIRC=$(FPCIRC) ./build.sh server

config: resources
	@FPCIRC=$(FPCIRC) ./build.sh config

cpl: resources
	@FPCIRC=$(FPCIRC) ./build.sh cpl

fossil:
	@FPCIRC=$(FPCIRC) ./build.sh fossil

clean:
	@echo "=== Cleaning build artifacts ==="
	@find . -not -path './.git/*' -not -path './dos/bin/*' \
		\( -name "*.o" -o -name "*.ppu" -o -name "*.or" \
		-o -name "*.s" -o -name "*.rst" -o -name "ppas.sh" \
		-o -name "*.bak" -o -name "link.res" -o -name "*.res" \) \
		-type f -delete 2>/dev/null || true
	@rm -rf out/
	@echo "  done"
