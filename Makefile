# netmodem2irc — Makefile
# Requires: fpc264irc r6.0+ (github.com/verta1878/fpc264irc)
#           i686-w64-mingw32-windres for icon resources

FPCIRC  ?= $(HOME)/fpc264irc
WINDRES ?= i686-w64-mingw32-windres
SHELL    = /bin/sh

.PHONY: all tests resources server config cpl fossil clean

all: tests resources server config cpl fossil

tests:
	@FPCIRC=$(FPCIRC) ./build.sh tests

resources:
	@WINDRES=$(WINDRES) ./build.sh resources

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
	@find . -not -path './.git/*' \
		\( -name "*.o" -o -name "*.ppu" -o -name "*.or" \
		-o -name "*.s" -o -name "*.rst" -o -name "ppas.sh" \
		-o -name "*.bak" -o -name "link.res" \) \
		-type f -delete 2>/dev/null || true
	@rm -rf out/
	@rm -f server/NMServer server/NMServer.exe server/NMServer.res
	@rm -f config/NMConfig config/NMConfig.exe config/NMConfig.res
	@rm -f cpl/NetModemCPL.dll cpl/NetModemCPL.cpl cpl/NetModemCPL.res
	@echo "  done (dos/bin/netfossl.exe preserved)"
