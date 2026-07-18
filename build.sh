#!/bin/sh
# netmodem2irc — full project build
# Usage: ./build.sh [tests|server|config|cpl|fossil|resources|all]
#        FPCIRC=/path/to/fpc264irc ./build.sh
# Requires: fpc264irc r6.0+
#           i686-w64-mingw32-windres (for icon resources)
set -e
cd "$(dirname "$0")"
TARGET="${1:-all}"
FPC="${FPC:-fpc}"
WINDRES="${WINDRES:-i686-w64-mingw32-windres}"

build_resources() {
    echo "=== Resources (icons) ==="
    if command -v "$WINDRES" >/dev/null 2>&1; then
        (cd server/resources && $WINDRES --preprocessor=cat NMServer.rc -o ../NMServer.res) 2>&1
        (cd config/resources && $WINDRES --preprocessor=cat NMConfig.rc -o ../NMConfig.res) 2>&1
        (cd cpl/resources && $WINDRES --preprocessor=cat NetModemCPL.rc -o ../NetModemCPL.res) 2>&1
        echo "  NMServer.res — $(ls -l server/NMServer.res 2>/dev/null | awk '{print $5}') bytes"
        echo "  NMConfig.res — $(ls -l config/NMConfig.res 2>/dev/null | awk '{print $5}') bytes"
        echo "  NetModemCPL.res — $(ls -l cpl/NetModemCPL.res 2>/dev/null | awk '{print $5}') bytes"
    else
        echo "  SKIP (needs i686-w64-mingw32-windres)"
        echo "  Install: apt install binutils-mingw-w64-i686"
    fi
}

run_tests() {
    echo "=== Engine Tests ==="
    cd engine && sh test/run-tests.sh && cd ..
}

build_server() {
    echo "=== Server (NMServer) ==="
    OUT="$(pwd)/out"
    mkdir -p "$OUT"
    $FPC -Mobjfpc -Fu"$(pwd)/engine" -Fu"$(pwd)/common" -Fu"$(pwd)/libs/synapse" \
        -FE"$OUT" server/NMServer.lpr 2>&1 | tail -3
    if [ -f "$OUT/NMServer" ] || [ -f "$OUT/NMServer.exe" ]; then
        echo "  NMServer — $(ls -lh $OUT/NMServer.exe 2>/dev/null || ls -lh $OUT/NMServer 2>/dev/null | awk '{print $5}')"
    else
        echo "  NMServer — SKIP (needs Lazarus LCL)"
    fi
}

build_config() {
    echo "=== Config (NMConfig) ==="
    OUT="$(pwd)/out"
    mkdir -p "$OUT"
    $FPC -Mobjfpc -Fu"$(pwd)/engine" -Fu"$(pwd)/common" \
        -FE"$OUT" config/NMConfig.lpr 2>&1 | tail -3
    if [ -f "$OUT/NMConfig" ] || [ -f "$OUT/NMConfig.exe" ]; then
        echo "  NMConfig — $(ls -lh $OUT/NMConfig.exe 2>/dev/null || ls -lh $OUT/NMConfig 2>/dev/null | awk '{print $5}')"
    else
        echo "  NMConfig — SKIP (needs Lazarus LCL)"
    fi
}

build_cpl() {
    echo "=== CPL (NetModemCPL) ==="
    OUT="$(pwd)/out"
    mkdir -p "$OUT"
    $FPC -Mobjfpc -Fu"$(pwd)/engine" -Fu"$(pwd)/common" \
        -FE"$OUT" cpl/NetModemCPL.pas 2>&1 | tail -3
    if [ -f "$OUT/NetModemCPL.dll" ]; then
        cp "$OUT/NetModemCPL.dll" "$OUT/NetModemCPL.cpl"
        echo "  NetModemCPL.cpl — $(ls -lh $OUT/NetModemCPL.cpl | awk '{print $5}')"
    else
        echo "  NetModemCPL — SKIP (needs Windows target)"
    fi
}

build_fossil() {
    echo "=== FOSSIL (netfossl.exe) ==="
    cd dos && sh build.sh && cd ..
}

case "$TARGET" in
    tests)     run_tests ;;
    resources) build_resources ;;
    server)    build_resources; build_server ;;
    config)    build_resources; build_config ;;
    cpl)       build_resources; build_cpl ;;
    fossil)    build_fossil ;;
    all)       run_tests; echo; build_resources; echo; build_server; echo; build_config; echo; build_cpl; echo; build_fossil ;;
    *)         echo "Usage: $0 [tests|server|config|cpl|fossil|resources|all]"; exit 1 ;;
esac

echo
echo "=== Build complete ==="
