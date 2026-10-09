; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Transient candidate ownership begins after reader/payload validation ends.
; Preview/display scratch ends before byte8192; no candidate survives paging.
OBJECT_CANDIDATE equ EDITOR_READBACK_BASE+8192
OBJECT_INVERSE   equ OBJECT_CANDIDATE+430
        ifgt OBJECT_INVERSE+64-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Object edit candidate exceeds readback scratch"
        endif
        ifgt edtr_state_end-OBJECT_CANDIDATE
        fail "Object edit candidate overlaps graphics state"
        endif

; D0.w=0 delete/1 move/2 insert, D1.w=logical index/boundary, D2/D3=world X/Y.
; Insertion uses the selected AUR type, admitted by the static root catalog.
; Return 1 changed,0 exact no-op,-1 refusal,-2 last logical object. Preserve others.
; Caller restores its preview first and repaints after a successful publication.
        xdef object_edit,object_undo_edit
object_edit:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d7
        bsr.s object_owner
        bne .return
        cmpi.w #2,d7
        bhi .invalid
        bsr object_context
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d0
        tst.w d7
        beq.s .delete
        cmpi.w #1,d7
        beq.s .move
        move.w d3,d4
        move.w d2,d3
        move.w AUR_BASE+AUR_OBJECT_TYPE,d2
        cmpi.w #110,d2
        bhi.s .invalid
        move.w d2,d5
        add.w d5,d5
        lea op_part_index(pc),a3
        tst.w 0(a3,d5.w)
        beq.s .invalid
        move.w editor_map_width,d5
        move.w editor_map_height,d6
        bsr ot_insert
        bra.s .publish
.move:
        move.w editor_map_width,d4
        move.w editor_map_height,d5
        bsr ot_move
        bra.s .publish
.delete:
        bsr ot_delete
.publish:
        tst.l d0
        bmi.s .return
        lsl.w #4,d1
        bsr.s object_context
        moveq #0,d7
        move.w editor_map_width,d7
        mulu editor_map_height,d7
        bsr op_publish
        cmpi.w #1,d0
        bne.s .return
        bsr aur_mark_edited
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
.invalid:
        moveq #-1,d0
        bra.s .return

; Return2 delegates a terrain group to EDTR without popping it.
object_undo_edit:
        movem.l d1-d7/a0-a6,-(sp)
        bsr object_owner
        bne.s .return
        bsr.s object_context
        moveq #0,d7
        move.w editor_map_width,d7
        mulu editor_map_height,d7
        bsr op_undo
        cmpi.w #1,d0
        bne.s .return
        bsr aur_mark_edited
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
object_context:
        lea EDITOR_SPT_BASE,a0
        lea OBJECT_CANDIDATE,a1
        lea OBJECT_INVERSE,a2
        lea EDITOR_METADATA_BASE,a3
        lea AUR_BASE,a4
        lea EDITOR_UNDO_BASE,a5
        rts
