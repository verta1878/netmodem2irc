unit NM_UART16550;
{ ===========================================================================
  netmodem2irc — NS-16550 UART emulation (NT-branch, user-mode)
  ---------------------------------------------------------------------------
  A faithful user-mode re-creation of the 16550 register file that Dedrick
  Allen's Ring-0 VxD emulated in NETMODEM.ASM (see docs LAYER_A_SPEC.md §1).

  On the 9x branch, the VxD trapped I/O-port access and serviced these
  registers in Ring-0. On the NT branch there is no VxD: a user-mode virtual
  COM layer delivers register reads/writes here, and this unit's TX/RX rings
  are drained/filled by the Telnet server over a socket.

  This unit is PURE emulation logic — no OS calls, no sockets, no I/O ports.
  That keeps it portable and testable in isolation. The transport (virtual COM
  + WinSock) lives elsewhere (see NT_TRANSPORT_LAYER.md).

  Source of truth: driver/src/NETMODEM.INC (UARTStruct) + NETMODEM.ASM
  (IOHandler). Register semantics: NS-16550 datasheet.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  { --- 16550 register offsets from the port base address --- }
  { When DLAB (LCR bit 7) = 0 }
  UART_RBR = 0;   // R : Receiver Buffer Register
  UART_THR = 0;   // W : Transmit Holding Register
  UART_IER = 1;   // R/W: Interrupt Enable Register
  { When DLAB = 1, offsets 0/1 access the divisor latches }
  UART_DLL = 0;   // R/W: Divisor Latch Low
  UART_DLM = 1;   // R/W: Divisor Latch High
  { Always at these offsets }
  UART_IIR = 2;   // R : Interrupt Identification Register
  UART_FCR = 2;   // W : FIFO Control Register
  UART_LCR = 3;   // R/W: Line Control Register
  UART_MCR = 4;   // R/W: Modem Control Register
  UART_LSR = 5;   // R : Line Status Register
  UART_MSR = 6;   // R : Modem Status Register
  UART_SCR = 7;   // R/W: Scratch Register

  { --- LCR bits --- }
  LCR_DLAB     = $80;   // divisor latch access
  LCR_BREAK    = $40;   // set break

  { --- LSR bits (NS-16550) --- }
  LSR_DR       = $01;   // data ready (RX has a byte)
  LSR_OE       = $02;   // overrun error
  LSR_PE       = $04;   // parity error
  LSR_FE       = $08;   // framing error
  LSR_BI       = $10;   // break interrupt
  LSR_THRE     = $20;   // transmit holding register empty (room to send)
  LSR_TEMT     = $40;   // transmitter empty (THR + shift both empty)
  LSR_FIFOERR  = $80;   // error in RX FIFO

  { --- MCR bits --- }
  MCR_DTR      = $01;   // data terminal ready (drop => hangup)
  MCR_RTS      = $02;   // request to send
  MCR_OUT1     = $04;
  MCR_OUT2     = $08;   // gates interrupts on real HW
  MCR_LOOP     = $10;   // local loopback (local echo test)

  { --- MSR bits --- }
  MSR_DCTS     = $01;   // delta CTS
  MSR_DDSR     = $02;   // delta DSR
  MSR_TERI     = $04;   // trailing-edge ring indicator
  MSR_DDCD     = $08;   // delta DCD
  MSR_CTS      = $10;   // clear to send
  MSR_DSR      = $20;   // data set ready
  MSR_RI       = $40;   // ring indicator (incoming call)
  MSR_DCD      = $80;   // data carrier detect (online/connected)

  { --- IER bits --- }
  IER_RDA      = $01;   // received-data-available interrupt
  IER_THRE     = $02;   // transmitter-holding-empty interrupt
  IER_RLS      = $04;   // receiver-line-status interrupt
  IER_MSI      = $08;   // modem-status interrupt

  { --- IIR values (cause, by priority) --- }
  IIR_NONE     = $01;   // no interrupt pending (bit0=1 means none)
  IIR_RLS      = $06;   // receiver line status (highest)
  IIR_RDA      = $04;   // received data available
  IIR_THRE     = $02;   // transmitter holding empty
  IIR_MSI      = $00;   // modem status (lowest)
  IIR_FIFO     = $C0;   // FIFOs enabled (OR'd into IIR when FCR bit0 set)

  RING_SIZE = 4096;     // TX/RX ring capacity (bytes)

type
  { A simple byte ring buffer — the TX and RX paths (LAYER_A_SPEC §1). }
  TByteRing = record
    Data : array[0..RING_SIZE-1] of Byte;
    Head : Word;          // write index
    Tail : Word;          // read index
    Count: Word;          // bytes currently stored
  end;

  { The emulated 16550 state. Mirrors NETMODEM.INC UARTStruct, plus the two
    ring buffers that on 9x were the VxD's TX/RX buffers. }
  TUart16550 = record
    { 16550 registers — standard datasheet mnemonics, kept as-is so the code matches
      any UART reference a reader has open:
        IER Interrupt Enable      IIR Interrupt Identification   FCR FIFO Control
        LCR Line Control          MCR Modem Control              LSR Line Status
        MSR Modem Status          SCR Scratch                    DLL Divisor Latch Low
        DLM Divisor Latch High }
    IER, IIR, FCR, LCR, MCR, LSR, MSR, SCR, DLL, DLM : Byte;
    { rings (RBR reads pull from RX; THR writes push to TX) }
    RX : TByteRing;       // ReceiveRing:  bytes from the network, guest reads via RBR
    TX : TByteRing;       // TransmitRing: bytes from the guest, server sends to network
    { modem/line state reflected into MSR }
    Online  : Boolean;    // carrier present -> MSR_DCD (data carrier detect)
    Ringing : Boolean;    // incoming call   -> MSR_RI  (ring indicator)
    FifoOn  : Boolean;    // FCR bit0 (FIFO enabled)
  end;
  PUart16550 = ^TUart16550;

{ --- ring primitives --- }
procedure RingClear(var R: TByteRing);
function  RingPut(var R: TByteRing; B: Byte): Boolean;   // false if full
function  RingGet(var R: TByteRing; out B: Byte): Boolean;// false if empty
function  RingFree(const R: TByteRing): Word;

{ --- UART lifecycle --- }
procedure UartReset(var Uart: TUart16550);

{ --- the guest-side register interface (what the virtual COM layer calls) --- }
{ Read a UART register at the given offset (0..7). Honors DLAB. }
function  UartReadReg(var Uart: TUart16550; Offset: Byte): Byte;
{ Write a UART register at the given offset (0..7). Honors DLAB. }
procedure UartWriteReg(var Uart: TUart16550; Offset: Byte; Value: Byte);

{ --- the network-side interface (what the Telnet server calls) --- }
{ Server delivers a byte received from the socket into RX (guest will read it). }
function  UartNetToGuest(var Uart: TUart16550; B: Byte): Boolean;
{ Server drains a byte the guest wrote to TX (to send over the socket). }
function  UartGuestToNet(var Uart: TUart16550; out B: Byte): Boolean;

{ --- status helpers --- }
procedure UartSetCarrier(var Uart: TUart16550; AOnline: Boolean);
procedure UartSetRing(var Uart: TUart16550; ARinging: Boolean);
procedure UartRecomputeLSR(var Uart: TUart16550);
procedure UartRecomputeMSR(var Uart: TUart16550);

implementation

procedure RingClear(var R: TByteRing);
begin
  R.Head := 0; R.Tail := 0; R.Count := 0;
end;

function RingPut(var R: TByteRing; B: Byte): Boolean;
begin
  if R.Count >= RING_SIZE then
    Exit(False);
  R.Data[R.Head] := B;
  R.Head := (R.Head + 1) mod RING_SIZE;
  Inc(R.Count);
  Result := True;
end;

function RingGet(var R: TByteRing; out B: Byte): Boolean;
begin
  if R.Count = 0 then
    Exit(False);
  B := R.Data[R.Tail];
  R.Tail := (R.Tail + 1) mod RING_SIZE;
  Dec(R.Count);
  Result := True;
end;

function RingFree(const R: TByteRing): Word;
begin
  Result := RING_SIZE - R.Count;
end;

procedure UartReset(var Uart: TUart16550);
begin
  RingClear(Uart.RX);
  RingClear(Uart.TX);
  Uart.IER := 0;
  Uart.IIR := IIR_NONE;
  Uart.FCR := 0;
  Uart.LCR := $03;          // 8N1 default (word length 8, no parity, 1 stop)
  Uart.MCR := 0;
  Uart.SCR := 0;
  Uart.DLL := $01;          // 115200 default divisor low (cosmetic over TCP)
  Uart.DLM := $00;
  Uart.Online  := False;
  Uart.Ringing := False;
  Uart.FifoOn  := False;
  UartRecomputeLSR(Uart);
  UartRecomputeMSR(Uart);
end;

{ LSR reflects the ring state: DR if RX has data, THRE/TEMT if TX has room. }
procedure UartRecomputeLSR(var Uart: TUart16550);
begin
  Uart.LSR := 0;
  if Uart.RX.Count > 0 then
    Uart.LSR := Uart.LSR or LSR_DR;
  if RingFree(Uart.TX) > 0 then
    Uart.LSR := Uart.LSR or LSR_THRE;
  if Uart.TX.Count = 0 then
    Uart.LSR := Uart.LSR or LSR_TEMT;
end;

{ MSR reflects modem state: DCD from Online, RI from Ringing. CTS/DSR are held
  asserted (a virtual modem is always "ready"). Delta bits are set by the
  set-carrier / set-ring helpers when state changes. }
procedure UartRecomputeMSR(var Uart: TUart16550);
begin
  { preserve delta bits (low nibble), rebuild status bits (high nibble) }
  Uart.MSR := Uart.MSR and $0F;
  Uart.MSR := Uart.MSR or MSR_CTS or MSR_DSR;
  if Uart.Online then
    Uart.MSR := Uart.MSR or MSR_DCD;
  if Uart.Ringing then
    Uart.MSR := Uart.MSR or MSR_RI;
end;

procedure UartSetCarrier(var Uart: TUart16550; AOnline: Boolean);
begin
  if Uart.Online <> AOnline then
  begin
    Uart.Online := AOnline;
    Uart.MSR := Uart.MSR or MSR_DDCD;   // signal delta-DCD (carrier changed)
  end;
  UartRecomputeMSR(Uart);
end;

procedure UartSetRing(var Uart: TUart16550; ARinging: Boolean);
begin
  if Uart.Ringing <> ARinging then
  begin
    Uart.Ringing := ARinging;
    Uart.MSR := Uart.MSR or MSR_TERI;   // trailing-edge ring indicator
  end;
  UartRecomputeMSR(Uart);
end;

function UartReadReg(var Uart: TUart16550; Offset: Byte): Byte;
var
  DLAB: Boolean;
  B: Byte;
begin
  DLAB := (Uart.LCR and LCR_DLAB) <> 0;
  case Offset of
    0: if DLAB then
         Result := Uart.DLL
       else
       begin
         { RBR — pull next received byte from RX ring }
         if RingGet(Uart.RX, B) then
           Result := B
         else
           Result := 0;
         UartRecomputeLSR(Uart);
       end;
    1: if DLAB then
         Result := Uart.DLM
       else
         Result := Uart.IER;
    2: begin
         { IIR — report highest-priority pending cause (LAYER_A_SPEC §2) }
         Result := IIR_NONE;
         if ((Uart.IER and IER_RDA) <> 0) and (Uart.RX.Count > 0) then
           Result := IIR_RDA
         else if ((Uart.IER and IER_THRE) <> 0) and (RingFree(Uart.TX) > 0) then
           Result := IIR_THRE;
         if Uart.FifoOn then
           Result := Result or IIR_FIFO;
       end;
    3: Result := Uart.LCR;
    4: Result := Uart.MCR;
    5: begin
         UartRecomputeLSR(Uart);
         Result := Uart.LSR;
       end;
    6: begin
         Result := Uart.MSR;
         { reading MSR clears the delta (low-nibble) bits }
         Uart.MSR := Uart.MSR and $F0;
       end;
    7: Result := Uart.SCR;
  else
    Result := 0;
  end;
end;

procedure UartWriteReg(var Uart: TUart16550; Offset: Byte; Value: Byte);
var
  DLAB: Boolean;
begin
  DLAB := (Uart.LCR and LCR_DLAB) <> 0;
  case Offset of
    0: if DLAB then
         Uart.DLL := Value
       else
       begin
         { THR — push byte to TX ring for the server to send }
         RingPut(Uart.TX, Value);
         UartRecomputeLSR(Uart);
       end;
    1: if DLAB then
         Uart.DLM := Value
       else
         Uart.IER := Value and $0F;
    2: begin
         { FCR — FIFO control }
         Uart.FCR := Value;
         Uart.FifoOn := (Value and $01) <> 0;
         if (Value and $02) <> 0 then RingClear(Uart.RX);  // clear RX FIFO
         if (Value and $04) <> 0 then RingClear(Uart.TX);  // clear TX FIFO
       end;
    3: Uart.LCR := Value;
    4: Uart.MCR := Value;   // note: DTR drop is handled by the transport layer
    5: ;                 // LSR is read-only
    6: ;                 // MSR is read-only
    7: Uart.SCR := Value;
  end;
end;

function UartNetToGuest(var Uart: TUart16550; B: Byte): Boolean;
begin
  Result := RingPut(Uart.RX, B);
  UartRecomputeLSR(Uart);
end;

function UartGuestToNet(var Uart: TUart16550; out B: Byte): Boolean;
begin
  Result := RingGet(Uart.TX, B);
  UartRecomputeLSR(Uart);
end;

end.
