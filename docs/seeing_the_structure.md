# Seeing the structure — the method behind the audits

The discipline this project applies whenever it touches unfamiliar code.
Referenced by `CREDITS.md`, `netmodem2irc_overflow_audit.md`, and
`testing_the_boundary.md` as "the lesson."

## The lesson

**Read the structure before you read the logic.** A unit's meaning is
not in its individual lines but in how its pieces connect — what calls
what, what owns what, what can fail and what handles the failure. If
you understand the structure, the bugs announce themselves. If you read
line by line, you see only what the author saw.

This is why the audits in this project are called "structural-sight
audits" rather than code reviews. They are not looking for style
violations or naming issues. They are looking for **structural
ghosts**: places where the code's shape doesn't match the problem's
shape.

## What a structural-sight audit does

1. **Map the data flow.** Not the control flow — the data. Where do
   bytes enter, where do they exit, and what transforms them in
   between? Draw the path.

2. **Find the boundaries.** Every place where data crosses from one
   owner to another — a function call, a buffer copy, a protocol
   transition — is a boundary. Bugs live at boundaries because both
   sides make assumptions about the other.

3. **Check each boundary for assumption mismatches.** The sender
   assumes the receiver will handle X bytes. The receiver assumes it
   will never get more than Y. If X > Y, you have a bug, even if it
   has never triggered. That is the ghost.

4. **Name the ghost, then prove it.** Don't fix an assumption mismatch
   by inspection alone. Write a test that puts data across the boundary
   at the size that would trigger the mismatch. If the test passes, the
   ghost was not real. If it fails, you have a finding.

## What this method has found in this project

| Audit | Ghost | Real? |
|---|---|---|
| `netmodem2irc_overflow_audit.md` | Seam LEN field overflow at the 256-byte boundary | Yes — found and fixed |
| `netmodem2irc_transport_audit.md` | Outbound IAC-doubling missing | Yes — found and fixed |
| `netmodem2irc_at_ghost_audit.md` | AT command buffer overflow | No — the ghost was not real |
| `netmodem2irc_link_audit.md` | Named-pipe link boundary | Clean |
| `netmodem2irc_boundary_audit_full.md` | Full seam/switch path | Clean |
| `testing_the_boundary.md` | Method: proving a fix without the real condition | Applied to `NM_SynapseLink` tail buffer |

## Why it matters for this project specifically

NetModem/32 is a **protocol bridge**: it stands between a DOS BBS
speaking FOSSIL over a UART and a TCP socket speaking Telnet. Every
byte crosses at least three boundaries — FOSSIL dispatch to UART
emulation, UART rings to transport, transport to socket — and each
boundary was written by a different author in a different decade for a
different platform.

Line-by-line review would not have found the seam LEN overflow. The
code that writes the length and the code that reads it are in different
units, written months apart. Only mapping the data flow from sender to
receiver, across the boundary, made the mismatch visible.

## The rule

When you open a unit you have not read before:

1. Find the data path first.
2. Find the boundaries second.
3. Read the logic third.

The logic is the least important part. The structure is the thing that
is either right or wrong.
