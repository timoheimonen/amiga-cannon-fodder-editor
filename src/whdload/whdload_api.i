; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; WHDLoad interface subset, from https://whdload.de/docs/autodoc.html.

WHDLF_ClearMem         equ 1<<12
TDREASON_OK            equ -1
TDREASON_WRONGVER      equ 9
resload_Abort          equ $04
resload_LoadFile       equ $08
resload_SaveFile       equ $0c
resload_FlushCache     equ $20
resload_GetFileSize    equ $24
resload_DiskLoad       equ $28

resload_ListFiles       equ $14
resload_SaveFileOffset  equ $38
resload_LoadFileOffset  equ $4c
resload_DeleteFile      equ $58
