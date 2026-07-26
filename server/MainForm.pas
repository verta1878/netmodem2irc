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

unit MainForm;
{ NetModem/32 — Telnet server, main window.
  Rebuilt in Lazarus from the decompiled original NETMODEM.EXE::TForm1.
  Original used TShortcutBar + TShortcutSheet (Absolute Solutions, proprietary);
  here that left-hand nav is replaced with a free TPageControl + side buttons.
  This is a scaffold: it opens the driver, registers this window, and reacts to
  the CM_* messages. Fill in the transport (NetTransport.pas) to complete it. }

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, Menus, StdCtrls, LMessages,
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  NMVxD, NM_ServerBridge, NM_Node, NM_Debug;

type

  { TfrmMain — the server window (was NETMODEM.EXE TForm1) }
  TfrmMain = class(TForm)
    MainMenu: TMainMenu;
    miFile: TMenuItem;
    miSetup: TMenuItem;
    miExit: TMenuItem;
    NodeList: TListView;         // was TListView: the node/connection list
    StatusBar: TStatusBar;
    RefreshTimer: TTimer;        // was TTimer: status refresh
    TrayIcon: TTrayIcon;         // was TTrayIcon: runs in the system tray
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure RefreshTimerTimer(Sender: TObject);
    procedure miSetupClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
  private
    FDriver: TNetModemDriver;
    FBridge: TServerBridge;
    procedure RefreshNodes;
    {$IFDEF WINDOWS}
    // Intercept the CM_* messages the driver posts to this window.
    procedure WndProc(var Msg: TLMessage); override;
    {$ENDIF}
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  DebugInitFile(ExtractFilePath(Application.ExeName) + 'netmodem_debug.log');
  DebugLog('NMServer', 'FormCreate: enter');
  FDriver := TNetModemDriver.Create;
  DebugLog('NMServer', 'FormCreate: driver created, IsOpen=' + BoolToStr(FDriver.IsOpen, True));
  FBridge := TServerBridge.Create;
  DebugLog('NMServer', 'FormCreate: bridge created');

  if FDriver.IsOpen then
  begin
    {$IFDEF WINDOWS}
    FDriver.RegisterServerWindow(Handle);   // IOCTL 08 — driver posts CM_* here
    {$ENDIF}
    StatusBar.SimpleText := 'Driver connected — NetModem/32 server ready.';
  end
  else
    StatusBar.SimpleText := 'Driver not found (NETMODEM.VXD not loaded).';

  RefreshNodes;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  DebugLog('NMServer', 'FormDestroy: shutting down');
  FBridge.Free;
  DebugLog('NMServer', 'FormDestroy: bridge freed');
  FDriver.Free;
  DebugLog('NMServer', 'FormDestroy: driver freed');
  DebugShutdown;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Original minimized to tray instead of closing; mirror that here later.
  CanClose := True;
end;

procedure TfrmMain.RefreshNodes;
{ Query every active node and update the NodeList display.
  Called on a timer (RefreshTimerTimer) and once on FormCreate.
  The bridge owns the node state; we just read it and show it.
  HAZARD: do not call bridge methods that mutate state here —
  this runs on a timer and must be read-only. }
var
  i: Integer;
  node: TNetModemNode;
  item: TListItem;
begin
  NodeList.Items.BeginUpdate;
  try
    NodeList.Items.Clear;
    for i := 0 to NM_MAX_NODES - 1 do
    begin
      node := FBridge.Nodes.NodeByIndex(i);
      if node <> nil then
      begin
        item := NodeList.Items.Add;
        item.Caption := IntToStr(i);
        if node.Online then
          item.SubItems.Add('ONLINE')
        else
          item.SubItems.Add('IDLE');
        DebugLog('NMServer', 'RefreshNodes: node ' + IntToStr(i) +
          ' online=' + BoolToStr(node.Online, True));
      end;
    end;
  finally
    NodeList.Items.EndUpdate;
  end;
end;

procedure TfrmMain.RefreshTimerTimer(Sender: TObject);
begin
  RefreshNodes;
end;

procedure TfrmMain.miSetupClick(Sender: TObject);
{ Launch the external NMConfig.exe configuration app.
  The original did the same — NETMODEM.EXE launched NETMODEM.CPL.
  We launch NMConfig.exe from the same directory as NMServer.exe.
  HAZARD: ShellExecute is NT+ only; on Win9x use WinExec.
  Both are in the Windows unit. }
{$IFDEF WINDOWS}
var
  ConfigPath: String;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  ConfigPath := ExtractFilePath(Application.ExeName) + 'NMConfig.exe';
  if FileExists(ConfigPath) then
  begin
    DebugLog('NMServer', 'miSetupClick: launching ' + ConfigPath);
    { WinExec works on Win98 through Win11. ShellExecute needs shell32. }
    WinExec(PChar(ConfigPath), SW_SHOWNORMAL);
  end
  else
    DebugLog('NMServer', 'miSetupClick: NMConfig.exe not found at ' + ConfigPath);
  {$ENDIF}
end;

procedure TfrmMain.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.TrayIconDblClick(Sender: TObject);
begin
  Show; WindowState := wsNormal;
end;

{$IFDEF WINDOWS}
procedure TfrmMain.WndProc(var Msg: TLMessage);
begin
  case Msg.Msg of
    CM_CONNECT_NODE:
      begin
        { The driver says a node is going online — a caller connected via
          the virtual COM port. Route to the bridge, which creates the node,
          assigns a socket link, and starts Telnet negotiation.
          WParam low byte = node index (0..98). }
        DebugLog('NMServer', 'CM_CONNECT_NODE node=' + IntToStr(Msg.WParam and $FF));
        FBridge.OnConnectNode(Msg.WParam and $FF);
        RefreshNodes;
      end;
    CM_DISCONNECT_NODE:
      begin
        { Node hung up — close its socket and remove it from the manager. }
        DebugLog('NMServer', 'CM_DISCONNECT_NODE node=' + IntToStr(Msg.WParam and $FF));
        FBridge.OnDisconnectNode(Msg.WParam and $FF);
        RefreshNodes;
      end;
    CM_SEND_REMOTE_BREAK:
      begin
        { The BBS sent a BREAK — forward it as a Telnet BREAK to the remote. }
        DebugLog('NMServer', 'CM_SEND_REMOTE_BREAK node=' + IntToStr(Msg.WParam and $FF));
        FBridge.OnSendRemoteBreak(Msg.WParam and $FF);
      end;
    CM_WILL_BINARY:
      begin
        { Driver requests Telnet BINARY mode on. }
        DebugLog('NMServer', 'CM_WILL_BINARY node=' + IntToStr(Msg.WParam and $FF));
        FBridge.OnBinary(Msg.WParam and $FF, True);
      end;
    CM_WONT_BINARY:
      begin
        { Driver reports Telnet BINARY mode off. Informational — our transport
          always negotiates BINARY on connect and stays in it. }
        DebugLog('NMServer', 'CM_WONT_BINARY node=' + IntToStr(Msg.WParam and $FF));
        FBridge.OnBinary(Msg.WParam and $FF, False);
      end;
  end;
  inherited WndProc(Msg);
end;
{$ENDIF}

end.
