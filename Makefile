# netmodem2irc — Makefile
# Requires: fpc264irc r6.1+ (github.com/verta1878/fpc264irc)
#           i686-w64-mingw32-windres for icon resources

FPCIRC  ?= $(HOME)/fpc264irc
WINDRES ?= i686-w64-mingw32-windres
SHELL    = /bin/sh

.PHONY: all tests resources win32 fossil clean

all: tests win32 fossil

tests:
	@FPCIRC=$(FPCIRC) ./build.sh tests

resources:
	@WINDRES=$(WINDRES) ./build.sh resources

win32:
	@FPCIRC=$(FPCIRC) WINDRES=$(WINDRES) ./build.sh win32

fossil:
	@FPCIRC=$(FPCIRC) ./build.sh fossil

clean:
	@./build.sh clean
