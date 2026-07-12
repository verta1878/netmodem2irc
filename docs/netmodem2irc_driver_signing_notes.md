# Driver signing — where it does and doesn't apply to netmodem2irc

Analysis of self-signing unsigned drivers (per woshub.com guide) and how it maps
onto our architecture. Short version: our primary FOSSIL-TSR path does NOT need
Windows driver signing at all.

## The self-signing method (from the guide)
Create a self-signed code-signing cert -> add to Trusted Root + Trusted Publisher
-> build a .cat catalog (inf2cat) -> sign with signtool. Tools: Windows SDK
(signtool) + WDK (inf2cat).

## THE CRITICAL DISTINCTION (from the guide + its comments)
Self-signing works for **user-mode** drivers but effectively **FAILS for
kernel-mode** drivers on 64-bit Windows:
- User-mode drivers (printers/scanners/UMDF): self-signing works, even with
  Secure Boot.
- Kernel-mode (.sys): installs without warning but WON'T LOAD. At boot the kernel
  can't read the trusted-cert store; it uses certs baked into the kernel. Result:
  "cannot verify digital signature" / Code 52. Confirmed repeatedly in comments.
- Kernel-mode on x64 requires Microsoft WHQL certification (paid), OR globally
  disabling enforcement via `bcdedit /set testsigning on` (Test Mode).

## How this maps to netmodem2irc's architecture
### FOSSIL TSR (our PRIMARY path) — signing does NOT apply
Our FOSSIL driver is a **16-bit real-mode DOS TSR** running INSIDE a DOS VM
(ntvdmx64 / DOSBox-X / vDos). It is NOT a Windows .sys driver. Windows'
driver-signing enforcement does not apply to it — Windows doesn't see it as a
driver; the VM hosts it. So the whole signing problem is IRRELEVANT to our main
path. This is a point in favor of the FOSSIL-TSR approach over a Windows driver.

### The signing problem belongs to ntvdmx64, not us
ntvdmx64 is the component that must get itself onto 64-bit Windows, and it uses a
non-standard INJECTOR precisely because the clean self-signing path (this guide)
does NOT work for its kind of low-level code. This guide essentially documents the
wall that forced ntvdmx64 to use injection. Self-signing and the injector are two
attempts at the same locked door; self-signing fails for deep-system code, which
is why the injector exists.

### Option A UMDF virtual-COM driver (the OPTIONAL frontier) — signing WOULD apply
IF we ever build the Option A user-mode (UMDF) virtual-COM driver, THAT is a real
Windows user-mode driver, and self-signing per this guide CAN work for it (user-
mode is the case that succeeds). But note the downsides the comments flag:
- Test Mode watermark + globally weakened security if testsigning is used.
- Some anti-cheat / software refuses to run under test-signing mode.
- A self-signed cert must be added to Trusted Root + Trusted Publisher on each
  target machine (or deployed via GPO).
Since Option A is optional and the FOSSIL-TSR path avoids signing entirely, the
FOSSIL path remains preferred.

## Bottom line
- FOSSIL TSR (primary): NO Windows signing needed (runs in the VM). ✓
- ntvdmx64 (runtime): has its own signing problem, solved by its injector (why it
  exists); this is the leaked-source / injector caveat we already noted.
- Option A UMDF driver (optional): user-mode, so self-signing CAN work, with the
  Test-Mode / anti-cheat downsides. Not required.
