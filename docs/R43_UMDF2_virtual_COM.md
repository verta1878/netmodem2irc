# R4.3 — NT Native UMDF2 Virtual COM Port Driver

## Overview

A **User-Mode Driver Framework v2 (UMDF2)** driver that creates virtual
COM ports on Windows 10/11 without third-party dependencies. Each virtual
COM port connects to NMServer's engine via shared memory or named pipes.

This is the "Option A" frontier — the cleanest NT path, but the most
work. It replaces com0com with our own signed, installable driver.

## Architecture

```
                    User Mode
    ┌──────────────────────────────────────────┐
    │  BBS Door                                │
    │  (opens COM3)                            │
    │       │                                  │
    │       ▼                                  │
    │  ┌─────────────────┐                     │
    │  │  UMDF2 Driver   │ ◄── netmodem_vcom   │
    │  │  (virtual COM)  │                     │
    │  └────────┬────────┘                     │
    │           │ named pipe / shared memory    │
    │           ▼                               │
    │  ┌─────────────────┐                     │
    │  │  NMServer.exe   │                     │
    │  │  (engine)       │                     │
    │  └────────┬────────┘                     │
    │           │ TCP socket                   │
    │           ▼                               │
    │     Telnet caller                        │
    └──────────────────────────────────────────┘
                   (no kernel mode needed)
```

## Why UMDF2

- **User-mode**: no blue screens, no kernel debugging
- **Signed**: Microsoft provides attestation signing for UMDF2 drivers
  through the Windows Hardware Dev Center (free for open-source projects)
- **Installable**: standard INF + driver package, works with Windows Update
- **No test signing**: unlike com0com, works on stock Windows 10/11
- **Multi-port**: one driver instance creates N virtual COM ports

## Driver Design

### INF File (netmodem_vcom.inf)

```ini
[Version]
Signature   = "$Windows NT$"
Class       = Ports
ClassGuid   = {4D36E978-E325-11CE-BFC1-08002BE10318}
Provider    = %ProviderString%
DriverVer   = 07/28/2026,1.0.0.0
CatalogFile = netmodem_vcom.cat

[SourceDisksNames]
1 = %DiskName%

[SourceDisksFiles]
netmodem_vcom.dll = 1

[DestinationDirs]
DefaultDestDir = 12  ; %SystemRoot%\System32\Drivers

[Manufacturer]
%ManufacturerString% = Standard,NTamd64

[Standard.NTamd64]
%DeviceDesc% = NetModem_Install, Root\NetModemVCOM

[NetModem_Install]
CopyFiles = NetModem_CopyFiles

[NetModem_CopyFiles]
netmodem_vcom.dll

[NetModem_Install.Services]
AddService = WUDFRd,0x000001fa,WUDFRD_ServiceInstall

[WUDFRD_ServiceInstall]
ServiceType    = 1
StartType      = 3
ErrorControl   = 1
ServiceBinary  = %12%\WUDFRd.sys

[NetModem_Install.Wdf]
UmdfService      = NetModemVCOM, NetModem_UmdfInstall
UmdfServiceOrder = NetModemVCOM

[NetModem_UmdfInstall]
UmdfLibraryVersion = 2.31
ServiceBinary      = %12%\UMDF\netmodem_vcom.dll
DriverCLSID        = {YOUR-GUID-HERE}

[Strings]
ProviderString     = "netmodem2irc"
ManufacturerString = "netmodem2irc"
DeviceDesc         = "NetModem/32 Virtual COM Port"
DiskName           = "NetModem/32 Driver Disk"
```

### Driver Source (C, UMDF2)

The driver implements the serial port interface:

```c
// netmodem_vcom.c — UMDF2 virtual COM port driver

#include <windows.h>
#include <wdf.h>
#include <ntddser.h>   // serial IOCTL definitions

// Device context: one per virtual COM port
typedef struct _DEVICE_CONTEXT {
    HANDLE hPipe;           // named pipe to NMServer
    WCHAR  PipeName[256];   // \\.\pipe\netmodem_node_N
    ULONG  BaudRate;
    SERIAL_LINE_CONTROL LineControl;
    SERIAL_HANDFLOW HandFlow;
    ULONG  ModemStatus;     // MSR: DCD, DSR, CTS, RI
} DEVICE_CONTEXT, *PDEVICE_CONTEXT;

WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(DEVICE_CONTEXT, GetDeviceContext);

// IOCTLs we handle (the ones BBS software actually uses):
//   IOCTL_SERIAL_SET_BAUD_RATE
//   IOCTL_SERIAL_GET_BAUD_RATE
//   IOCTL_SERIAL_SET_LINE_CONTROL
//   IOCTL_SERIAL_GET_LINE_CONTROL
//   IOCTL_SERIAL_SET_HANDFLOW
//   IOCTL_SERIAL_GET_MODEM_STATUS  <-- DCD = carrier detect
//   IOCTL_SERIAL_SET_DTR
//   IOCTL_SERIAL_CLR_DTR
//   IOCTL_SERIAL_SET_RTS
//   IOCTL_SERIAL_CLR_RTS
//   IOCTL_SERIAL_GET_COMMSTATUS
//   IOCTL_SERIAL_PURGE
//   IOCTL_SERIAL_SET_TIMEOUTS
//   IOCTL_SERIAL_GET_PROPERTIES
//   IOCTL_SERIAL_SET_WAIT_MASK
//   IOCTL_SERIAL_WAIT_ON_MASK

// Read/Write: bytes go through the named pipe to NMServer.
// NMServer's engine bridges them to/from the Telnet socket.
```

### Named Pipe Protocol

```
NMServer creates:  \\.\pipe\netmodem_node_0
                   \\.\pipe\netmodem_node_1
                   ...

Driver connects to the pipe matching its node index.

Data flow:
  BBS writes to COM3 -> driver -> pipe -> NMServer -> TCP
  TCP -> NMServer -> pipe -> driver -> BBS reads from COM3

Control flow (out-of-band):
  NMServer sets DCD (carrier) by writing a control byte:
    0x01 = carrier on (DCD set in MSR)
    0x02 = carrier off (DCD clear)
    0x03 = RING (RI set in MSR)
  Driver responds to IOCTL_SERIAL_GET_MODEM_STATUS with
  the current MSR state.
```

## Build Requirements

- Windows 10 SDK + WDK (Windows Driver Kit)
- Visual Studio 2019+ with WDK extension
- Or: standalone WDK + MSBuild

```
msbuild netmodem_vcom.vcxproj /p:Configuration=Release /p:Platform=x64
```

## Signing

For distribution:
1. Create a Windows Hardware Dev Center account
2. Submit the driver package for attestation signing
3. Microsoft signs the .cat file
4. Package with the INF for installation

For development/testing:
```
bcdedit /set testsigning on
signtool sign /v /s PrivateCertStore /n "NetModem Test" /t http://timestamp.digicert.com netmodem_vcom.dll
```

## Installation

```cmd
pnputil /add-driver netmodem_vcom.inf /install
```

Or via Device Manager: Add legacy hardware > Install from list > Ports >
Have Disk > point to netmodem_vcom.inf.

## Comparison

| | com0com (R4.2) | UMDF2 (R4.3) |
|---|---|---|
| Kernel mode | Yes (WDM) | No (user-mode) |
| Signing | Unsigned (hack needed) | Attestation signed |
| Maintenance | Abandoned (~2012) | Our code, maintained |
| Multi-port | Pair-per-node | N ports from one driver |
| Stability | Can BSOD | Cannot BSOD |
| Windows 11 | Broken without hacks | Works stock |
| Development | Not needed (install only) | C + WDK + signing |
| Time to ship | Days | Weeks |

## Roadmap

1. Prototype: hardcoded single COM port, named pipe, read/write only
2. Add serial IOCTLs (baud, line control, modem status)
3. Add DCD/RI signaling through the pipe
4. Multi-port: N ports from registry config
5. INF packaging + test signing
6. Attestation signing via WHDC
7. Inno Setup integration (R5.1)

## Status

R4.3 is the frontier. com0com (R4.2) works TODAY for sysops who need
it. The UMDF2 driver is the long-term clean solution. Development
starts after M3 runtime is stable.
