# driver/src/ — RETIRED

The original NETMODEM.VXD MASM source (Dedrick Allen, 5,712 lines)
has been moved to `attic/driver-vxd-original/`.

All logic has been ported to Pascal:

| VxD Component | Pascal Equivalent |
|---------------|-------------------|
| IOHandler00-07 (UART) | engine/NM_UART16550.pas |
| INT14 00-21h (FOSSIL) | engine/NM_Fossil.pas |
| AT command parser | engine/NM_ATCommand.pas |
| IOCTL 00-10h | common/NMVxD.pas |
| Ring buffers | NM_UART16550 ring buffer |
| StatusStruct | driver/pascal-port/NM_VxD_Types.pas |
| VCOMM port hooks | engine/NM_ServerBridge.pas |
| Registry config | engine/NM_GlobalConfig.pas |
| Named pipe link | engine/NM_NamedPipeLink.pas |
| com0com link | engine/NM_Com0ComLink.pas |

The ~1,400 lines of VxD kernel framework (VMM calls, V86 memory,
VPICD IRQ virtualization, DDB) have no Pascal equivalent — they are
Win9x Ring-0 concepts that don't apply to user-mode code.

The Pascal port is **safer** than the original VxD:
- Ring buffer bounds checked (RingFree before write)
- AT parser overflow handled
- File I/O try/finally protected
- XON/XOFF intercepted in pump loop
- MCR loopback wired
- X00 extensions (Fn20h, Fn21h, 7Eh, 7Fh) implemented
- 64-bit safe (PtrInt for handles)
