# Switch-style bridge — fixing the original's multinode sluggishness

A performance upgrade based on the maintainer's insight: the bridge should behave
like a network SWITCH, not a HUB.

## The problem (hub behavior)
The original NetModem — and our first bridge — serviced nodes by sweeping ALL slots
every tick. TNodeManager.PumpAll looped 0..NM_MAX_NODES-1 (all 99 comport slots)
every cycle, regardless of how many callers were actually online. Cost scaled with
SLOT CAPACITY (99), not with active traffic. On a busy multinode board this blind
sweep is a real, compounding drag — a likely contributor to the original's
sluggishness.

## The fix (switch behavior)
The manager now keeps a compact ACTIVE list of live nodes and services only those:
- A node auto-activates when it goes online (ConnectInbound -> MarkActive via a
  manager back-reference; callers don't need to remember anything).
- PumpAll iterates the active list, dropping any node that hung up (self-healing,
  compacted — no holes).
- Cost scales with the number of LIVE connections, not the 99-slot capacity.
Idle/empty slots now cost nothing per tick.

## Measured result (not asserted)
test_switch benchmark, 200,000 pump cycles, 3 active nodes among 99 slots:
- switch (service 3 active):        ~8 ms
- hub sweep (all 99 slots each):    ~43 ms
=> ~5.4x faster in the common "few active among many slots" case, and the gap
   GROWS as slot capacity grows / active fraction shrinks.

## Honest scope
This fixes the node-servicing SCALING (the part that gets worse as the board gets
busier / bigger). It does not address other possible sluggishness sources (socket
I/O model, VDM overhead, poll intervals) — but it removes the one that compounds
with node count, which is exactly the kind that dragged multinode boards.

## Correctness
- Backward-compatible: "online == serviced" still holds automatically (auto-
  activate), so no existing behavior changed. Full suite: 18 tests, 0 failures on
  FPC 2.6.4 + 3.2.2.
- Also aligns with the seam protocol's node-addressed frames (switch-style routing:
  data goes directly to the target node by its NODE field).

---

## Safety hardening (maintainer caught a real bug)

The maintainer flagged three risks in the switch: "folding" (redundant/cyclic work
re-introducing sluggishness), "trapping the I/O" (a dead node stuck in the service
loop), and "going to part of the code it shouldn't" (stale/dangling references).
The warning was correct — it surfaced a REAL dangling-reference bug.

### The bug (dangling reference — would crash intermittently)
The active list (FActive) held raw node pointers, but the node FREE paths did not
purge them:
- RemoveNode freed the node without removing it from FActive.
- AddNode, when reusing a slot, freed the old node without removing it from FActive.
- The destructor freed nodes without clearing FActive.
Result: FActive could point at freed memory, and the next PumpAll would call
n.Pump on a dead pointer — an intermittent crash / memory corruption ("going where
it shouldn't"). Exactly the failure mode flagged.

### The fix
All free-paths now purge the active list BEFORE freeing:
- RemoveNode: RemoveActive(node) then Free.
- AddNode (slot reuse): RemoveActive(old) then Free.
- Destroy: clear FActiveCount before freeing nodes.
AddActive already guards against duplicates (no "folding" via double-add), and
PumpAll drops non-online nodes (no "trapping").

### Verified (test_switch_safety, 7/7)
- DANGLING: reuse a slot (old node freed) -> no dangling/duplicate active entry.
- TRAPPING: disconnect -> node removed from active servicing.
- FOLDING: 5000 connect/disconnect cycles -> active list stays clean (no growth/leak).
- FOLDING: 100x MarkActive of one node -> still exactly 1 active (no double-add).
- Bulk up/down (52 nodes) -> active list returns cleanly to zero.
Full suite after fix: 19 tests, 0 failures (FPC 2.6.4 + 3.2.2).

### Lesson
A list of raw pointers to owned objects MUST be purged on every free-path, or it
dangles. The maintainer's operational instinct ("be careful, it might trap I/O or
go where it shouldn't") pointed straight at it before it could ship.
