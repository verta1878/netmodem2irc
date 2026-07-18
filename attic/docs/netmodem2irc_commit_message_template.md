# netmodem2irc — commit message template (GitHub Desktop)

A consistent format so the git history is readable at a glance. Summary line +
a description grouped into Add / Fix / Change. Keep the summary under ~72 chars.

## The shape

SUMMARY (required, one line, imperative, under ~72 chars):
    <verb> <what> — <short why/scope>

DESCRIPTION (grouped; only include the groups that apply):
    Add:    new files, units, features, tests, docs
    Fix:    bugs corrected, gaps closed, regressions repaired
    Change: renames, refactors, behavior changes, decisions, doc updates

    <test status line>
    <attribution line if relevant>

## Rules of thumb
- Summary starts with a verb: Add / Fix / Change / Update / Audit / Document.
- One logical change per commit where possible (easier to read + revert).
- Under each group, one bullet per item, plainest words.
- Always end with the test status ("N tests, 0 failures on FPC 2.6.4 + 3.2.2")
  so history shows the suite stayed green.
- Keep the NetModem attribution line when the change touches core/driver.
- Say the WHY, not just the what, when the why isn't obvious (the decision, the
  bug's cause) — future-you reads these.

## Fill-in template (copy/paste)

    <verb> <what> — <scope>

    Add:
    - <new unit/feature/test/doc>
    Fix:
    - <bug/gap>: <what was wrong> -> <what now>
    Change:
    - <rename/refactor/decision/doc update>

    N tests, 0 failures on FPC 2.6.4 and 3.2.2.
    Original NetModem/32 (c) Dedrick Allen (mag69), GPLv2 — attribution preserved.

## Worked examples

### Example — a bug fix
    Fix FOSSIL Fn 06h DTR to handle both directions

    Fix:
    - Fn 06h SET_DTR only lowered DTR; raise (AL=1) did nothing. ELECOM's stateful
      Com_SetDtr revealed the gap. Now handles both; DTR in MCR bit; raise = ready
      without fabricating carrier.

    27 tests, 0 failures on FPC 2.6.4 and 3.2.2.

### Example — a new feature
    Add block I/O (FOSSIL Fn 18h/19h) for high-throughput doors

    Add:
    - Fn 18h/19h READ_BLOCK/WRITE_BLOCK via a Buf pointer (host analog of ES:DI),
      non-blocking, honest returned count, bounds-safe.
    - test_fossil_block (10/10), boundary-disciplined.

    28 tests, 0 failures on FPC 2.6.4 and 3.2.2.

### Example — a decision / change
    Change config format to canonical text file

    Change:
    - Standardized on a plain text config (node <index> <host> <port>), parsed by
      NM_Config. Chosen over the registry: avoids newer-Windows access-flag/ACL
      complexity; identical from NT4 onward. Registry mirroring may come later.

    33 tests, 0 failures on FPC 2.6.4 and 3.2.2.

### Example — mixed
    Add i8086 TSR scaffolds; document NT4 build

    Add:
    - NM_Int14ISR, NM_TSRResident (design-stage, DOS_TARGET-guarded, host-compile).
    - Docs: i8086 finish guide, CPL design, M2/NT4 build runbook.
    Change:
    - TNetModemNode exposes UartPtr (ISR needs the resident UART by pointer).

    33 tests, 0 failures on FPC 2.6.4 and 3.2.2.
    Original NetModem/32 (c) Dedrick Allen (mag69), GPLv2 — attribution preserved.
