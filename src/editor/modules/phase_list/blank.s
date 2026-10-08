; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private append admission after the guard. All retained phases must have saved
; file backing before selecting a newly created FF slot. The original source is
; requalified before the picker; the wrapper requalifies the Custom directory
; after retirement.
phl_blank_prepare:
        movem.l d1-d7/a0-a6,-(sp)
        bsr phl_check
        bne phl_return
        cmpi.w #AUR_CONTINUE_PHASE_BLANK,PHL_INTENT
        bne phl_bad_private
        bsr phl_changed
        bne phl_bad_private
        btst #0,PHL_OWNER+AUR_FLAGS+1
        beq phl_bad_private
        lea PHL_MAP,a0
        moveq #0,d1
        move.b 6(a0),d1
        cmpi.w #6,d1
        bhs phl_bad_private
        moveq #0,d2
        move.b 7(a0),d2
        cmpi.b #$FF,0(a0,d2.w)
        beq phl_bad_private
        bsr phl_read_source
        bne phl_return
        moveq #0,d1
        bsr phl_parse_source
        bne phl_return
        bsr phl_valid_map
        bne phl_return
        lea PHL_MAP,a0
        moveq #0,d1
        move.b 6(a0),d1
        move.b #$FF,0(a0,d1.w)
        move.b d1,7(a0)
        bclr d1,PHL_TESTED
        addq.b #1,6(a0)
        move.w #2,PHL_READY
        moveq #0,d0
        bra phl_return

; D0.l family0..5, D1.l width, D2.l height. Owns only disposable stage after
; the paired modal has retired. Reuses the qualified blank draft constructor.
phl_blank_stage:
        movem.l d1-d7/a0-a6,-(sp)
        bsr new_draft_stage
        tst.w d0
        bne phl_return
        lea NEW_STAGE_SPT,a0
        lea PHL_STAGE_SPT,a1
        move.w #430,d0
        bsr phl_copy
        clr.w PHL_STAGE_SPT+430
        lea NEW_STAGE_METADATA,a0
        lea PHL_STAGE_METADATA,a1
        move.w #384,d0
        bsr phl_copy
        lea PHL_ORIGINAL,a0
        lea PHL_STAGE_METADATA,a1
        bsr.s phase_preserve_mission
        lea EDITOR_READBACK_BASE,a0
        lea PHL_STAGE_SPT,a1
        lea PHL_STAGE_METADATA,a2
        lea EDITOR_SERIAL_WORK_BASE,a3
        lea EDITOR_SERIAL_WORK_BASE+32,a4
        moveq #0,d0
        move.w PHL_STAGE_METADATA+CFMD_MAP_BYTES,d0
        moveq #10,d1
        bsr cf_payload_validate
        tst.w d0
        bra phl_return
