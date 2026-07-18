# FPC i8086-msdos Sockets — Feature Request

## Status
Pending submission to FPC GitLab + mailing list.

## GitLab Issue

**Title:** i8086-msdos: sockets unit has no TCP/IP backend

The sockets unit compiles for the i8086-msdos target (FPC 3.0.4 cross-compiler) and produces a valid PPU, but the BSD socket calls (fpSocket, fpConnect, fpSend, fpRecv, fpClose, TInetSockAddr) have no backend implementation. They're stubs that only work on Unix/Linux targets.

I'm building a DOS BBS tool (FOSSIL-to-TCP bridge) that needs real TCP/IP from a 16-bit DOS binary. The cross-compiler and 20 RTL units are working — sockets is the missing piece.

Watt-32 (http://www.watt-32.net/) is the standard DOS TCP/IP library and seems like the natural backend. It provides a BSD-compatible socket API over packet drivers and already supports Watcom/DJGPP/etc.

What I have working:
- i8086-msdos cross-compiler (ppcross8086) on Linux
- 20 PPUs: system, dos, crt, strings, sysutils, sockets (stub), etc.
- Build pipeline: ppcross8086 → nasm → wlink → .exe
- Successfully linking 32KB DOS executables

What's needed:
- fpSocket, fpConnect, fpBind, fpListen, fpAccept, fpSend, fpRecv, fpClose
- TInetSockAddr / sockaddr_in equivalent
- Backend via Watt-32, or packet driver INT, or any workable approach

I can test any patches on real hardware and DOSBox. Happy to contribute.

Repo with cross-compiler and units: https://github.com/verta1878/fpc264irc

## Mailing List Post

**To:** fpc-devel@lists.freepascal.org
**Subject:** i8086-msdos sockets — any path to real TCP/IP?

Hi all,

I have a working i8086-msdos cross-compiler (FPC 3.0.4) with 20 RTL units including sockets.ppu. The unit compiles fine but the BSD socket calls have no DOS backend — they're Unix/Linux only.

I'm building a DOS FOSSIL-to-TCP bridge (single 16-bit .exe) and need fpSocket/fpConnect/fpSend/fpRecv working on real DOS. Watt-32 seems like the natural backend since it provides BSD-compatible sockets over packet drivers.

Is anyone working on this, or is there a recommended approach? I have a full build pipeline (ppcross8086 → nasm → wlink) producing working DOS executables and I'm happy to test or contribute.

Repo: https://github.com/verta1878/fpc264irc

Thanks,
Antonio

## Links
- FPC GitLab: https://gitlab.com/freepascal.org/fpc/source/-/issues
- FPC mailing list: fpc-devel@lists.freepascal.org
- Watt-32: http://www.watt-32.net/
