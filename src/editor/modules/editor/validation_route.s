; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

edtr_request_validation:
        move.l #$000DFFFF,-(sp)
        bra edtr_request_page
edtr_validation_released:
        move.l #$000DFFFF,-(sp)
        bra edtr_page_released

; Full AUR/page/module identity is already checked. A camera-only result must
; match the completed by-value focus record; consumption invalidates it once.
edtr_validation_receipt:
        tst.w d2
        beq.s edtr_validation_cancel
        cmpi.w #EDTR_VISUAL_ERROR,d2
        beq.s edtr_validation_cancel
        cmpi.w #1,d2
        bne edtr_receive_return
        cmpi.l #E7_TAG,E7_CONTEXT
        bne edtr_receive_return
        cmpi.b #E7_FOCUS_APPLIED,E7_STAGE
        bne edtr_receive_return
        move.b E7_PHASE+PCREL(pc),d3
        cmp.b AUR_SELECTED(a5),d3
        bne edtr_receive_return
        move.l E7_X+PCREL(pc),d3
        cmp.l AUR_CAMERA_X(a5),d3
        bne edtr_receive_return
        moveq #0,d2
edtr_validation_cancel:
        clr.b E7_STAGE
        bra tile_receive_commit

; Assets must be complete before this gate is called. A guard cancellation
; retains the old selected phase, so its mismatched logical focus is discarded.
; On resume, place the by-value request below our returnPC for the shared tail.
edtr_focus_resume:
        cmpi.l #E7_TAG,E7_CONTEXT
        bne.s .no
        cmpi.b #E7_JUMP_PENDING,E7_STAGE
        bne.s .no
        move.b E7_PHASE+PCREL(pc),d0
        cmp.b AUR_BASE+AUR_SELECTED+PCREL(pc),d0
        beq.s .resume
        clr.b E7_STAGE
.no:
        moveq #0,d0
        rts
.resume:
        move.l (sp)+,a0
        move.l #$000D0000,-(sp)
        move.l a0,-(sp)
        moveq #1,d0
        rts
