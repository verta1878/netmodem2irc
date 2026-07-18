; stubs.asm — provide missing symbols for FPC+Watt32 mixed link
; RTTI/INIT symbols: FPC compiler-generated type info references
; Watcom C symbols: entry point and float formatting stubs

SEGMENT _DATA CLASS=DATA ALIGN=2

GLOBAL INIT_SYSTEM_CHAR
GLOBAL INIT_SYSTEM_ANSISTRING
GLOBAL RTTI_SYSTEM_CHAR
GLOBAL RTTI_SYSTEM_BYTE
GLOBAL RTTI_SYSTEM_POINTER
GLOBAL RTTI_SYSTEM_SMALLINT
GLOBAL RTTI_SYSTEM_LONGINT
GLOBAL RTTI_SYSTEM_WORD

INIT_SYSTEM_CHAR:       db 0
INIT_SYSTEM_ANSISTRING: db 0
RTTI_SYSTEM_CHAR:       db 0
RTTI_SYSTEM_BYTE:       db 0
RTTI_SYSTEM_POINTER:    db 0
RTTI_SYSTEM_SMALLINT:   db 0
RTTI_SYSTEM_LONGINT:    db 0
RTTI_SYSTEM_WORD:       db 0

SEGMENT _TEXT CLASS=CODE ALIGN=2

GLOBAL main_
GLOBAL _EFG_Format_
GLOBAL __cnvs2d_

main_:
    ret

_EFG_Format_:
    xor ax, ax
    ret

__cnvs2d_:
    xor ax, ax
    ret
