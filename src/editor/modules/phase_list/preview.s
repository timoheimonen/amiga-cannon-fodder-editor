; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Build all source rows before a modal takes READBACK. Tail staging is dead
; while the list is live. Preserve caller registers; no canonical mutation.
phl_preview:
        movem.l d1-d7/a0-a6,-(sp)
        clr.b PHL_SOURCE_COUNT
        btst #0,PHL_OWNER+AUR_FLAGS+1
        beq .ok
        bsr phl_read_source
        bne .return
        moveq #0,d6
        lea PHL_CACHE,a5
.parse:
        move.w d6,d1
        bsr phl_parse_source
        bne .return
        lea EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_TITLE,a0
        movea.l a5,a1
        moveq #64,d0
        bsr phl_copy
        lea EDITOR_SERIAL_WORK_BASE+CFMD_MAP_NAME,a0
        moveq #16,d0
        bsr phl_copy
        move.w EDITOR_SERIAL_WORK_BASE+CFMD_MAP_BYTES,PHL_ROW_BYTES_MAP(a5)
        move.l EDITOR_SERIAL_WORK_BASE+CFMD_MAP_CRC,PHL_ROW_CRC(a5)
        clr.w PHL_ROW_STATUS(a5)
        clr.l PHL_ROW_SIZE(a5)
        lea PHL_ROW_BYTES(a5),a5
        addq.w #1,d6
        cmp.b PHL_SOURCE_COUNT,d6
        blo.s .parse
        moveq #0,d6
        lea PHL_CACHE,a5
.map:
        lea PHL_ROW_NAME(a5),a0
        moveq #0,d0
        move.w PHL_ROW_BYTES_MAP(a5),d0
        move.l PHL_ROW_CRC(a5),d1
        bsr phl_read_dependency
        bne.s .return
        moveq #PHL_ERROR_SOURCE,d0
        cmpi.l #$63666564,EDITOR_READBACK_BASE+80
        bne.s .return
        moveq #0,d1
        move.w EDITOR_READBACK_BASE+84,d1
        beq.s .return
        moveq #0,d2
        move.w EDITOR_READBACK_BASE+86,d2
        beq.s .return
        mulu d2,d1
        cmpi.l #7500,d1
        bhi.s .return
        add.l d1,d1
        addi.l #96,d1
        cmp.w PHL_ROW_BYTES_MAP(a5),d1
        bne.s .return
        move.l EDITOR_READBACK_BASE+84,PHL_ROW_SIZE(a5)
        lea PHL_ROW_BYTES(a5),a5
        addq.w #1,d6
        cmp.b PHL_SOURCE_COUNT,d6
        blo.s .map
.ok:
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
