#!/bin/sh
# netmodem2irc — full project build
# Usage: ./build.sh [tests|server|config|dos|all]
#        FPCIRC=/path/to/fpc264irc ./build.sh
set -e
cd "$(dirname "$0")"
TARGET="${1:-all}"
FPC="${FPC:-fpc}"

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
        echo "  NMServer — OK"
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
        echo "  NMConfig — OK"
    else
        echo "  NMConfig — SKIP (needs Lazarus LCL)"
    fi
}

build_dos() {
    echo "=== DOS netfossl.exe ==="
    cd dos && sh build.sh && cd ..
}

case "$TARGET" in
    tests)  run_tests ;;
    server) build_server ;;
    config) build_config ;;
    dos)    build_dos ;;
    all)    run_tests; echo; build_server; echo; build_config; echo; build_dos ;;
    *)      echo "Usage: $0 [tests|server|config|dos|all]"; exit 1 ;;
esac

echo
echo "=== Build complete ==="
