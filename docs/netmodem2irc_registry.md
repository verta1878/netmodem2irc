# NetModem/32 Registry Layout (Original)

## Overview

Dedrick Allen's original NetModem/32 VxD reads its configuration from the
Windows registry at Ring-0 boot (`SysDeviceCriticalInit`). The config CPL
(`NETMODEM.CPL`) writes these values. netmodem2irc replaces the registry
— this document describes the registry layout used by both the VxD and our code
for reference and 9x branch compatibility.

## Registry Key

    HKEY_LOCAL_MACHINE\Software\Allen Software\NetModem

## Values

### ComportConfig (REG_BINARY)

Array of `ComportStruct` records, one per node (up to MaxNodes). Each record
is packed, matching the VxD's in-memory layout (from `NETMODEM.INC`):

    Offset  Size  Field             Description
    ------  ----  -----             -----------
    0       1     Node              Node index (0-based)
    1       1     Enabled           0=disabled, 1=enabled
    2       1     ComportNumber     Virtual COM port number (3-99)
    3       7     szComportName     ASCII name, e.g. "COM3\0\0\0"
    10      1     Emulation         0=UART, 1=FOSSIL
    11      2     Baudrate          19200/38400/57600/115200
    13      2     Internetport      TCP port for inbound telnet
    15      2     Baseaddress       I/O base address (emulated)
    17      1     Alwaysactive      Keep node active even without connection
    18      1     Lockedbaudrate    Lock baud rate (no auto-negotiate)
    19      1     Managetimeslice   Yield CPU time when idle
    20      2     Buffersize        RX/TX buffer size

    Total: 22 bytes per node

The VxD allocates `SizeOf(ComportStruct) * MaxNodes` bytes of heap
and reads the entire blob from the registry in one `_RegQueryValueEx` call.

### IRQ (REG_DWORD)

Single DWORD — the IRQ number assigned to the virtual COM ports. The VxD
virtualizes this IRQ via VPICD to signal the DOS/16-bit app when data
arrives. Read during init if present; if absent, IRQ virtualization is
skipped.

## How the VxD Uses It

1. `SysDeviceCriticalInit` — allocates StatusStruct + ComportStruct arrays
2. Opens `HKLM\Software\Allen Software\NetModem`
3. Reads `ComportConfig` → fills per-node config structs
4. Reads `IRQ` → virtualizes interrupt if present
5. Closes registry key
6. For each enabled node: hooks INT 14h (FOSSIL), sets up UART emulation
7. `IOCTL_RELOAD_CONFIG` (code $03) — re-reads registry at runtime when
   the config CPL saves changes (no reboot needed)

## How netmodem2irc Replaces It

netmodem2irc uses the same registry keys as the original. Text config is also supported:

    Original (registry):
    HKLM\Software\Allen Software\NetModem\ComportConfig = <binary blob>
    HKLM\Software\Allen Software\NetModem\IRQ = <dword>

    netmodem2irc (text file):
    node 3 comport 3 baud 38400 mode fossil
    node 4 comport 4 baud 57600 mode fossil

Benefits:
- Cross-platform (works on Linux, DOS, Win9x, NT)
- No Windows ACL/permission issues
- Human-readable and editable
- No registry pollution
- Connection targets come from AT dial commands (ATDT host:port),
  not baked into config — matching real modem behavior

## 9x Branch Compatibility

If running with Dedrick's original VxD on Win9x, the NMConfig GUI would
need to write `ComportConfig` and `IRQ` to the registry so the VxD can
read them. The constants are defined in `common/NMVxD.pas`:

    REG_NETMODEM_KEY  = 'Software\Allen Software\NetModem';
    REG_CONFIG_VALUE  = 'ComportConfig';
    REG_IRQ_VALUE     = 'IRQ';

The TComportStruct record in NMVxD.pas matches the VxD's binary layout
byte-for-byte.

## Source References

- `driver/src/NETMODEM.ASM` lines 175-176 (key/value names)
- `driver/src/NETMODEM.ASM` lines 249-266 (registry read during init)
- `driver/src/NETMODEM.ASM` lines 481-485 (IRQ read)
- `driver/src/NETMODEM.INC` (ComportStruct definition)
- `common/NMVxD.pas` (Pascal translation of all structs and constants)
- `engine/NM_Config.pas` (text config — matches all CPL per-node fields 1:1)
