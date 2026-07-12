#!/bin/sh
# netmodem2irc — NT-branch emulation + transport + AT test suite
# All tests are pure/fake-socket — no network needed. Runs anywhere FPC does.
# Usage:  sh test/run-tests.sh   |   FPC=/path/to/ppcXXX sh test/run-tests.sh
cd "$(dirname "$0")/.."
FPC="${FPC:-fpc}"
SRC="$(pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "=== compiling units ==="
for u in NM_UART16550 NM_Fossil NetTransport NM_ATCommand NM_Node NM_NamedPipeLink NM_ServerBridge; do
  $FPC -Mobjfpc -vw -Fu"$SRC" -FE"$OUT" "$SRC/$u.pas" >/dev/null 2>&1 \
    && echo "  $u: OK" || { echo "  $u: COMPILE FAIL"; exit 1; }
done

echo "=== running tests ==="
fails=0
for t in test_uart test_fossil test_transport test_atcommand test_synapse_stub test_node test_pipelink test_pipe_transport test_bridge test_bridge_io test_m1_complete; do
  $FPC -Mobjfpc -vw -Fu"$SRC" -Fu"$OUT" -FE"$OUT" "$SRC/test/$t.pas" >/dev/null 2>&1
  if "$OUT/$t" 2>/dev/null | tail -1 | grep -q VERIFIED; then
    echo "  $t: PASS"
  else
    echo "  $t: FAIL"; fails=$((fails+1))
  fi
done
echo "=== done: $fails failure(s) ==="
exit $fails
