# FOSSIL cross-validation — our driver vs. ELECOM FOS_COM

"We know it works" for the FOSSIL driver, proven the strong way: our driver answers
the calls of an INDEPENDENT, period-correct FOSSIL client exactly as it expects.

## The method
ELECOM's FOS_COM.PAS (Maarten Bekers, ~1999) is a real DOS FOSSIL CLIENT — it calls
INT 14h and interprets the results the way BBS-era software did. We extracted its
EXACT call/interpretation spec and drove our NM_FossilDriver.DispatchFrame with the
same AH/AL/BX/CX/DX inputs, checking our outputs against FOS_COM's expectations.

## The spec (extracted from FOS_COM.PAS)
| Fn | FOS_COM call | Inputs | FOS_COM expects |
|----|--------------|--------|-----------------|
| $04 | Com_Open/OpenKeep | BX=$4F50, DX=port | AX=$1954 |
| $03 | Com_CharAvail | status | AH bit0 = char ready |
| $03 | Com_ReadyToSend | status | AH bit5 ($20) = room to send |
| $03 | Com_Carrier | status | AL bit7 (128) = carrier |
| $03 | GetModemStatus | status | AL=modem, AH=line |
| $02 | Com_GetChar | — | AL = char |
| $18 | Com_ReadBlock | CX=len | AX = count |
| $19 | Com_SendBlock | CX=len | AX = count |
| $06 | Com_SetDtr | AL=state | — |
| $0A/$09 | purge in/out | — | — |
| $0F | flow control | AL flags | — |
| $1B | Com_GetDriverInfo | CX=sizeof | info block |
| $05 | Com_Close (keep) | — | — |

## Result
test_fossil_client: 9/9 PASS — "FOSSIL CLIENT CROSS-VALIDATION VERIFIED".
Our driver answers FOS_COM's exact calls with FOS_COM's exact expected results.

## Why this matters
Two independent FOSSIL implementations, ~25 years apart (Maarten Bekers' FOS_COM
client and our NM_Fossil/NM_FossilDriver), agree on the bit-level FOSSIL contract
($1954 signature, the fn $03 status bit layout, the fn $04 BX=$4F50 request). If
FOS_COM would work against a real FOSSIL, and our driver answers FOS_COM identically,
then a real BBS FOSSIL client works against our driver. This is logic-level proof,
target-independent — verified now, before the 16-bit ISR/TSR packaging exists.

## What remains (target-bound, later)
The real DOS proof — FOS_COM compiled for go32v2/16-bit actually calling INT 14h
against our loaded TSR — needs the i8086 build (fpc264irc r3). But the CONTRACT
those calls rely on is now proven at the logic level, so that final step is
validation, not discovery.
