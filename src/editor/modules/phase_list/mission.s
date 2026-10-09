; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; A0 original mission metadata, A1 staged new phase. Preserve identity/revision,
; source-manifest reference and authored mission recruits/title. D0 is scratch;
; A0/A1 are advanced. Phase policies, title and payload references stay staged.
phase_preserve_mission:
        move.l CFMD_ID(a0),CFMD_ID(a1)
        move.l CFMD_GENERATION(a0),CFMD_GENERATION(a1)
        move.l CFMD_REVISION(a0),CFMD_REVISION(a1)
        move.w CFMD_MANIFEST_BYTES(a0),CFMD_MANIFEST_BYTES(a1)
        move.l CFMD_MANIFEST_CRC(a0),CFMD_MANIFEST_CRC(a1)
        move.l CFMD_MANIFEST_NAME(a0),CFMD_MANIFEST_NAME(a1)
        move.l CFMD_MANIFEST_NAME+4(a0),CFMD_MANIFEST_NAME+4(a1)
        move.l CFMD_MANIFEST_NAME+8(a0),CFMD_MANIFEST_NAME+8(a1)
        move.l CFMD_MANIFEST_NAME+12(a0),CFMD_MANIFEST_NAME+12(a1)
        lea CFMD_TITLE(a0),a0
        lea CFMD_TITLE(a1),a1
        moveq #15,d0
.title:
        move.l (a0)+,(a1)+
        dbf d0,.title
        rts
