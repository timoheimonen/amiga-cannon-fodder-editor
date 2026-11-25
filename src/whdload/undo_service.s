; Cannon Fodder In-Game Level Editor V1.2.6
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Undo/Redo service (backend operation 14, see ui.i). Backed by 8 KiB in
; ws_ExpMem immediately above DIALOG_BACKUP_END so it costs no BaseMem and
; survives native gameplay during Test. All registers except D0.l are preserved.
UNDO_EXPMEM_BASE    equ (DIALOG_BACKUP_END+3)&-4
UNDO_BACKUP_BUF     equ UNDO_EXPMEM_BASE
REDO_RING_BUF       equ UNDO_BACKUP_BUF+4096
UNDO_EXPMEM_END     equ REDO_RING_BUF+4096
SLAVE_EXPMEM_BYTES  equ (UNDO_EXPMEM_END+$fff)&-$1000

undo_service:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w #UNDO_REDO_POP_GROUP,d1
        bhi.s .refuse
        add.w d1,d1
        move.w .jump(pc,d1.w),d1
        jsr .jump(pc,d1.w)
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
.refuse:
        moveq #-1,d0
        bra.s .return
.jump:
        dc.w undo_op_backup-.jump
        dc.w undo_op_restore-.jump
        dc.w undo_op_clear-.jump
        dc.w undo_op_push-.jump
        dc.w undo_op_peek-.jump
        dc.w undo_op_pop_one-.jump
        dc.w undo_op_pop_group-.jump

; D2.l = next|count, D3.l = source_id, D4.w = selected, A0 = EDITOR_UNDO_BASE.
undo_op_backup:
        movea.l expmem(pc),a1
        adda.l #UNDO_BACKUP_BUF,a1
        move.w #4096/4-1,d0
.copy:
        move.l (a0)+,(a1)+
        dbra d0,.copy
        lea undo_bak_valid(pc),a1
        move.w #1,(a1)+
        move.l d2,(a1)+
        move.l d3,(a1)+
        move.w d4,(a1)
        moveq #0,d0
        rts

; A0 = EDITOR_UNDO_BASE, A1 = &AUR_UNDO_NEXT, D3.l = source_id, D4.w = selected.
; Returns 1 if restored, 0 if no matching backup (clears backup and redo).
undo_op_restore:
        lea undo_bak_valid(pc),a2
        tst.w (a2)
        beq.s .miss
        cmp.l 6(a2),d3
        bne.s .miss
        cmp.w 10(a2),d4
        bne.s .miss
        clr.w (a2)
        move.l 2(a2),(a1)
        movea.l expmem(pc),a2
        adda.l #UNDO_BACKUP_BUF,a2
        move.w #4096/4-1,d0
.copy:
        move.l (a2)+,(a0)+
        dbra d0,.copy
        moveq #1,d0
        rts
.miss:
        clr.w (a2)
        lea redo_next(pc),a2
        clr.l (a2)
        moveq #0,d0
        rts

; Clear the redo ring and any pending Test backup.
undo_op_clear:
        lea undo_bak_valid(pc),a1
        clr.w (a1)
        lea redo_next(pc),a1
        clr.l (a1)
        moveq #0,d0
        rts

; A0 = 16-byte record to push onto the 256-record redo ring.
undo_op_push:
        movea.l expmem(pc),a2
        adda.l #REDO_RING_BUF,a2
        lea redo_next(pc),a1
        cmpi.w #256,2(a1)
        blo.s .append
        ; Ring full: discard the oldest complete group (starting at redo_next).
        move.w (a1),d2
        moveq #0,d3
.drop:
        addq.w #1,d3
        addq.w #1,d2
        andi.w #255,d2
        cmp.w 2(a1),d3
        beq.s .drop_done
        move.w d2,d0
        lsl.w #4,d0
        tst.w 0(a2,d0.w)
        bpl.s .drop
.drop_done:
        sub.w d3,2(a1)
.append:
        move.w (a1),d0
        lsl.w #4,d0
        lea 0(a2,d0.w),a3
        move.l (a0)+,(a3)+
        move.l (a0)+,(a3)+
        move.l (a0)+,(a3)+
        move.l (a0)+,(a3)+
        addq.w #1,(a1)
        andi.w #255,(a1)
        addq.w #1,2(a1)
        moveq #0,d0
        rts

; Returns 0 if empty, else the top record's type (1=terrain, 2..4=object).
undo_op_peek:
        lea redo_next(pc),a1
        tst.w 2(a1)
        beq.s .empty
        move.w (a1),d0
        subq.w #1,d0
        andi.w #255,d0
        lsl.w #4,d0
        movea.l expmem(pc),a2
        adda.l #REDO_RING_BUF,a2
        moveq #0,d1
        move.w 0(a2,d0.w),d1
        andi.w #$7FFF,d1
        move.l d1,d0
        rts
.empty:
        moveq #0,d0
        rts

; A0 = 16-byte output buffer. Pops newest record -> D0=1 popped, 0 empty.
undo_op_pop_one:
        lea redo_next(pc),a1
        tst.w 2(a1)
        beq.s .empty
        subq.w #1,(a1)
        andi.w #255,(a1)
        subq.w #1,2(a1)
        move.w (a1),d0
        lsl.w #4,d0
        movea.l expmem(pc),a2
        adda.l #REDO_RING_BUF,a2
        lea 0(a2,d0.w),a3
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        moveq #1,d0
        rts
.empty:
        moveq #0,d0
        rts

; A0 = 64-byte output buffer. Pops newest object group (1..4 records, oldest-first).
; Returns byte length (16..64), 0 if empty, -1 if terrain or malformed.
undo_op_pop_group:
        lea redo_next(pc),a1
        move.w 2(a1),d5
        beq.s .empty
        movea.l expmem(pc),a2
        adda.l #REDO_RING_BUF,a2
        move.w (a1),d3
        moveq #0,d6
.scan:
        cmp.w d5,d6
        bhs.s .bad
        subq.w #1,d3
        andi.w #255,d3
        move.w d3,d4
        lsl.w #4,d4
        move.w 0(a2,d4.w),d0
        move.w d0,d1
        andi.w #$7FFF,d1
        cmpi.w #2,d1
        blo.s .bad
        cmpi.w #4,d1
        bhi.s .bad
        addq.w #1,d6
        cmpi.w #4,d6
        bhi.s .bad
        tst.w d0
        bpl.s .scan
        ; D3 = oldest slot in group, D6 = record count (1..4).
        move.w d6,d2
        subq.w #1,d2
        move.w d3,d4
.copy:
        move.w d4,d0
        lsl.w #4,d0
        lea 0(a2,d0.w),a3
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        move.l (a3)+,(a0)+
        addq.w #1,d4
        andi.w #255,d4
        dbra d2,.copy
        move.w d3,(a1)
        sub.w d6,2(a1)
        moveq #0,d0
        move.w d6,d0
        lsl.w #4,d0
        rts
.empty:
        moveq #0,d0
        rts
.bad:
        moveq #-1,d0
        rts

undo_bak_valid:     dc.w 0
undo_bak_next_cnt:  dc.l 0
undo_bak_id:        dc.l 0
undo_bak_phase:     dc.w 0
redo_next:          dc.w 0
redo_count:         dc.w 0
        even
