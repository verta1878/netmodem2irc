program test_config;
{$MODE OBJFPC}{$H+}
{ Config parsing + validation, with boundary discipline: node index and port
  tested AT their limits, bad input must be REJECTED (not silently accepted). }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_Config;
var
  cfg: TNMConfig; pass,fail: Integer; c: TNodeConfig;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;

begin
  pass:=0;fail:=0;

  writeln('== happy path: a valid node line parses ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 3 bbs.example.com 23'), 'valid line accepted');
  Check(cfg.NodeCount = 1, 'one node loaded');
  Check(cfg.GetNode(3, c), 'node 3 found');
  Check((c.Host='bbs.example.com') and (c.Port=23) and (c.NodeIndex=3), 'fields correct');
  Check(cfg.IsValid, 'config valid (no errors)');
  cfg.Free;

  writeln('== comments and blanks are ignored, not errors ==');
  cfg := TNMConfig.Create;
  cfg.ParseLine('; this is a comment');
  cfg.ParseLine('# also a comment');
  cfg.ParseLine('');
  cfg.ParseLine('   ');
  Check(cfg.NodeCount = 0, 'no nodes from comments/blanks');
  Check(cfg.IsValid, 'comments/blanks produce no errors');
  cfg.Free;

  writeln('== BOUNDARY: node index 0 and 98 valid, 99 and -1 rejected ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 0 h 23'),  'index 0 (min) accepted');
  Check(cfg.ParseLine('node 98 h 23'), 'index 98 (max valid) accepted');
  Check(not cfg.ParseLine('node 99 h 23'),  'index 99 (== NM_MAX_NODES) REJECTED');
  Check(not cfg.ParseLine('node -1 h 23'),  'index -1 REJECTED');
  Check(cfg.ErrorCount = 2, 'exactly 2 range errors recorded');
  Check(not cfg.IsValid, 'config invalid when a line was bad');
  cfg.Free;

  writeln('== BOUNDARY: port 1 and 65535 valid, 0 and 65536 rejected ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseLine('node 5 h 1'),     'port 1 (min) accepted');
  Check(cfg.ParseLine('node 6 h 65535'), 'port 65535 (max) accepted');
  Check(not cfg.ParseLine('node 7 h 0'),     'port 0 REJECTED');
  Check(not cfg.ParseLine('node 8 h 65536'), 'port 65536 (past Word) REJECTED');
  cfg.Free;

  writeln('== malformed lines rejected with errors, not silently swallowed ==');
  cfg := TNMConfig.Create;
  Check(not cfg.ParseLine('node 3 onlythree'),      'too few fields rejected');
  Check(not cfg.ParseLine('node 3 h 23 extra'),     'too many fields rejected');
  Check(not cfg.ParseLine('node abc h 23'),         'non-numeric index rejected');
  Check(not cfg.ParseLine('node 3 h notaport'),     'non-numeric port rejected');
  Check(not cfg.ParseLine('frobnicate 3 h 23'),     'unknown keyword rejected');
  Check(cfg.ErrorCount = 5, 'all 5 bad lines recorded as errors');
  cfg.Free;

  writeln('== ParseText: whole multi-line config ==');
  cfg := TNMConfig.Create;
  Check(cfg.ParseText(
    '; my board' + #10 +
    'node 1 bbs.one.net 23' + #10 +
    'node 2 bbs.two.net 6667' + #10 +
    '# end') = 2, 'ParseText loaded 2 nodes');
  Check(cfg.GetNode(2, c) and (c.Port=6667), 'node 2 port 6667 correct');
  Check(cfg.IsValid, 'multi-line config valid');
  cfg.Free;

  writeln('== redefining a node updates it (last wins) ==');
  cfg := TNMConfig.Create;
  cfg.ParseLine('node 4 old.host 23');
  cfg.ParseLine('node 4 new.host 24');
  Check(cfg.NodeCount = 1, 'still one node (updated, not duplicated)');
  Check(cfg.GetNode(4, c) and (c.Host='new.host') and (c.Port=24), 'node 4 updated to new values');
  cfg.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('CONFIG - VERIFIED');
end.
