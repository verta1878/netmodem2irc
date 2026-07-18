# netmodem2irc CPL configuration — design

## What it is

A Control Panel applet (.cpl) that configures the NetModem/32 driver.
Reads/writes `HKLM\Software\Allen Software\NetModem` (ComportConfig
binary blob + IRQ dword) — the same registry keys the VxD reads at boot.

## Architecture

    CPL (.cpl in system32)  ──writes──>  Registry (ComportConfig, IRQ)
    NMConfig.exe            ──writes──>  Registry (same keys)
                                              │
    VxD driver              ──reads───<───────┘  (at boot + IOCTL 03 reload)
    NMServer.exe            does NOT read config (driver has it)

Connection targets come from AT dial commands (ATDT host:port), not config.

## Registry layout

    HKLM\Software\Allen Software\NetModem
      ComportConfig   REG_BINARY   array of TRegComportStruct (22 bytes each)
      IRQ             REG_DWORD    interrupt number (0 = none)

See docs/netmodem2irc_registry.md for field-by-field layout.

## Per-node fields (matches original CPL TForm1)

    Field            Type    Default    CPL Control
    -----            ----    -------    -----------
    Node             Byte    1          ListBox1 (COM port list)
    Enabled          Byte    1          RadioButton Enabled/Disabled
    ComportNumber    Byte    3          ListBox1 selection
    Emulation        Byte    1(FOSSIL)  ComboBox2 (UART/FOSSIL)
    Baudrate         Word    38400      ComboBox3 (300-115200)
    Internetport     Word    23         Edit7 + UpDown5
    Baseaddress      Word    $03E8      Edit8 + UpDown6
    Buffersize       Word    2048       ComboBox4/5 (1024-8192)
    Alwaysactive     Byte    0          CheckBox
    Lockedbaudrate   Byte    1          CheckBox
    Managetimeslice  Byte    1          CheckBox

## Implementation

    history/NETMODEM.CPL     — original Dedrick Allen binary (657KB, Delphi 5)
    config/NMConfig.lpr      — standalone config app (same functionality)
    config/ConfigMain.pas    — Lazarus form, reads/writes registry
    engine/NM_DefaultConfig  — WriteDefaultRegistry, factory defaults
    common/NMVxD.pas         — TRegComportStruct, registry key constants

## Original CPL forms (recovered)

    cpl/original_forms/NETMODEM_CPL__TForm1.dfm  — main config (424x398)
    cpl/original_forms/NETMODEM_CPL__TForm2.dfm  — listserv info
    cpl/original_forms/NETMODEM_CPL__TForm3.dfm  — global config
    cpl/original_forms/NETMODEM_CPL__TForm4.dfm  — (settings)
    cpl/original_forms/NETMODEM_CPL__TForm5.dfm  — (minimal)
    cpl/original_forms/NETMODEM_CPL__TForm6.dfm  — (address book)

Original binary: history/NETMODEM.CPL (657KB, Delphi 5)

## Build

    copy NETMODEM.CPL %SystemRoot%\system32\

Using original NETMODEM.CPL binary. Config app (NMConfig) requires fpc264irc r6.1+.
