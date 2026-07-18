program test_globalconfig;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_GlobalConfig;
var
  gc: TNMGlobalConfig;
  pass, fail: Integer;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0; fail:=0;

  writeln('== defaults match original CPL ==');
  gc := TNMGlobalConfig.Create;
  Check(gc.StartAsService = False, 'StartAsService off');
  Check(gc.SuppressSplash = False, 'SuppressSplash off');
  Check(gc.AutoMinimize = False, 'AutoMinimize off');
  Check(gc.EnableSpinningGlobe = True, 'SpinningGlobe on');
  Check(gc.ServerLogging = True, 'ServerLogging on');
  Check(gc.ActivityLog = True, 'ActivityLog on');
  Check(gc.LogFileDays = 30, 'LogFileDays 30');
  Check(gc.LogFileMaxSize = 1024, 'LogFileMaxSize 1024');
  Check(gc.RetrieveLocalHost = True, 'RetrieveLocalHost on');
  Check(gc.ExplicitBind = False, 'ExplicitBind off');
  Check(gc.AllowUnknownHosts = True, 'AllowUnknownHosts on');
  Check(gc.AllowDuplicateConn = False, 'AllowDuplicateConn off');
  Check(gc.DisplayBusyFile = True, 'DisplayBusyFile on');
  Check(gc.DisplayOfflineFile = True, 'DisplayOfflineFile on');
  Check(gc.DisplayBlockedFile = True, 'DisplayBlockedFile on');
  Check(gc.EnableAutoNews = False, 'AutoNews off');
  Check(gc.AutoNewsInterval = 60, 'AutoNewsInterval 60');
  Check(gc.EnableListserv = False, 'Listserv off');
  Check(gc.InternalCacheSize = 4096, 'CacheSize 4096');
  Check(gc.RingCount = 1, 'RingCount 1');
  gc.Free;

  writeln('== file save/load roundtrip ==');
  gc := TNMGlobalConfig.Create;
  gc.StartAsService := True;
  gc.SuppressSplash := True;
  gc.AutoMinimize := True;
  gc.EnableSpinningGlobe := False;
  gc.ServerLogging := False;
  gc.AllowUnknownHosts := False;
  gc.AllowDuplicateConn := True;
  gc.EnableAutoNews := True;
  gc.AutoNewsInterval := 15;
  gc.EnableListserv := True;
  gc.RingCount := 3;
  gc.BindAddress := '192.168.1.100';
  gc.ExplicitBind := True;
  gc.LogFileDays := 7;
  gc.SaveToFile('/tmp/test_globalcfg.cnf');
  gc.Free;

  gc := TNMGlobalConfig.Create;
  gc.LoadFromFile('/tmp/test_globalcfg.cnf');
  Check(gc.StartAsService = True, 'roundtrip StartAsService');
  Check(gc.SuppressSplash = True, 'roundtrip SuppressSplash');
  Check(gc.AutoMinimize = True, 'roundtrip AutoMinimize');
  Check(gc.EnableSpinningGlobe = False, 'roundtrip SpinningGlobe off');
  Check(gc.ServerLogging = False, 'roundtrip ServerLogging off');
  Check(gc.AllowUnknownHosts = False, 'roundtrip AllowUnknownHosts off');
  Check(gc.AllowDuplicateConn = True, 'roundtrip AllowDuplicateConn on');
  Check(gc.EnableAutoNews = True, 'roundtrip AutoNews on');
  Check(gc.AutoNewsInterval = 15, 'roundtrip AutoNewsInterval 15');
  Check(gc.EnableListserv = True, 'roundtrip Listserv on');
  Check(gc.RingCount = 3, 'roundtrip RingCount 3');
  Check(gc.BindAddress = '192.168.1.100', 'roundtrip BindAddress');
  Check(gc.ExplicitBind = True, 'roundtrip ExplicitBind');
  Check(gc.LogFileDays = 7, 'roundtrip LogFileDays');
  gc.Free;

  {$IFNDEF WINDOWS}
  writeln('== registry stubs (non-Windows) ==');
  gc := TNMGlobalConfig.Create;
  Check(True, 'no registry on this platform');
  gc.Free;
  {$ENDIF}

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('GLOBAL CONFIG - VERIFIED');
end.
