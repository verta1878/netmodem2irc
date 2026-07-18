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
  NMVxD, NM_ServerBridge;

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
  FDriver := TNetModemDriver.Create;
  FBridge := TServerBridge.Create;

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
  FBridge.Free;
  FDriver.Free;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Original minimized to tray instead of closing; mirror that here later.
  CanClose := True;
end;

procedure TfrmMain.RefreshNodes;
begin
  // TODO: query per-node status via FDriver.GetInitInfo / AnswerCheck and
  // populate NodeList. Placeholder for the scaffold.
end;

procedure TfrmMain.RefreshTimerTimer(Sender: TObject);
begin
  RefreshNodes;
end;

procedure TfrmMain.miSetupClick(Sender: TObject);
begin
  // Launch the configuration app (config/ project) or open an in-app config form.
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
      ; // TODO: node (Msg.WParam and $FF) going online -> open Telnet socket
    CM_DISCONNECT_NODE:
      ; // TODO: node hung up -> close socket
    CM_SEND_REMOTE_BREAK:
      ; // TODO: send Telnet BREAK to remote
    CM_WILL_BINARY, CM_WONT_BINARY:
      ; // TODO: Telnet BINARY option negotiation
  end;
  inherited WndProc(Msg);
end;
{$ENDIF}

end.
