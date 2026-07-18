program test_config;
{$MODE OBJFPC}{$H+}
{ Config parsing — matches original CPL fields 1:1.
  All per-node ComportStruct fields tested. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_Config;
var
  cfg: TNMConfig; pass,fail: Integer; c: TNodeConfig;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;

begin
  pass:=0;fail:=0;

  writeln('== happy path: all fields ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 1 comport 3 baud 38400 mode fossil port 23 base $03E8 buffer 2048 alwaysactive 0 lockedbaud 1 timeslice 1 enabled 1'), 'full line accepted');
  Check(cfg.GetNode(1, c), 'node 1 found');
  Check(c.ComPort = 3, 'comport 3');
  Check(c.Baud = 38400, 'baud 38400');
  Check(c.Mode = nmFossil, 'mode fossil');
  Check(c.InternetPort = 23, 'port 23');
  Check(c.BaseAddress = $03E8, 'base $03E8');
  Check(c.BufferSize = 2048, 'buffer 2048');
  Check(c.AlwaysActive = False, 'alwaysactive 0');
  Check(c.LockedBaudRate = True, 'lockedbaud 1');
  Check(c.ManageTimeSlice = True, 'timeslice 1');
  Check(c.Enabled = True, 'enabled 1');
  cfg.Free;

  writeln('== shorthand: just comport, all defaults ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 5 comport 5'), 'shorthand accepted');
  Check(cfg.GetNode(5, c), 'node 5 found');
  Check(c.Baud = 38400, 'default baud 38400');
  Check(c.Mode = nmFossil, 'default fossil');
  Check(c.InternetPort = 23, 'default port 23');
  Check(c.BaseAddress = $03E8, 'default base $03E8');
  Check(c.BufferSize = 2048, 'default buffer 2048');
  Check(c.AlwaysActive = False, 'default alwaysactive off');
  Check(c.LockedBaudRate = True, 'default lockedbaud on');
  Check(c.ManageTimeSlice = True, 'default timeslice on');
  Check(c.Enabled = True, 'default enabled');
  cfg.Free;

  writeln('== CPL baud rates: all 14 valid ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 1 comport 3 baud 300'), '300');
  Check(cfg.ParseLine('node 2 comport 4 baud 1200'), '1200');
  Check(cfg.ParseLine('node 3 comport 5 baud 2400'), '2400');
  Check(cfg.ParseLine('node 4 comport 6 baud 9600'), '9600');
  Check(cfg.ParseLine('node 5 comport 7 baud 14400'), '14400');
  Check(cfg.ParseLine('node 6 comport 8 baud 16800'), '16800');
  Check(cfg.ParseLine('node 7 comport 9 baud 19200'), '19200');
  Check(cfg.ParseLine('node 8 comport 10 baud 21600'), '21600');
  Check(cfg.ParseLine('node 9 comport 11 baud 28800'), '28800');
  Check(cfg.ParseLine('node 10 comport 12 baud 33600'), '33600');
  Check(cfg.ParseLine('node 11 comport 13 baud 38400'), '38400');
  Check(cfg.ParseLine('node 12 comport 14 baud 57600'), '57600');
  Check(cfg.ParseLine('node 13 comport 15 baud 64000'), '64000');
  Check(cfg.ParseLine('node 14 comport 16 baud 115200'), '115200');
  Check(not cfg.ParseLine('node 15 comport 17 baud 12345'), 'invalid baud rejected');
  cfg.Free;

  writeln('== boundary: port 1..65535 ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 1 comport 3 port 1'), 'port 1 ok');
  Check(cfg.ParseLine('node 2 comport 4 port 65535'), 'port 65535 ok');
  Check(not cfg.ParseLine('node 3 comport 5 port 0'), 'port 0 rejected');
  Check(not cfg.ParseLine('node 4 comport 6 port 65536'), 'port 65536 rejected');
  cfg.Free;

  writeln('== boundary: buffer 1024..8192 ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 1 comport 3 buffer 1024'), 'buffer 1024 ok');
  Check(cfg.ParseLine('node 2 comport 4 buffer 8192'), 'buffer 8192 ok');
  Check(not cfg.ParseLine('node 3 comport 5 buffer 512'), 'buffer 512 rejected');
  Check(not cfg.ParseLine('node 4 comport 6 buffer 9000'), 'buffer 9000 rejected');
  cfg.Free;

  writeln('== boundary: node index and comport ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 0 comport 1'), 'index 0 ok');
  Check(cfg.ParseLine('node 98 comport 99'), 'index 98 ok');
  Check(not cfg.ParseLine('node 99 comport 3'), 'index 99 rejected');
  Check(not cfg.ParseLine('node -1 comport 3'), 'index -1 rejected');
  Check(not cfg.ParseLine('node 1 comport 0'), 'comport 0 rejected');
  Check(not cfg.ParseLine('node 2 comport 100'), 'comport 100 rejected');
  cfg.Free;

  writeln('== comments and blanks ==');
  cfg := TNMConfig.Create;
  cfg.ParseLine('; comment');
  cfg.ParseLine('# comment');
  cfg.ParseLine('');
  Check(cfg.NodeCount = 0, 'no nodes');
  Check(cfg.IsValid, 'no errors');
  cfg.Free;

  writeln('== multi-line ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseText(
    '; my board' + #10 +
    'node 1 comport 3 baud 38400 mode fossil port 23' + #10 +
    'node 2 comport 4 baud 57600 mode uart port 6667' + #10 +
    '# end') = 2, '2 nodes loaded');
  Check(cfg.GetNode(2, c) and (c.Baud = 57600) and (c.Mode = nmUart) and (c.InternetPort = 6667), 'node 2 correct');
  cfg.Free;

  writeln('== update (last wins) ==');
  cfg := TNMConfig.Create;
  cfg.ParseLine('node 4 comport 3 baud 19200');
  cfg.ParseLine('node 4 comport 5 baud 57600 port 2323');
  Check(cfg.NodeCount = 1, 'one node');
  Check(cfg.GetNode(4, c) and (c.ComPort = 5) and (c.Baud = 57600) and (c.InternetPort = 2323), 'updated');
  cfg.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('CONFIG - VERIFIED');
end.
