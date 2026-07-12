# Config wiring (NM_Config) — per-node comport/host/port, deployable setup

Turns netmodem2irc from "constructed in code" into "configured and deployable."

## Format (simple, BBS-era INI-like)
    node <index> <host> <port>
e.g.
    ; my board
    node 3 bbs.example.com 23
    node 4 chat.example.org 6667
Blank lines and lines starting with ';' or '#' are comments.

## What it does
- TNetModemConfig parses config text/lines into per-node entries
  (TNodeConfig: NodeIndex, Host, Port).
- Each field is RANGE-CHECKED on load (structural-sight discipline — a config
  value is untrusted input crossing a boundary, like a wire value):
    * node index: 0 .. NM_MAX_NODES-1 (0..98)
    * port:       1 .. 65535
    * host:       non-empty
- Bad lines are REPORTED (Errors), never silently accepted. IsValid is true only
  if every line parsed cleanly.
- Redefining a node updates it (last wins), no duplicates.

## Verified (test_config, 28/28) — boundary discipline
- node index: 0 and 98 accepted; 99 (== NM_MAX_NODES) and -1 REJECTED.
- port: 1 and 65535 accepted; 0 and 65536 (past Word) REJECTED.
- malformed lines (too few/many fields, non-numeric index/port, unknown keyword)
  all rejected AND recorded as errors, not swallowed.
- comments/blanks ignored; multi-line ParseText; last-wins update.
Full suite: 25 tests, 0 failures (FPC 2.6.4 + 3.2.2).

## Where it fits
This is the last big buildable-now server-side piece: it's how a deployment says
"node 3 is COM3, talks to bbs.example.com:23." The server would load a config and
AddNode(idx, link-to(host,port)) per entry; the TSR side reads its own node's
host/port the same way. Wiring config into the actual server/TSR construction is a
small follow-up (it just feeds the already-tested constructors).

---

## Config APPLIED to the server (NM_ConfigApply) — the loose end closed

NM_Config parses+validates; NM_ConfigApply is the thin glue that brings the
configured nodes UP on a TServerBridge, so "load a config -> nodes come up" is a
real, tested path. Kept as its own single-purpose unit (config parses, bridge
runs, applier connects them).

ApplyConfig(cfg, bridge) -> TApplyResult(Brought, Skipped):
- Refuses to apply an INVALID config (IsValid = false) — never half-configures
  from broken input.
- For each configured node, brings it up via the bridge; counts Brought vs
  Skipped. HONEST about the stub build: with no transport backend compiled in
  (HAS_SYNAPSE off), MakeLink returns nil and nodes are counted SKIPPED, not
  falsely reported up. With -dHAS_SYNAPSE the same nodes come up.

### Verified (test_config_apply, 7/7)
- valid config -> all configured nodes accounted for (brought + skipped, none lost).
- INVALID config -> applies NOTHING (0 brought, 0 skipped).
- empty config and nil args -> safe, 0/0.
Full suite: 26 tests, 0 failures (FPC 2.6.4 + 3.2.2).

The config story is now complete end to end: text -> parse -> validate -> apply ->
nodes, every step tested.
