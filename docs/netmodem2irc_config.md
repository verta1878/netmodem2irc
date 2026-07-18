# netmodem2irc — configuration

## Storage

Primary: Windows registry (`HKLM\Software\Allen Software\NetModem`)
- `ComportConfig` — REG_BINARY, array of ComportStruct (22 bytes/node)
- `IRQ` — REG_DWORD

Text config also supported (NM_Config.ParseText):
    node 1 comport 3 baud 38400 mode fossil port 23

## What configures what

- **CPL / NMConfig** writes the registry (per-node settings)
- **VxD driver** reads the registry at boot + on IOCTL 03 reload
- **NMServer** does NOT read config — the driver already has it
- **Connection targets** come from AT dial (ATDT host:port), not config

## Per-node fields

All fields match the original NetModem/32 CPL 1:1:

    NodeIndex, ComPort, Baud, Mode, Enabled, InternetPort,
    BaseAddress, BufferSize, AlwaysActive, LockedBaudRate, ManageTimeSlice

- NM_Config parses and validates (boundary-checked, tested)
- NM_ConfigApply applies to the bridge (tested)
- NM_DefaultConfig writes factory defaults to registry
- 35 test programs, 0 failures

## Factory defaults (NetModem v1)

    Node 1, COM3, 38400 baud, FOSSIL, port 23, base $03E8,
    buffer 2048, lockedbaud on, timeslice on, enabled
