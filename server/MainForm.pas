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
  NMVxD, NM_ServerBridge, NM_Node, NM_Debug, NM_DebugView;

type

  { TfrmMain — the server window (was NETMODEM.EXE TForm1) }
  TfrmMain = class(TForm)
    MainMenu: TMainMenu;
    miFile: TMenuItem;
    miSetup: TMenuItem;
    miExit: TMenuItem;
    miDebug: TMenuItem;          { R1.5: toggle debug panel }
    miLEDs: TMenuItem;           { toggle LED panel }
    NodeList: TListView;         // was TListView: the node/connection list
    StatusBar: TStatusBar;
    RefreshTimer: TTimer;        // was TTimer: status refresh
    TrayIcon: TTrayIcon;         // was TTrayIcon: runs in the system tray
    DebugSplitter: TSplitter;    { R1.5: resizable split between node list + debug }
    DebugMemo: TMemo;            { R1.5: debug output panel }
    LEDPanel: TPanel;            { USR Courier LED panel }
    LEDLabel: TLabel;            { LED state display }
    LEDTimer: TTimer;            { LED refresh timer (200ms) }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure RefreshTimerTimer(Sender: TObject);
    procedure miSetupClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miDebugClick(Sender: TObject);
    procedure miLEDsClick(Sender: TObject);
    procedure LEDTimerTimer(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
  private
    FDriver: TNetModemDriver;
    FBridge: TServerBridge;
    FDebugVisible: Boolean;
    FLEDVisible: Boolean;
    FDebugViewer: TDebugViewer;  { protocol analyzer with LED state }
    procedure RefreshNodes;
    { R1.5: callback from NM_Debug — receives every debug line }
    procedure OnDebugLine(const Subsystem, Msg, FormattedLine: string);
    { R1.6: color-code a subsystem tag }
    procedure AppendDebugLine(const Subsystem, Msg: string);
    { LED panel refresh }
    procedure RefreshLEDs;
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

  { R1.5: Create the debug panel — docked to bottom, hidden by default.
    The TMemo shows live debug output from every subsystem.
    Toggle with View > Debug Panel (or the miDebug menu item). }
  DebugMemo := TMemo.Create(Self);
  DebugMemo.Parent := Self;
  DebugMemo.Align := alBottom;
  DebugMemo.Height := 180;
  DebugMemo.ReadOnly := True;
  DebugMemo.ScrollBars := ssVertical;
  DebugMemo.Font.Name := 'Consolas';
  DebugMemo.Font.Size := 9;
  DebugMemo.WordWrap := False;
  DebugMemo.Visible := False;    { hidden by default — toggle with miDebug }

  DebugSplitter := TSplitter.Create(Self);
  DebugSplitter.Parent := Self;
  DebugSplitter.Align := alBottom;
  DebugSplitter.Height := 4;
  DebugSplitter.Visible := False;

  FDebugVisible := False;

  { R1.5: Wire the NM_Debug line handler so all debug output
    flows to the panel in real time. }
  DebugSetLineHandler(@OnDebugLine);

  { R1.5: Add Debug toggle to the menu }
  miDebug := TMenuItem.Create(MainMenu);
  miDebug.Caption := '&Debug Panel';
  miDebug.OnClick := @miDebugClick;
  miFile.Add(miDebug);

  { LED Panel — USR Courier modem front panel, docked to top }
  LEDPanel := TPanel.Create(Self);
  LEDPanel.Parent := Self;
  LEDPanel.Align := alTop;
  LEDPanel.Height := 60;
  LEDPanel.Color := $1A1A1A;       { dark background like a modem case }
  LEDPanel.BevelOuter := bvLowered;
  LEDPanel.Visible := False;       { hidden by default }

  LEDLabel := TLabel.Create(LEDPanel);
  LEDLabel.Parent := LEDPanel;
  LEDLabel.Align := alClient;
  LEDLabel.Alignment := taCenter;
  { LEDLabel.Layout := tlCenter; } { not available in nogui }
  LEDLabel.Font.Name := 'Consolas';
  LEDLabel.Font.Size := 10;
  LEDLabel.Font.Color := $C8C8C8;  { light gray text }
  LEDLabel.Caption := 'US Robotics  NetModem/32  Virtual Modem';

  LEDTimer := TTimer.Create(Self);
  LEDTimer.Interval := 200;        { refresh LEDs every 200ms }
  LEDTimer.OnTimer := @LEDTimerTimer;
  LEDTimer.Enabled := False;

  FLEDVisible := False;

  { Add LED toggle to the menu }
  miLEDs := TMenuItem.Create(MainMenu);
  miLEDs.Caption := '&Modem LEDs';
  miLEDs.OnClick := @miLEDsClick;
  miFile.Add(miLEDs);

  { Create the debug viewer (protocol analyzer) for node 0 }
  FDebugViewer := TDebugViewer.Create(0);
  FDebugViewer.Attach;

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
  FDebugViewer.Free;
  DebugLog('NMServer', 'FormDestroy: debug viewer freed');
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

procedure TfrmMain.miLEDsClick(Sender: TObject);
{ Toggle the USR Courier LED panel visibility. }
begin
  FLEDVisible := not FLEDVisible;
  LEDPanel.Visible := FLEDVisible;
  LEDTimer.Enabled := FLEDVisible;
  if FLEDVisible then
  begin
    miLEDs.Caption := 'Hide &Modem LEDs';
    RefreshLEDs;
    DebugLog('NMServer', 'LED panel opened');
  end
  else
    miLEDs.Caption := 'Show &Modem LEDs';
end;

procedure TfrmMain.LEDTimerTimer(Sender: TObject);
{ Called every 200ms to refresh LED state. }
begin
  RefreshLEDs;
end;

procedure TfrmMain.RefreshLEDs;
{ Update the LED panel with current modem state.
  Reads from the DebugViewer which tracks UART state. }
var
  S: String;
begin
  if not FLEDVisible then Exit;
  if FDebugViewer = nil then Exit;

  { LED line: [*]=on [ ]=off [~]=activity }
  S := FDebugViewer.FormatModemLEDs;

  { Also add throughput if we have a session }
  S := S + #13#10 + FDebugViewer.FormatModemHuman;

  LEDLabel.Caption := S;
end;

procedure TfrmMain.miDebugClick(Sender: TObject);
{ R1.5: Toggle the debug panel visibility. }
begin
  FDebugVisible := not FDebugVisible;
  DebugMemo.Visible := FDebugVisible;
  DebugSplitter.Visible := FDebugVisible;
  if FDebugVisible then
  begin
    miDebug.Caption := 'Hide &Debug Panel';
    DebugLog('NMServer', 'Debug panel opened');
  end
  else
    miDebug.Caption := 'Show &Debug Panel';
end;

procedure TfrmMain.OnDebugLine(const Subsystem, Msg, FormattedLine: string);
{ R1.5: Callback from NM_Debug — every DebugLog call arrives here.
  Appends to the TMemo with subsystem tag. Auto-scrolls. }
begin
  AppendDebugLine(Subsystem, Msg);
end;

procedure TfrmMain.AppendDebugLine(const Subsystem, Msg: string);
{ R1.6: Color-coded subsystem tags in the debug panel.
  Since TMemo doesn't support rich text, we use bracket-tagged
  prefixes that are visually distinct:
    [NMServer]   — main app events
    [Transport]  — Telnet/socket data flow
    [UART]       — serial emulation
    [FOSSIL]     — FOSSIL driver calls
    [Bridge]     — node management
    [Synapse]    — socket link layer
    [Debug]      — debug infrastructure
  A future RichMemo upgrade can color these; for now the tags
  make grep/filter easy. }
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) +
          ' [' + Subsystem + '] ' + Msg;
  { Cap at 5000 lines to prevent memory growth }
  if DebugMemo.Lines.Count > 5000 then
  begin
    DebugMemo.Lines.Delete(0);
    DebugMemo.Lines.Delete(0);
  end;
  DebugMemo.Lines.Add(Line);
  { Auto-scroll to bottom }
  DebugMemo.SelStart := Length(DebugMemo.Text);
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
