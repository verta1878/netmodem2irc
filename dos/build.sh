#!/bin/sh
# netmodem2irc/dos — build netfossl.exe (i8086 DOS, fpcirc TCP/IP)
# Requires: fpc264irc repo with i8086 cross-compiler + OpenWatcom wlink
# Usage:  ./build.sh
#         FPCIRC=/path/to/fpc264irc ./build.sh
set -e
cd "$(dirname "$0")"

# Find fpc264irc
FPCIRC="${FPCIRC:-}"
if [ -z "$FPCIRC" ]; then
    for p in ../../../fpc264irc /tmp/fpc264irc_latest "$HOME/fpc264irc"; do
        [ -x "$p/bin/tools/i8086-msdos/ppcross8086" ] && FPCIRC="$p" && break
    done
fi
[ -z "$FPCIRC" ] && echo "Set FPCIRC=/path/to/fpc264irc" && exit 1

TOOLS="$FPCIRC/bin/tools/i8086-msdos"
UNITS="$FPCIRC/bin/units/i8086-msdos"
LIBS="$FPCIRC/lib/watt32/wattcpwl.lib"
WLINK=$(command -v wlink 2>/dev/null || echo "/opt/watcom/binl64/wlink")

WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT

echo "=== netfossl.exe build ==="

echo "[1/5] Compile"
"$TOOLS/ppcross8086" -Tmsdos -s -CX- -Fu"$UNITS" -FE"$WORK" fossil_dos.pas 2>&1 | tail -1
"$TOOLS/ppcross8086" -Tmsdos -s -CX- -Fu"$UNITS" -FE"$WORK" netmodem.pas 2>&1 | tail -1

echo "[2/5] Assemble"
python3 "$TOOLS/fixasm.py" "$WORK/fossil_dos.s"
python3 "$TOOLS/fixasm.py" "$WORK/netmodem.s"
nasm -f obj -o "$WORK/fossil_dos.o" "$WORK/fossil_dos.s"
nasm -f obj -o "$WORK/netmodem.o" "$WORK/netmodem.s"
nasm -f obj -o "$WORK/fpcheap.o" "$TOOLS/fpcheap.asm"
nasm -f obj -o "$WORK/stubs.o" stubs.asm

echo "[3/5] Resolve dependencies"
python3 - "$WORK" "$UNITS" "$TOOLS" "$LIBS" << 'PYEOF'
import os, sys
sys.path.insert(0, sys.argv[3])
exec(open(os.path.join(sys.argv[3], 'omfinfo.py')).read().replace('for fn in sys.argv[1:]:', 'if False:'))
work, units, libs = sys.argv[1], sys.argv[2], sys.argv[4]
needed, defined = set(), set()
for p in [f'{work}/netmodem.o', f'{work}/fossil_dos.o']:
    o = OMFObj(p); needed.update(o.extdefs); defined.update(o.pubdefs)
needed -= defined
index = {}
for unit in ['system', 'dos', 'strings', 'objpas']:
    sl = os.path.join(units, unit + '.sl')
    if not os.path.isdir(sl): continue
    for fn in sorted(os.listdir(sl)):
        if not fn.endswith('.o'): continue
        try: o = OMFObj(os.path.join(sl, fn)); [index.__setitem__(s, os.path.join(sl, fn)) for s in o.pubdefs]
        except: pass
rf, rs, ur = set(), set(defined), set(needed)
for _ in range(30):
    nf = set()
    for sym in list(ur):
        if sym in index:
            fp = index[sym]
            if fp not in rf: nf.add(fp); rf.add(fp); o = OMFObj(fp); rs.update(o.pubdefs); ur.update(o.extdefs)
    ur -= rs
    if not nf: break
for sym in ['FPC_MSDOS_CARRY','FPC_CHECK_NULLAREA','FPC_INSTALL_INTERRUPT_HANDLERS','FPC_RESTORE_INTERRUPT_HANDLERS','__Test8086','__SaveInt00']:
    for fn in sorted(os.listdir(os.path.join(units, 'system.sl'))):
        if fn.endswith('.o'):
            fp = os.path.join(units, 'system.sl', fn)
            if sym.encode() in open(fp,'rb').read() and fp not in rf: rf.add(fp)
for fn in ['objpas0s22.o','objpas0s24.o']:
    fp = os.path.join(units, 'objpas.sl', fn)
    if os.path.exists(fp): rf.add(fp)
with open(f'{work}/link.res', 'w') as f:
    f.write('option quiet\nformat dos\noption stack=4096\n')
    f.write(f'name {work}/netfossl.exe\n')
    f.write(f'file {units}/prt0s.o\nfile {work}/netmodem.o\nfile {work}/fossil_dos.o\nfile {work}/fpcheap.o\nfile {work}/stubs.o\n')
    for fp in sorted(rf): f.write(f'file {fp}\n')
    f.write(f'library {libs}\nlibrary /opt/watcom/lib286/dos/clibl.lib\nlibrary /opt/watcom/lib286/dos/emu87.lib\n')
print(f"  {len(rf)} deps")
PYEOF

echo "[4/5] Link"
"$WLINK" @"$WORK/link.res" 2>&1 | grep -v "W1027\|W1008\|^$"

echo "[5/5] Output"
if [ -f "$WORK/netfossl.exe" ]; then
    mkdir -p bin
    cp "$WORK/netfossl.exe" bin/netfossl.exe
    SIZE=$(stat -c%s bin/netfossl.exe 2>/dev/null || stat -f%z bin/netfossl.exe)
    echo "  bin/netfossl.exe — $SIZE bytes"
else
    echo "  BUILD FAILED"
    exit 1
fi
