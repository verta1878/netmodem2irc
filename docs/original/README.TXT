             ------------------------------------------------------
                            NetModem/32 v2.0 alpha 3
                                 May 24, 2000
             ------------------------------------------------------

INTRODUCTION

This is a VERY primitive alpha of NetModem/32 v2.0. It is operational but
does not have all the features the final version will have. The user
interface doesn't function 100% yet. The private alpha is in fact further
along in development than these public alpha releases are.

This version includes the 16550 FIFO COM port emulator with a Hayes compatible
modem. It will respond to most Hayes AT commands and function accordingly. A
list of supported commands is in the file called ATCOMNDS.TXT. NetFOSSIL/32
is now included. You can also load X00, BNU, ADF or any other FOSSIL driver
that can support standard and/or non-standard (meaning you can customize
the FOSSIL's IRQ and base/hex address) COM ports and IRQs. Uploads and
downloads are both enabled in this release.

This release is NOT ready for mass distribution. It was only released for
testing purposes. Please do not distribute.

REQUIREMENTS

If icons on the left side of the configuration program are not showing up
then you need to get a new version of comctl32.dll, which usually comes
with new versions of Internet Explorer (4.x or above). If you see the icons
then you do not need another version of comctl32.dll. Not having the
neccesary version of comctl32.dll will not affect performance or
operation, only GUI related issues will occur.

INSTALLATION

Before proeeding, you MUST uninstall ANY version of NetModem you currently
have on your system using the Add/Remove programs from the Control Panel or
using the Uninstall icon in the NetModem Start menu folder. Next, scan your
hard drive for NETMODEM* and delete any files found. Check and see if your
NetModem directory still exits. If so, delete it. Be sure to check your
AUTOEXEC.BAT for NETFOSL.EXE that may be left over from NetModem/16 if you
have ever used it. After you have uninstalled everything you will need to
reboot. Any load errors Windows gives you will be fixed after installing this
new version and rebooting.

REBOOT BEFORE YOU INSTALL THIS!!!

If you dont the Uninstall will remove new files when you reboot and you will
be missing files.

SUPPORT AND CONTACT INFORMATION

If you have any problems, comments, lockups or concerns email us at
our new email address:

  support@allensoftware.com

For more information, visit our web site at http://www.allensoftware.com
