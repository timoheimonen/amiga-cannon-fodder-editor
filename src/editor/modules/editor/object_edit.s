; Cannon Fodder In-Game Level Editor V1.2.6
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Transient candidate ownership begins after reader/payload validation ends.
; Placed immediately above view/display scratch; no candidate survives paging.
OBJECT_CANDIDATE equ edtr_state_end
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
        xdef object_edit,object_undo_edit,object_redo_edit
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
        bsr object_context
        moveq #0,d7
        move.w editor_map_width,d7
        mulu editor_map_height,d7
        bsr op_publish
        cmpi.w #1,d0
        bne.s .return
        move.l d0,-(sp)
        moveq #UNDO_REDO_CLEAR,d1
        moveq #UNDO_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        move.l (sp)+,d0
        bsr aur_mark_edited
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
.invalid:
        moveq #-1,d0
        bra.s .return

; Return 2 delegates a terrain group to EDTR without popping it.
; Captures the undone object group's inverse onto the Slave Redo stack.
object_undo_edit:
        movem.l d1-d7/a0-a6,-(sp)
        lea -64(sp),sp
        bsr object_owner
        bne .return
        bsr object_context
        moveq #0,d7
        move.w editor_map_width,d7
        mulu editor_map_height,d7
        ; Check if top undo group is an object group before peeking into 64B.
        moveq #0,d6
        tst.w AUR_BASE+AUR_UNDO_COUNT
        beq.s .do_undo
        move.w AUR_BASE+AUR_UNDO_NEXT,d0
        subq.w #1,d0
        andi.w #255,d0
        lsl.w #4,d0
        move.w 0(a5,d0.w),d0
        andi.w #$7FFF,d0
        cmpi.w #1,d0
        beq.s .do_undo
        movea.l a5,a0
        lea AUR_BASE+AUR_UNDO_NEXT,a1
        movea.l sp,a2
        bsr oh_peek
        tst.l d0
        ble.s .do_undo
        cmpi.l #64,d0
        bhi.s .do_undo
        move.w d0,d6
        lea EDITOR_SPT_BASE,a0
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d0
        lea OBJECT_INVERSE,a1
        movea.l sp,a2
        move.w d6,d1
        bsr object_compute_inverse
.do_undo:
        bsr object_context
        bsr op_undo
        cmpi.w #1,d0
        bne.s .return
        tst.w d6
        beq.s .marked
        move.l d0,-(sp)
        lsr.w #4,d6
        subq.w #1,d6
        lea OBJECT_INVERSE,a0
.push_redo:
        moveq #UNDO_REDO_PUSH,d1
        moveq #UNDO_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        lea 16(a0),a0
        dbra d6,.push_redo
        move.l (sp)+,d0
.marked:
        bsr aur_mark_edited
.return:
        lea 64(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; Apply newest object group from the Slave Redo stack and record its inverse
; back into EDITOR_UNDO_BASE via op_publish. Return 2 delegates terrain redo.
object_redo_edit:
        movem.l d1-d7/a0-a6,-(sp)
        lea -64(sp),sp
        bsr object_owner
        bne .out
        moveq #UNDO_REDO_PEEK,d1
        moveq #UNDO_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        tst.l d0
        beq .out
        cmpi.w #1,d0
        bne.s .pop
        moveq #2,d0
        bra .out
.pop:
        movea.l sp,a0
        moveq #UNDO_REDO_POP_GROUP,d1
        moveq #UNDO_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        tst.l d0
        ble .out
        move.w d0,d6                ; group bytes (16..64)
        lea EDITOR_SPT_BASE,a0
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d0
        lea OBJECT_INVERSE,a1
        movea.l sp,a2
        move.w d6,d1
        bsr object_compute_inverse
        lea EDITOR_SPT_BASE,a0
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d0
        lea OBJECT_CANDIDATE,a1
        movea.l sp,a2
        move.w d6,d1
        bsr ot_reverse
        tst.l d0
        bmi.s .out
        move.w d6,d1
        bsr object_context
        moveq #0,d7
        move.w editor_map_width,d7
        mulu editor_map_height,d7
        bsr op_publish
        cmpi.w #1,d0
        bne.s .out
        bsr aur_mark_edited
.out:
        lea 64(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; Compute the exact inverse group of an object group about to be reversed by
; ot_reverse. A0=current SPT, D0.w=SPT bytes, A2=group (16..64 bytes, oldest
; first), D1.w=group bytes, A1=64-byte inverse output. Uses OBJECT_CANDIDATE
; as scratch SPT copy. Preserves all registers.
object_compute_inverse:
        movem.l d0-d7/a0-a6,-(sp)
        ; Copy current SPT to OBJECT_CANDIDATE.
        lea OBJECT_CANDIDATE,a4
        move.w d0,d7                ; cur_len
        move.w d0,d2
        lsr.w #1,d2
        beq.s .copied
        subq.w #1,d2
.copy:
        move.w (a0)+,(a4)+
        dbra d2,.copy
.copied:
        movea.l a2,a3
        adda.w d1,a3                ; walk backwards from end of group
        lsr.w #4,d1
        subq.w #1,d1
        move.w #$8000,d6            ; begin bit on first inverse record only
.step:
        lea -16(a3),a3
        moveq #0,d0
        move.w 2(a3),d0             ; slot index
        move.w d0,d4
        mulu.w #10,d4               ; byte offset in scratch SPT
        move.w (a3),d5
        andi.w #$7FFF,d5
        lea OBJECT_CANDIDATE,a4
        adda.w d4,a4
        cmpi.w #2,d5
        beq.s .inv_del
        cmpi.w #3,d5
        beq.s .inv_ins
        ; Tag 4 (move/replace): inverse is tag 4 with current 10 bytes.
        move.w d6,d2
        ori.w #4,d2
        move.w d2,(a1)+
        move.w d0,(a1)+
        move.l (a4),(a1)+
        move.l 4(a4),(a1)+
        move.w 8(a4),(a1)+
        clr.w (a1)+
        move.l 4(a3),(a4)
        move.l 8(a3),4(a4)
        move.w 12(a3),8(a4)
        bra.s .next
.inv_del:
        ; Tag 2 (delete slot): inverse is tag 3 with current 10 bytes, then shift left.
        move.w d6,d2
        ori.w #3,d2
        move.w d2,(a1)+
        move.w d0,(a1)+
        move.l (a4),(a1)+
        move.l 4(a4),(a1)+
        move.w 8(a4),(a1)+
        clr.w (a1)+
        lea 10(a4),a5
        move.w d7,d3
        sub.w d4,d3
        subi.w #10,d3
        lsr.w #1,d3
        beq.s .del_done
        subq.w #1,d3
.del_shift:
        move.w (a5)+,(a4)+
        dbra d3,.del_shift
.del_done:
        subi.w #10,d7
        bra.s .next
.inv_ins:
        ; Tag 3 (insert at slot): inverse is tag 2 with zero payload, then shift right.
        move.w d6,d2
        ori.w #2,d2
        move.w d2,(a1)+
        move.w d0,(a1)+
        clr.l (a1)+
        clr.l (a1)+
        clr.l (a1)+
        lea OBJECT_CANDIDATE,a5
        adda.w d7,a5
        lea 10(a5),a6
        move.w d7,d3
        sub.w d4,d3
        lsr.w #1,d3
        beq.s .ins_copy
        subq.w #1,d3
.ins_shift:
        move.w -(a5),-(a6)
        dbra d3,.ins_shift
.ins_copy:
        move.l 4(a3),(a4)
        move.l 8(a3),4(a4)
        move.w 12(a3),8(a4)
        addi.w #10,d7
.next:
        moveq #0,d6
        dbra d1,.step
        movem.l (sp)+,d0-d7/a0-a6
        rts
object_context:
        lea EDITOR_SPT_BASE,a0
        lea OBJECT_CANDIDATE,a1
        lea OBJECT_INVERSE,a2
        lea EDITOR_METADATA_BASE,a3
        lea AUR_BASE,a4
        lea EDITOR_UNDO_BASE,a5
        rts
