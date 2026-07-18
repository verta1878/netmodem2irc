#!/bin/sh
# netmodem2irc — full project build
# Usage: ./build.sh [tests|resources|win32|fossil|clean|all]
#        FPCIRC=/path/to/fpc264irc ./build.sh
# Requires: fpc264irc r3.1+
#           i686-w64-mingw32-windres (for icon resources)
set -e
cd "$(dirname "$0")"
TARGET="${1:-all}"
FPCIRC="${FPCIRC:-$HOME/fpc264irc}"
FPC="${FPC:-fpc}"
WINDRES="${WINDRES:-i686-w64-mingw32-windres}"

build_resources() {
    echo "=== Resources (icons) ==="
    if command -v "$WINDRES" >/dev/null 2>&1; then
        (cd server/resources && $WINDRES --preprocessor=cat NMServer.rc -o ../NMServer.res) 2>&1
        (cd config/resources && $WINDRES --preprocessor=cat NMConfig.rc -o ../NMConfig.res) 2>&1
        echo "  NMServer.res — $(ls -l server/NMServer.res 2>/dev/null | awk '{print $5}') bytes"
        echo "  NMConfig.res — $(ls -l config/NMConfig.res 2>/dev/null | awk '{print $5}') bytes"
    else
        echo "  SKIP (needs i686-w64-mingw32-windres)"
        echo "  Install: apt install binutils-mingw-w64-i686"
    fi
}

run_tests() {
    echo "=== Engine Tests ==="
    cd engine && sh test/run-tests.sh && cd ..
}

build_win32() {
    echo "=== Win32 Cross-Compile (fpc264irc r3.1+) ==="
    if [ ! -d "$FPCIRC" ]; then
        echo "  ERROR: FPCIRC=$FPCIRC not found"
        echo "  Set FPCIRC=/path/to/fpc264irc or clone github.com/verta1878/fpc264irc"
        return 1
    fi

    W32FPC="$FPCIRC/bin/ppc386"
    W32TOOLS="$FPCIRC/bin/tools/i386-win32"
    W32RTL="$FPCIRC/bin/units/i386-win32"
    W32LAZUTILS="$FPCIRC/bin/lazarus/units/i386-win32/lazutils"
    W32LCL="$FPCIRC/src/lazarus/lcl"
    W32LCLOUT="$FPCIRC/bin/lazarus/units/i386-win32/lcl/win32"
    W32FCLIMG="$FPCIRC/src/packages/fcl-image/src"
    W32FCLBASE="$FPCIRC/src/packages/fcl-base/src"
    W32WINUNITS="$FPCIRC/src/packages/winunits-base/src"

    chmod +x "$W32FPC" "$W32TOOLS"/* 2>/dev/null

    # Fix PPU timestamps (git clone sets source newer than PPUs)
    find "$FPCIRC/bin/units" "$FPCIRC/bin/lazarus/units" \
        \( -name "*.ppu" -o -name "*.o" \) -exec touch {} + 2>/dev/null

    mkdir -p out/win32

    # Build resources
    build_resources

    echo "--- NMServer.exe ---"
    $W32FPC -Twin32 -Mobjfpc \
        -Fu"$(pwd)/engine" -Fu"$(pwd)/common" -Fu"$(pwd)/libs/synapse" \
        -Fu"$W32RTL" -Fu"$W32LAZUTILS" -Fu"$W32LCLOUT" \
        -Fu"$W32LCL" -Fu"$W32LCL/widgetset" -Fu"$W32LCL/units/i386-win32" \
        -Fu"$W32FCLIMG" -Fu"$W32FCLBASE" -Fu"$W32WINUNITS" \
        -Fi"$W32LCL" -Fi"$W32LCL/include" \
        -FD"$W32TOOLS" \
        -FEout/win32 \
        server/NMServer.lpr 2>&1 | tail -3
    [ -f out/win32/NMServer.exe ] && echo "  NMServer.exe — $(ls -lh out/win32/NMServer.exe | awk '{print $5}')" || echo "  NMServer.exe — FAILED"

    echo "--- NMConfig.exe ---"
    $W32FPC -Twin32 -Mobjfpc \
        -Fu"$(pwd)/engine" -Fu"$(pwd)/common" \
        -Fu"$W32RTL" -Fu"$W32LAZUTILS" -Fu"$W32LCLOUT" \
        -Fu"$W32LCL" -Fu"$W32LCL/widgetset" -Fu"$W32LCL/units/i386-win32" \
        -Fu"$W32FCLIMG" -Fu"$W32FCLBASE" -Fu"$W32WINUNITS" \
        -Fi"$W32LCL" -Fi"$W32LCL/include" \
        -FD"$W32TOOLS" \
        -FEout/win32 \
        config/NMConfig.lpr 2>&1 | tail -3
    [ -f out/win32/NMConfig.exe ] && echo "  NMConfig.exe — $(ls -lh out/win32/NMConfig.exe | awk '{print $5}')" || echo "  NMConfig.exe — FAILED"

    echo "--- NETMODEM.CPL (original Dedrick Allen binary) ---"
    cp history/NETMODEM.CPL out/win32/
    echo "  NETMODEM.CPL — $(ls -lh out/win32/NETMODEM.CPL | awk '{print $5}')"
}

build_fossil() {
    echo "=== FOSSIL (netfossl.exe) ==="
    cd dos && sh build.sh && cd ..
}

build_clean() {
    echo "=== Cleaning build artifacts ==="
    find . -not -path './.git/*' -not -path './dos/bin/*' \
        \( -name "*.o" -o -name "*.ppu" -o -name "*.or" \
        -o -name "*.s" -o -name "*.rst" -o -name "ppas.sh" \
        -o -name "*.bak" -o -name "link.res" -o -name "*.res" \) \
        -type f -delete 2>/dev/null || true
    rm -rf out/
    echo "  done"
}

case "$TARGET" in
    tests)     run_tests ;;
    resources) build_resources ;;
    win32)     build_win32 ;;
    fossil)    build_fossil ;;
    clean)     build_clean ;;
    all)       run_tests; echo; build_win32; echo; build_fossil ;;
    *)         echo "Usage: $0 [tests|resources|win32|fossil|clean|all]"; exit 1 ;;
esac

echo
echo "=== Build complete ==="
