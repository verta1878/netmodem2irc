# netfosol — OS/2 FOSSIL Driver

OS/2 native FOSSIL driver for netmodem2irc.
Uses DosDevIOCtl for serial I/O, so32dll for sockets.

See also: evga's SIO2K rebuild (separate package, GPLv3).

## Status
Phase O1-O10 planned. See docs/OS2_PORT_PLAN.md.

## Files (planned)
- netfosol.pas — main driver
- async_os2.pas — OS/2 ASYNC implementation (DosDevIOCtl)
- Uses fossil/common/m_fossil_socket.pas for socket backend
