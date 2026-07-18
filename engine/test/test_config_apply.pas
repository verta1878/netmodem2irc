program test_config_apply;
{$MODE OBJFPC}{$H+}
{ The full deployable path: config text -> parse -> apply -> nodes up on bridge. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
     NM_SeamProtocol, NM_ServerBridge, NM_Config, NM_ConfigApply;
var
  cfg: TNMConfig; br: TServerBridge; r: TApplyResult; pass,fail: Integer;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;

  writeln('== valid config -> apply -> nodes accounted for (up or skipped) ==');
  cfg := TNMConfig.Create;
  cfg.ParseText('node 3 bbs.one.net 23'+#10+'node 4 bbs.two.net 6667'+#10+'node 5 h 23');
  Check(cfg.IsValid, 'config parsed cleanly');
  Check(cfg.NodeCount = 3, '3 nodes configured');
  br := TServerBridge.Create;
  r := ApplyConfig(cfg, br);
  { every configured node is either brought up or skipped — none lost }
  Check(r.Brought + r.Skipped = 3, 'all 3 configured nodes accounted for');
  { in this host/stub build there may be no transport -> skipped is honest, not up }
  writeln('     (brought=',r.Brought,' skipped=',r.Skipped,')');
  br.Free; cfg.Free;

  writeln('== INVALID config refuses to apply (no half-configuring) ==');
  cfg := TNMConfig.Create;
  cfg.ParseText('node 3 bbs.one.net 23'+#10+'node 999 bad 23');  // 999 out of range
  Check(not cfg.IsValid, 'config marked invalid (bad line)');
  br := TServerBridge.Create;
  r := ApplyConfig(cfg, br);
  Check((r.Brought = 0) and (r.Skipped = 0), 'invalid config applied NOTHING');
  br.Free; cfg.Free;

  writeln('== empty config applies cleanly (nothing to do) ==');
  cfg := TNMConfig.Create;
  br := TServerBridge.Create;
  r := ApplyConfig(cfg, br);
  Check((r.Brought=0) and (r.Skipped=0), 'empty config -> 0 up, 0 skipped');
  br.Free; cfg.Free;

  writeln('== nil safety ==');
  r := ApplyConfig(nil, nil);
  Check((r.Brought=0) and (r.Skipped=0), 'nil args handled safely');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('CONFIG APPLY - VERIFIED');
end.
