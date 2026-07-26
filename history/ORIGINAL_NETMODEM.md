# NetModem/32 — original release facts (from Dedrick Allen's FILE_ID.DIZ)

Preserved from the original NetModem/32 v2.0 alpha3 archive (nm32_2a3.zip).
This is Dedrick Allen's own description — footing for the revival.

## Release facts (verbatim source: history/FILE_ID.DIZ)
- Product: NetModem/32 v2.0 alpha3
- "32Bit FOSSIL Telnet Server for Windows 95/98"
- Released: 5/28/00 (May 28, 2000)
- Author: Dedrick Allen — http://www.allensoftware.com

## What the original DID (drives our revival requirements)
- **MULTINODE**: "!! Multinode versions are now available !!" — the original
  supported MULTIPLE simultaneous connections. Our revival MUST keep this:
  build per-node objects, hold N of them. Not a new feature — a preserved one.
- **Comports 3-99**: up to 97 virtual comports/nodes.
- **Baud rates**: 19200, 38400, 57600, 115200.
- Accepts incoming Telnet connections to any BBS/comm software that can use a
  FOSSIL driver.
- Uses Windows WinSock TCP/IP; works over dial-up, cable, ethernet, any TCP/IP.
- "Emulates a modem via FOSSIL services" — exactly Layer A in our DRIVER_MAP.

## What was "coming soon" in 2000 (we are completing it)
- **"Dial-Out coming soon"** — alpha3 was INBOUND only. Our AT-command layer
  (NM_ATCommand: ATDT<host> -> TCP connect) implements the dial-OUT feature
  Dedrick planned but hadn't shipped. The revival completes his roadmap.

## Design implication for netmodem2irc
The emulation units are already multi-instance-safe (all state is passed in,
no globals). The node object (NM_Node) is per-connection; the server holds an
array of nodes (ComportStruct has Max_Nodes). Single connection works now;
multi-node is "instantiate more" — honoring the original's multinode design.
