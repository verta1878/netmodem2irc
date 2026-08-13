{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

  Dedrick Allen's original NetModem/32 material preserved in driver/src/,
  history/ and cpl/original_forms/ remains under GPLv2 - see LICENSES.md.
  =========================================================================== }

unit NM_Fossil;
{ ===========================================================================
  netmodem2irc — FOSSIL (INT 14h) emulation (NT-branch, user-mode)
  ---------------------------------------------------------------------------
  User-mode re-creation of the Rev.5 FOSSIL + X00-superset services that
  Dedrick Allen's VxD dispatched via Int14_Table in NETMODEM.ASM
  (see docs LAYER_A_SPEC.md §3).

  FOSSIL is the DOCUMENTED serial API that DOS BBS door games call through
  INT 14h. This unit implements the function set on top of the 16550 UART
  emulation (NM_UART16550) — doors call FOSSIL, FOSSIL moves bytes through the
  UART's TX/RX rings, and the transport layer moves those to/from the socket.

  Register model: FOSSIL uses AH = function number, and returns values in
  AX/BX/etc. We model a "client register frame" (TFossilRegs) instead of real
  CPU registers, since on NT there is no INT 14h trap — the virtual COM / door
  shim calls FossilDispatch with a filled-in frame.

  Exact values verified against NETMODEM.ASM:
    Fn 04h (init) -> AX = 1954h (FOSSIL signature), BX = 0521h (maxfunc/ver)
    Fn 03h (status) -> AH bit0 = RX data ready, plus line/modem status
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils,
  NM_UART16550;

const
  { FOSSIL identity (from NETMODEM.ASM INT1404) }
  FOSSIL_SIGNATURE = $1954;   // AX on successful init
  FOSSIL_INFO_BX   = $0521;   // BX: max function 21h, FOSSIL rev 5
  FOSSIL_MAJVER    = 5;
  FOSSIL_MINVER    = 0;

  { INT 14h function numbers (AH) — LAYER_A_SPEC §3 }
  FN_SET_BAUD        = $00;
  FN_TX_WAIT         = $01;
  FN_RX_WAIT         = $02;
  FN_GET_STATUS      = $03;
  FN_INIT            = $04;
  FN_DEINIT          = $05;
  FN_SET_DTR         = $06;
  FN_TIMER_TICK      = $07;
  FN_FLUSH_OUTPUT    = $08;
  FN_PURGE_OUTPUT    = $09;
  FN_PURGE_INPUT     = $0A;
  FN_TX_NOWAIT       = $0B;
  FN_PEEK            = $0C;
  FN_KBD_NOWAIT      = $0D;
  FN_KBD_WAIT        = $0E;
  FN_FLOW_CONTROL    = $0F;
  FN_CTRLC_CHECK     = $10;
  FN_SET_CURSOR      = $11;
  FN_GET_CURSOR      = $12;
  FN_ANSI_WRITE      = $13;
  FN_WATCHDOG        = $14;
  FN_WRITE_BIOS      = $15;
  FN_INSDEL          = $16;
  FN_REBOOT          = $17;
  FN_READ_BLOCK      = $18;
  FN_WRITE_BLOCK     = $19;
  FN_BREAK           = $1A;
  { X00 SuperSet extensions (Dedrick Allen / NetModem/32) }
  FN_X00_READ        = $20;   // extended non-blocking read
  FN_X00_INJECT      = $21;   // write byte into RX buffer
  FN_GET_INFO        = $1B;

  { status bits returned by Fn 03h in AH (line status, 16550-like) }
  FSTAT_RX_READY     = $01;   // AH bit0: at least one char waiting
  FSTAT_TX_ROOM      = $20;   // AH bit5: output buffer has room (THRE-like)
  FSTAT_TX_EMPTY     = $40;   // AH bit6: output buffer empty
  { AL carries modem status (MSR-like): DCD etc. }

type
  { A FOSSIL "client register frame". The door/virtual-COM shim fills AH with
    the function and the in-params, calls FossilDispatch, then reads results.
    Named to mirror the FOSSIL/INT14h register usage, not real CPU registers. }
  TFossilRegs = record
    AH : Byte;      // in: function number
    AL : Byte;      // in/out: char (TX/RX) or sub-code; out: modem status (Fn 03)
    BX : Word;      // out: info (Fn 04 -> maxfunc/ver)
    CX : Word;      // in: block byte count (Fn 18h/19h); out: buffer size etc.
    DX : Word;      // in: port index (DL), or sub-params
    { Block I/O buffer — host analog of the real ES:DI far pointer used by Fn 18h
      (READ_BLOCK) and Fn 19h (WRITE_BLOCK). DOS build maps ES:DI here. Nil if none. }
    Buf : PByte;
    Handled : Boolean;  // set true if the function was recognized
  end;

  { The FOSSIL info block returned by Fn 1Bh (NETMODEM.INC FOSSILStruct). }
  TFossilInfo = packed record
    StrSiz  : Word;    // size of this structure
    MajVer  : Byte;    // 5
    MinVer  : Byte;    // 0
    Ident   : LongInt; // driver ident (-1 in source default)
    IBufr   : Word;    // input buffer size
    IFree   : Word;    // input buffer free
    OBufr   : Word;    // output buffer size
    OFree   : Word;    // output buffer free
    SWidth  : Byte;    // 80
    SHeight : Byte;    // 25
    Baud    : Byte;    // current baud code
  end;

{ Dispatch a FOSSIL INT 14h call against a UART. Returns via the R frame.
  U is the emulated UART whose TX/RX rings carry the bytes. }
procedure FossilDispatch(var U: TUart16550; var R: TFossilRegs);

{ Fill a TFossilInfo for Fn 1Bh from the current UART state. }
procedure FossilGetInfo(const U: TUart16550; out Info: TFossilInfo);

implementation

procedure FossilGetInfo(const U: TUart16550; out Info: TFossilInfo);
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.StrSiz  := SizeOf(TFossilInfo);
  Info.MajVer  := FOSSIL_MAJVER;
  Info.MinVer  := FOSSIL_MINVER;
  Info.Ident   := -1;
  Info.IBufr   := RING_SIZE;
  Info.IFree   := RingFree(U.RX);
  Info.OBufr   := RING_SIZE;
  Info.OFree   := RingFree(U.TX);
  Info.SWidth  := 80;
  Info.SHeight := 25;
  Info.Baud    := 12;  { 115200 / 100 = 1152; FOSSIL byte = 1152 div 100 = 12 }
end;

procedure FossilDispatch(var U: TUart16550; var R: TFossilRegs);
var
  b: Byte;
  n: Word;   // block-transfer byte count (Fn 18h/19h)
  Info: TFossilInfo;   // filled for Fn 1Bh GET_INFO
begin
  R.Handled := True;
  case R.AH of
    FN_INIT:
      begin
        { Fn 04h: initialize FOSSIL. Return the signature doors check.
          Only clear buffers on first init — re-init preserves data. }
        if not U.FifoOn then UartReset(U);  { first init only }
        U.FifoOn := True;  { mark as initialized }
        R.AH := Hi(FOSSIL_SIGNATURE);   // AX = 1954h
        R.AL := Lo(FOSSIL_SIGNATURE);
        R.BX := FOSSIL_INFO_BX;         // 0521h
      end;

    FN_DEINIT:
      begin
        { Fn 05h: deinitialize. }
        UartSetCarrier(U, False);
      end;

    FN_TX_WAIT, FN_TX_NOWAIT:
      begin
        { Fn 01h/0Bh: transmit AL. For nowait, fail (AX=0) if no room. }
        if RingFree(U.TX) > 0 then
        begin
          UartWriteReg(U, UART_THR, R.AL);
          { sent OK }
        end
        else if R.AH = FN_TX_NOWAIT then
        begin
          R.AL := 0;   // signal not sent
        end;
      end;

    FN_RX_WAIT:
      begin
        { Fn 02h: receive a char into AL. Spec says BLOCK until available.
          Spin-wait with Sleep(1) to yield CPU. Timeout if not connected. }
        while (U.RX.Count = 0) and ((U.MSR and MSR_DCD) <> 0) do
          Sleep(1);
        if RingGet(U.RX, b) then
        begin
          R.AL := b;
          R.AH := FSTAT_TX_ROOM;
        end
        else
          R.AL := 0;
        UartRecomputeLSR(U);
      end;

    FN_PEEK:
      begin
        { Fn 0Ch: peek next incoming char without removing it. }
        if U.RX.Count > 0 then
          R.AL := U.RX.Data[U.RX.Tail]
        else
          R.AL := $FF;   // no char
      end;

    FN_GET_STATUS:
      begin
        { Fn 03h: AH = line status (RX ready / TX room), AL = modem status. }
        UartRecomputeLSR(U);
        R.AH := 0;
        if U.RX.Count > 0 then      R.AH := R.AH or FSTAT_RX_READY;
        if RingFree(U.TX) > 0 then  R.AH := R.AH or FSTAT_TX_ROOM;
        if U.TX.Count = 0 then      R.AH := R.AH or FSTAT_TX_EMPTY;
        R.AL := U.MSR;              // modem status (DCD/RI/CTS/DSR)
      end;

    FN_SET_DTR:
      begin
        { Fn 06h: AL=0 lower DTR (hangup), AL=1 raise DTR (ready).
          Per the FOSSIL spec DTR is stateful (cf. ELECOM ComBase Com_SetDtr(State):
          both directions matter). Reflect DTR in the MCR bit, and lower DTR drops
          carrier (the modem hangup semantic). Raising DTR marks the line ready; it
          does NOT itself create carrier (that comes from a real connection), so we
          set the DTR bit but leave carrier to the transport. }
        if R.AL = 0 then
        begin
          U.MCR := U.MCR and (not MCR_DTR);   // DTR low
          UartSetCarrier(U, False);           // hangup
        end
        else
          U.MCR := U.MCR or MCR_DTR;           // DTR high (ready)
      end;

    FN_FLUSH_OUTPUT:
      begin
        { Fn 08h: wait until output buffer empty. On NT the server drains TX;
          we report by leaving TX to be drained. No-op here beyond status. }
        UartRecomputeLSR(U);
      end;

    FN_PURGE_OUTPUT:
      RingClear(U.TX);      // Fn 09h

    FN_PURGE_INPUT:
      begin
        RingClear(U.RX);    // Fn 0Ah
        UartRecomputeLSR(U);
      end;

    FN_GET_INFO:
      begin
        { Fn 1Bh: copy the FOSSIL info structure to the caller's buffer (ES:DI ->
          R.Buf), CX = size of the caller's buffer. Copy min(CX, SizeOf(info))
          bytes and return AX = bytes transferred (spec). Uses the same Buf
          mechanism as block I/O (18h/19h). If no buffer, still report sizes in CX
          and signature in AX for callers that only read registers. }
        FossilGetInfo(U, Info);
        if R.Buf <> nil then
        begin
          n := SizeOf(TFossilInfo);
          if R.CX < n then n := R.CX;        // never write past the caller's buffer
          Move(Info, R.Buf^, n);
          R.AH := Hi(n);                      // AX = bytes transferred
          R.AL := Lo(n);
        end
        else
        begin
          R.CX := RING_SIZE;
          R.AH := Hi(FOSSIL_SIGNATURE);
          R.AL := Lo(FOSSIL_SIGNATURE);
        end;
      end;

    FN_SET_BAUD:
      begin
        { Fn 00h: set baud/line params in AL. Cosmetic over TCP — store it. }
        U.DLL := R.AL;
      end;

    FN_FLOW_CONTROL:
      begin
        { Fn 0Fh: AL in = requested flow-control bits (bit0 XON/XOFF tx, bit1
          CTS/RTS, bit3 XON/XOFF rx). Return AL = flow control actually IN EFFECT.
          Over TCP the transport is reliable and self-pacing, so byte-level flow
          control is neither needed nor applied. Report NONE in effect (AL=0)
          honestly, rather than silently leaving AL undefined — a door reads this
          return to learn what it got. }
        R.AL := 0;
      end;

    FN_READ_BLOCK:
      begin
        { Fn 18h: read up to CX bytes from RX into the caller's buffer (ES:DI ->
          R.Buf). Non-blocking: transfer only what's available. Return the actual
          count in AX. Bounds discipline: never write past CX, stop when RX empty. }
        n := 0;
        if R.Buf <> nil then
          while (n < R.CX) and RingGet(U.RX, b) do
          begin
            (R.Buf + n)^ := b;
            Inc(n);
          end;
        UartRecomputeLSR(U);
        R.AH := Hi(n);   // AX = bytes actually read
        R.AL := Lo(n);
      end;

    FN_WRITE_BLOCK:
      begin
        { Fn 19h: write up to CX bytes from the caller's buffer (ES:DI -> R.Buf)
          into TX. Non-blocking: transfer only while TX has room. Return the actual
          count in AX. Bounds discipline: never read past CX, stop when TX full. }
        n := 0;
        if R.Buf <> nil then
          while (n < R.CX) and (RingFree(U.TX) > 0) do
          begin
            RingPut(U.TX, (R.Buf + n)^);
            Inc(n);
          end;
        UartRecomputeLSR(U);
        R.AH := Hi(n);   // AX = bytes actually written
        R.AL := Lo(n);
      end;

    FN_ANSI_WRITE:
      begin
        { Fn 13h: write string with ANSI processing. Uses Buf/CX like Fn 19h.
          If Buf is nil, write single char from AL (fallback). }
        if (R.Buf <> nil) and (R.CX > 0) then
        begin
          n := 0;
          while n < R.CX do
          begin
            RingPut(U.TX, (R.Buf + n)^);
            Inc(n);
          end;
          R.AH := Hi(n);
          R.AL := Lo(n);
        end
        else
          RingPut(U.TX, R.AL);
      end;

    { ---- X00 SuperSet Extensions (Dedrick Allen) ---- }

    FN_X00_READ:  { $20 — Extended non-blocking read from RX buffer }
      begin
        if UartGuestToNet(U, b) then
        begin
          R.AH := 0;
          R.AL := b;
        end
        else
        begin
          R.AH := $80;  { no data flag }
          R.AL := 0;
        end;
      end;

    FN_X00_INJECT:  { $21 — Write byte INTO RX buffer (keyboard inject) }
      begin
        { VxD checks CK_Checking for Ctrl-C/Ctrl-K intercept.
          We skip that — user-mode doesn't need it. }
        UartNetToGuest(U, R.AL);
      end;

  else
    begin
      { Recognize X00 range plus Dedrick Allen's extended signature
        checks (7Eh/7Fh) as ours. Everything else chains. }
      if R.AH <= $21 then
        R.Handled := True
      else if (R.AH = $7E) or (R.AH = $7F) then
      begin
        { P-5: Extended FOSSIL signature — Dedrick Allen extension.
          Returns AX=1954h, BH=0, BL=input AL. }
        R.BX := Word(R.AL);       { BL = input AL, BH = 0 }
        R.AH := Hi(FOSSIL_SIGNATURE);
        R.AL := Lo(FOSSIL_SIGNATURE);
        R.Handled := True;
      end
      else
        R.Handled := False;
    end;
  end;
end;

end.
