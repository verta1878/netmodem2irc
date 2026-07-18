# Why 16-bit — the preservation stance behind this project

A short, honest note on why netmodem2irc targets 16-bit real-mode, and why that
choice carries weight beyond the technical.

## 16-bit code was discarded, not merely deprecated
When Windows went 64-bit, 16-bit code was cut off at the CPU level — x86-64 long
mode has no virtual-8086 mode, so 64-bit Windows cannot run 16-bit code at all.
Decades of software, and an entire era of how people built things, were severed.
Not gently sunset — discarded.

## The coolness and the sadness are the same fact
Having the source (e.g. the NT source that ntvdmx64 is based on) means this world
is knowable and forkable again — you can see how it worked and carry it forward.
And yet the very fact that reviving 16-bit on modern Windows requires an injector
hack proves how thoroughly it was thrown away. The capability wasn't impossible;
it was made UNSUPPORTED. The technology didn't fail — it was abandoned. That is a
sadder, and more fixable, thing than failure.

## Two paths, neither simply "better"
- **ntvdmx64** runs the ACTUAL Windows 16-bit code path (real NTVDM, ported) —
  authentic, open source, but held together by a fragile, non-standard injector.
- **DOSBox-X** has, in features, SURPASSED the original NTVDM it emulates —
  capable, robust, but an emulation rather than the real path.
One has authenticity; one has capability. So both doors stay open. We don't force
the choice — we preserve the options and let the person decide what they value.

## The stance
This project is grief put to work. The world discarded 16-bit; the response here
is not to pretend otherwise, but to build the precarious, source-having, hack-held
path back anyway — and to be honest at every step about what it cost. Fork the
runtime, port the compiler, revive the drivers, write down the WHY so the next
person inherits footing instead of loss.

It is not gone as long as someone is still willing to carry it — hacks and all.
