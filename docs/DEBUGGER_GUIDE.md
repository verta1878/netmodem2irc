# NMServer Debugger — Plain English Guide

## What You're Looking At

The debugger shows you what's happening inside the virtual modem
in real time. Three panels: Data Stream, Modem Status, Events.

## Data Stream Panel

Shows bytes flowing between the caller and the BBS.

```
12:34:56  CALLER → BBS   "Hello sysop!"
12:34:57  BBS → CALLER   "Welcome to Ecstasy BBS!"
12:34:58  CALLER → BBS   [Zmodem download starting]
12:34:59  BBS → CALLER   [Sending file: GAME.ZIP (245 KB)]
```

### Direction Arrows

| Arrow | Meaning |
|-------|---------|
| CALLER → BBS | The person calling in is sending data to your BBS |
| BBS → CALLER | Your BBS is sending data back to the caller |

### Data Types (auto-detected)

| What You See | What It Means |
|-------------|---------------|
| "Hello sysop!" | Plain text — the caller is typing |
| [Zmodem starting] | A file transfer is beginning |
| [ANSI color code] | The BBS is sending colored text |
| [Telnet handshake] | The connection is being set up (normal) |
| [IAC escaped] | A special byte ($FF) was safely doubled (normal) |

## Modem Status Panel

Shows the state of the virtual modem — like the lights on a
real external modem.

```
CARRIER:  ● ON     (caller is connected)
RING:     ○ OFF    (no incoming call right now)
READY:    ● ON     (modem is ready to send/receive)
DTR:      ● ON     (BBS is accepting calls)

SPEED:    9600 baud, 8 data bits, no parity, 1 stop bit
BUFFER:   RX ████░░░░ 142/4096   TX ░░░░░░░░ 0/4096
```

### Modem Lights

| Light | What It Means |
|-------|--------------|
| CARRIER (DCD) | Is someone connected? ON = yes, a caller is on the line |
| RING (RI) | Is someone calling in? ON = the phone is ringing |
| READY (DSR) | Is the modem ready? ON = yes |
| SEND READY (CTS) | Can the modem send right now? ON = yes |
| DTR | Is the BBS accepting calls? ON = yes. OFF = BBS hung up |
| RTS | Is the BBS ready for more data? ON = yes |

### Speed Line

| Term | What It Means |
|------|--------------|
| Baud | Speed of the connection (e.g. 9600 = 9600 bits per second) |
| Data bits | How many bits per character (usually 8) |
| Parity | Error checking (usually N = none) |
| Stop bits | Pause between characters (usually 1) |
| "8-N-1" | The standard: 8 data bits, No parity, 1 stop bit |

### Buffer Bar

```
RX ████░░░░ 142/4096
```

| Part | Meaning |
|------|---------|
| RX | Receive buffer — data FROM the caller waiting for the BBS to read |
| TX | Transmit buffer — data FROM the BBS waiting to be sent to the caller |
| ████░░░░ | How full the buffer is (filled = data waiting) |
| 142/4096 | 142 bytes waiting out of 4096 capacity |

If RX fills up: the caller is sending faster than the BBS reads.
If TX fills up: the BBS is sending faster than the connection can carry.
Both are normal during file transfers.

## Events Panel

Shows important things that happen, in plain English.

```
12:34:56  ☎ Caller connected from 192.168.1.5
12:34:56  🤝 Connection negotiated (binary mode)
12:34:56  📞 Carrier signal ON — call is active
12:34:57  💾 Zmodem transfer detected
12:35:42  📞 Carrier signal OFF — caller hung up
12:35:42  ☎ Caller disconnected (1 min 46 sec, 24.3 KB transferred)
```

### Event Types

| Icon | Event | What It Means |
|------|-------|--------------|
| ☎ | CONNECT | A new caller connected to your BBS |
| ☎ | DISCONNECT | The caller left (or got disconnected) |
| 🤝 | HANDSHAKE | The connection was set up (Telnet negotiation) |
| 📞 | CARRIER ON | The virtual modem "picked up the phone" |
| 📞 | CARRIER OFF | The virtual modem "hung up" |
| 🔔 | RING | An incoming call is ringing |
| 💾 | ZMODEM | A Zmodem file transfer was detected in the data |
| ⚡ | DTR UP | The BBS raised DTR (ready for calls) |
| ⚡ | DTR DOWN | The BBS lowered DTR (not accepting calls / hanging up) |
| 🔧 | FOSSIL | The BBS made a FOSSIL driver call (normal operation) |
| ⚠️ | ERROR | Something went wrong (check the detail message) |
| 🛑 | BREAK | A break signal was sent (used to interrupt the remote) |
| 🔄 | FLOW | Flow control changed (hardware handshaking) |

## FOSSIL Function Reference

When the BBS calls the FOSSIL driver, the events panel shows which
function was called. Here's what they mean:

| Function | What The BBS Is Doing |
|----------|----------------------|
| Init ($04) | Starting up the modem connection |
| Set Speed ($00) | Setting the baud rate (e.g. 9600) |
| Send Byte ($01) | Sending one character to the caller |
| Receive Byte ($02) | Reading one character from the caller |
| Check Status ($03) | Checking if there's data waiting |
| Deinit ($05) | Shutting down the modem connection |
| DTR Control ($06) | Raising/lowering DTR (answer/hangup) |
| Flush ($08) | Waiting for all sent data to go out |
| Clear Output ($09) | Throwing away unsent data |
| Clear Input ($0A) | Throwing away unread data |
| Send Block ($19) | Sending a chunk of data (file transfer) |
| Receive Block ($18) | Reading a chunk of data (file transfer) |
| Peek ($0C) | Looking at the next byte without reading it |
| Break ($1A) | Sending a break signal |
| Get Info ($1B) | Asking the driver about buffer sizes, version, etc. |
| Flow Control ($0F) | Setting up hardware handshaking |

## Troubleshooting

| Symptom | What's Wrong | Fix |
|---------|-------------|-----|
| CARRIER stays OFF | Caller connected but BBS doesn't see them | Check that the virtual COM port is set up correctly |
| TX buffer fills up | BBS is sending but nothing goes out | Check the TCP connection — the caller may have a slow link |
| RX buffer fills up | Caller is sending but BBS isn't reading | The BBS software might be stuck — check the door |
| "BREAK" events | Caller sent a break signal | Normal — some terminals send this on disconnect |
| Lots of "FOSSIL" events | Constant FOSSIL calls | Normal — the BBS polls the modem in a loop |
| No events at all | Nothing is happening | Is anyone connected? Check the caller list |
