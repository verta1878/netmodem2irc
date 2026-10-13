#!/bin/sh
# ============================================================
#  NETMODEM.VXD build — JWasm + Open Watcom wlink (Linux)
#  wrench, 2026-10-13
#
#  Requires:
#    - jwasm (MASM-compatible assembler, github.com/JWasm/JWasm)
#    - wlink (Open Watcom v2 linker, LE/VxD format support)
#  Both build on Linux natively. No Wine, no MASM, no DDK needed.
# ============================================================
set -e
JWASM="${JWASM:-jwasm}"
WLINK="${WLINK:-wlink}"
SRC=../src
BUILD=.

echo "[1/2] Assembling NETMODEM.ASM..."
"$JWASM" -c -coff -DBLD_COFF -DIS_32 -Sg -DMASM6 -W2 -Zp1 -DNODECOUNT=16 \
    -I"$BUILD" -I"$SRC" -Fo NETMODEM.obj "$SRC/NETMODEM.ASM"

echo "[2/2] Linking NETMODEM.VXD..."
cat > netmodem.lnk << LNK
format windows vxd dynamic
file NETMODEM.obj
name ../bin/NETMODEM.vxd
export NETMODEM_DDB.1
LNK
"$WLINK" @netmodem.lnk

echo "Done: ../bin/NETMODEM.vxd"
file ../bin/NETMODEM.vxd
sha256sum ../bin/NETMODEM.vxd
