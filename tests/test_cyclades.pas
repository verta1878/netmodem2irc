{ ===========================================================================
  test_cyclades — Cyclades CD1400 Integration Test Suite
  GPLv3 — Copyright (C) 2026 wrench (netmodem2irc)
  ---------------------------------------------------------------------------
  Tests cd1400_regs.pas constants, cy_fossil_bridge.pas operations,
  and multi-port node management.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program test_cyclades;

uses
  SysUtils, cd1400_regs, cy_fossil_bridge, NM_UART16550;

var
  Passed, Failed: Integer;

procedure Check(const Name: string; Condition: Boolean);
begin
  if Condition then Inc(Passed)
  else begin Inc(Failed); WriteLn('  FAIL: ', Name); end;
end;

{ Phase 1: Register constants }
procedure TestRegisters;
begin
  WriteLn('Phase 1: Register Constants');
  Check('CyCAR = $D0', CyCAR = $D0);
  Check('CyGFRCR = $80', CyGFRCR = $80);
  Check('CySVRR = $CE', CySVRR = $CE);
  Check('CyTDR = $C6', CyTDR = $C6);
  Check('CyRDSR = $C4', CyRDSR = $C4);
  Check('CyEOSRR = $C0', CyEOSRR = $C0);
  Check('CyCCR = $0A', CyCCR = $0A);
  Check('CySRER = $0C', CySRER = $0C);
  Check('CyMSVR1 = $D8', CyMSVR1 = $D8);
  Check('CyMSVR2 = $DA', CyMSVR2 = $DA);
  Check('CyCOR1 = $10', CyCOR1 = $10);
  Check('CyCOR2 = $12', CyCOR2 = $12);
  Check('CyCOR3 = $14', CyCOR3 = $14);
  Check('CyRBPR = $F0', CyRBPR = $F0);
  Check('CyTBPR = $E4', CyTBPR = $E4);
  Check('CY_MAX_PORTS = 32', CY_MAX_PORTS = 32);
  Check('CY_MAX_CHAR_FIFO = 12', CY_MAX_CHAR_FIFO = 12);
end;

{ Phase 2: Baud rate indices }
procedure TestBaudRates;
begin
  WriteLn('Phase 2: Baud Rate Indices');
  Check('50 baud = 0', CY_BAUD_50 = 0);
  Check('9600 baud = 12', CY_BAUD_9600 = 12);
  Check('115200 baud = 17', CY_BAUD_115200 = 17);
  Check('230400 baud = 19', CY_BAUD_230400 = 19);
  Check('Count = 20', CY_BAUD_COUNT = 20);
end;

{ Phase 3: Modem signal bits }
procedure TestModemBits;
begin
  WriteLn('Phase 3: Modem Signal Bits');
  Check('DCD = $10', CyDCD = $10);
  Check('CTS = $40', CyCTS = $40);
  Check('DSR = $80', CyDSR = $80);
  Check('RI = $20', CyRI = $20);
  Check('DTR = $02', CyDTR = $02);
  Check('RTS = $01', CyRTS = $01);
end;

{ Phase 4: Bridge init }
procedure TestBridgeInit;
var Mgr: TCycladesManager; B: Byte;
begin
  WriteLn('Phase 4: Bridge Init');
  Mgr := TCycladesManager.Create;
  Check('Create OK', Mgr <> nil);
  Check('Init 8 ports', Mgr.Init(CY_DEFAULT_MEMBASE, 8));
  Check('ChipCount = 2', Mgr.ChipCount = 2);
  Check('PortCount = 8', Mgr.PortCount = 8);
  Check('MemBase = $D4000', Mgr.MemBase = CY_DEFAULT_MEMBASE);
  Mgr.Free;
end;

{ Phase 5: Port enable/disable }
procedure TestPortLifecycle;
var
  Mgr: TCycladesManager;
  P: PCyPortBridge;
begin
  WriteLn('Phase 5: Port Lifecycle');
  Mgr := TCycladesManager.Create;
  Mgr.Init(CY_DEFAULT_MEMBASE, 8);

  Mgr.EnablePort(0, 9600, 0);
  P := Mgr.GetPort(0);
  Check('Port 0 enabled', P^.Enabled);
  Check('Port 0 baud = 9600', P^.BaudIndex = CY_BAUD_9600);
  Check('Port 0 DTR up', P^.DTRState);

  Mgr.EnablePort(7, 115200, 2);
  P := Mgr.GetPort(7);
  Check('Port 7 enabled', P^.Enabled);
  Check('Port 7 baud = 115200', P^.BaudIndex = CY_BAUD_115200);
  Check('Port 7 flow = XON/XOFF', P^.FlowControl = 2);

  Mgr.DisablePort(0);
  P := Mgr.GetPort(0);
  Check('Port 0 disabled', not P^.Enabled);
  Check('Port 0 DTR down', not P^.DTRState);

  Mgr.Free;
end;

{ Phase 6: Data transfer }
procedure TestDataTransfer;
var
  Mgr: TCycladesManager;
  TxBuf, RxBuf: array[0..15] of Byte;
  i, Got: Integer;
begin
  WriteLn('Phase 6: Data Transfer');
  Mgr := TCycladesManager.Create;
  Mgr.Init(CY_DEFAULT_MEMBASE, 4);
  Mgr.EnablePort(0, 9600, 0);

  { Net → Port (simulate incoming TCP data) }
  for i := 0 to 7 do TxBuf[i] := $41 + i;  { ABCDEFGH }
  Mgr.NetToPort(0, TxBuf, 8);
  Check('Carrier up after data', Mgr.GetDCD(0));

  { Port → Net is the BBS TX path — write via UART }
  UartWriteReg(Mgr.GetPort(0)^.Uart, UART_THR, $5A);  { 'Z' }
  Got := Mgr.PortToNet(0, RxBuf, 16);
  Check('PortToNet got 1 byte', Got = 1);
  Check('PortToNet byte = Z', RxBuf[0] = $5A);

  Mgr.Free;
end;

{ Phase 7: DTR hangup }
procedure TestDTRHangup;
var Mgr: TCycladesManager; B: Byte;
begin
  WriteLn('Phase 7: DTR Hangup');
  Mgr := TCycladesManager.Create;
  Mgr.Init(CY_DEFAULT_MEMBASE, 4);
  Mgr.EnablePort(0, 9600, 0);

  Mgr.SetDTR(0, True);
  Check('DTR on', Mgr.GetPort(0)^.DTRState);

  B := $41; Mgr.NetToPort(0, B, 1);
  Check('DCD up', Mgr.GetDCD(0));

  Mgr.SetDTR(0, False);
  Check('DTR off', not Mgr.GetPort(0)^.DTRState);
  Check('DCD down (DTR drop = hangup)', not Mgr.GetDCD(0));

  Mgr.Free;
end;

{ Phase 8: 32-port stress }
procedure TestMultiPort;
var
  Mgr: TCycladesManager;
  i: Integer;
  B: Byte;
begin
  WriteLn('Phase 8: Multi-Port (32 ports)');
  Mgr := TCycladesManager.Create;
  Check('Init 32 ports', Mgr.Init(CY_DEFAULT_MEMBASE, 32));
  Check('ChipCount = 8', Mgr.ChipCount = 8);
  Check('PortCount = 32', Mgr.PortCount = 32);

  for i := 0 to 31 do
    Mgr.EnablePort(i, 9600, 0);
  Check('All 32 enabled', Mgr.GetPort(31)^.Enabled);

  { Send different byte to each port }
  for i := 0 to 31 do
  begin
    B := Byte(i + $30);
    Mgr.NetToPort(i, B, 1);
  end;
  Check('Port 0 has data', Mgr.GetPort(0)^.Uart.RX.Count > 0);
  Check('Port 31 has data', Mgr.GetPort(31)^.Uart.RX.Count > 0);

  Mgr.Free;
end;

begin
  Passed := 0;
  Failed := 0;
  WriteLn('=== Cyclades CD1400 Integration Test Suite ===');
  WriteLn;

  TestRegisters;
  TestBaudRates;
  TestModemBits;
  TestBridgeInit;
  TestPortLifecycle;
  TestDataTransfer;
  TestDTRHangup;
  TestMultiPort;

  WriteLn;
  WriteLn('TOTAL: ', Passed, ' passed, ', Failed, ' failed');
  if Failed = 0 then WriteLn('ALL TESTS PASSED')
  else WriteLn('*** ', Failed, ' FAILURES ***');
  if Failed > 0 then Halt(1);
end.
