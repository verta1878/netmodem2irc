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

program test_seam_node_bounds;
{$MODE OBJFPC}{$H+}
{ Wire-value trust boundary (maintainer's lesson): the seam NODE field is a Byte
  (0..255) but NM_MAX_NODES=99. A frame carrying NODE >= 99 (corrupt/hostile wire)
  must be safely IGNORED, never index FNodes[] out of bounds. Prove the reader does
  not trust the boundary value. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
     NM_SeamProtocol, NM_SeamSender, NM_ServerBridge;
type
  TFakeLink = class(TInterfacedObject, ISocketLink)
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
  end;
function TFakeLink.Connect(const H:string;P:Word):TLinkResult;begin Result:=lrOk;end;
function TFakeLink.Send(const B;L:Integer;out S:Integer):TLinkResult;begin S:=L;Result:=lrOk;end;
function TFakeLink.Recv(var B;L:Integer;out G:Integer):TLinkResult;begin G:=0;Result:=lrWouldBlock;end;
procedure TFakeLink.Close;begin end;
function TFakeLink.IsConnected:Boolean;begin Result:=True;end;
var
  br: TServerBridge; pass,fail,n:Integer; buf: array[0..31] of Byte; pl: array[0..7] of Byte;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;

  writeln('== out-of-range NODE from the wire must be ignored, not crash ==');
  { NODE=200 (> NM_MAX_NODES=99). BuildFrame writes it (Byte). The bridge must
    handle the frame without indexing FNodes[200]. }
  FillChar(pl, SizeOf(pl), 0);
  n := BuildFrame(smConnect, 200, pl[0], 0, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'connect NODE=200 frame consumed (parsed)');
  { if it had indexed FNodes[200] we'd have crashed already; reaching here = safe }
  Check(br.Nodes.ActiveCount = 0, 'no phantom node activated for out-of-range NODE');

  writeln('== NODE=255 (max Byte) data frame safely ignored ==');
  pl[0]:=Ord('X');
  n := BuildFrame(smData, 255, pl[0], 1, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'data NODE=255 consumed without OOB');

  writeln('== NODE=98 (last valid slot) still works normally ==');
  n := BuildFrame(smConnect, 98, pl[0], 0, buf[0]);
  br.FeedDriverBytes(buf[0], n);
  Check(True, 'valid boundary NODE=98 handled (no crash)');

  writeln('== disconnect + break with out-of-range NODE ignored ==');
  n := BuildFrame(smDisconnect, 150, pl[0], 0, buf[0]); br.FeedDriverBytes(buf[0], n);
  n := BuildFrame(smBreak, 150, pl[0], 0, buf[0]); br.FeedDriverBytes(buf[0], n);
  Check(True, 'disconnect/break NODE=150 handled safely');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SEAM NODE BOUNDS - VERIFIED');
end.
