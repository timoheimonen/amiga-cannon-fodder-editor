; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private ordered-SPT movement. No engine calls or canonical publication.
; A0=source; D0.w=source bytes; D1.w=logical root index.
; D2.w/D3.w=new world X/Y; D4.w/D5.w=map width/height in tiles.
; A1=430-byte candidate; A2=64-byte inverse-record candidate.
; Caller supplies disjoint, aligned, owned ranges. Inputs are read-only.
; D0.l=source byte length, D1.l=inverse count on success; D0=-1,D1=0
; on refusal. D2-D7/A0-A6 preserved. Refusal leaves both outputs untouched.
        section .text,code
        xdef ot_move,ot_move_end
ot_move:
        movem.l d2-d7/a0-a6,-(sp)
        subq.l #8,sp
        moveq #0,d7
        move.w d0,d7
        moveq #0,d6
        move.w d1,d6
        cmpi.w #19,d4
        blo .invalid
        cmpi.w #15,d5
        blo .invalid
        move.w d4,d0
        mulu.w d5,d0
        cmpi.l #7500,d0
        bhi .invalid
        cmpi.w #16,d2
        blo .invalid
        tst.w d2
        bmi .invalid
        tst.w d3
        bmi .invalid
        lsl.w #4,d4
        lsl.w #4,d5
        cmp.w d4,d2
        bhs .invalid
        cmp.w d5,d3
        bhs .invalid
        subi.w #16,d2
        move.w d2,(sp)
        move.w d3,2(sp)
        cmpi.w #10,d7
        blo .invalid
        cmpi.w #430,d7
        bhi .invalid
        move.l d7,d0
        divu.w #10,d0
        move.w d0,d5
        swap d0
        tst.w d0
        bne .invalid
        cmp.w d5,d6
        bhs .invalid
        moveq #0,d2
        moveq #0,d3
        movea.l a0,a4
.scan:
        moveq #0,d0
        move.w 8(a4),d0
        cmpi.w #$6e,d0
        bhi .invalid
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a5
        adda.w d0,a5
        moveq #0,d4
        move.b (a5)+,d4
        andi.w #3,d4
        move.w d3,d0
        addq.w #1,d0
        add.w d4,d0
        cmp.w d5,d0
        bhi .invalid
        cmp.w d6,d3
        bne.s .next_root
        move.w d4,d2
        addq.w #1,d2
        movea.l a4,a6
.next_root:
        addq.w #1,d3
        adda.w #10,a4
        tst.w d4
        beq.s .root_done
.suffix:
        moveq #0,d0
        move.b (a5)+,d0
        cmp.w 8(a4),d0
        bne .invalid
        addq.w #1,d3
        adda.w #10,a4
        subq.w #1,d4
        bne.s .suffix
.root_done:
        cmp.w d5,d3
        blo.s .scan
        tst.w d2
        beq .invalid
        cmpi.w #$7fef,4(a6)
        bhi .invalid
        tst.w 6(a6)
        bmi .invalid
        move.w (sp),d0
        sub.w 4(a6),d0
        move.w d0,4(sp)
        move.w 2(sp),d0
        sub.w 6(a6),d0
        move.w d0,6(sp)
        movea.l a6,a4
        move.w d2,d4
        subq.w #1,d4
.check_position:
        cmpi.w #$8000,4(a4)
        beq.s .position_ok
        cmpi.w #$7fef,4(a4)
        bhi .invalid
        tst.w 6(a4)
        bmi .invalid
        move.w 4(a4),d0
        add.w 4(sp),d0
        cmpi.w #$7fef,d0
        bhi .invalid
        move.w 6(a4),d0
        add.w 6(sp),d0
        bmi .invalid
.position_ok:
        adda.w #10,a4
        dbra d4,.check_position

        ; Publish to private outputs only after complete source/range validation.
        movea.l a0,a3
        movea.l a1,a4
        move.w d7,d4
        lsr.w #1,d4
        subq.w #1,d4
.copy:
        move.w (a3)+,(a4)+
        dbra d4,.copy
        moveq #0,d1
        tst.l 4(sp)
        beq.s .success
        movea.l a6,a3
        move.w d6,d4
        mulu.w #10,d4
        movea.l a1,a4
        adda.l d4,a4
        move.w d2,d5
        subq.w #1,d5
.change:
        cmpi.w #$8000,4(a3)
        beq.s .next_part
        move.w #4,d0
        tst.w d1
        bne.s .tag
        ori.w #$8000,d0
.tag:
        move.w d0,(a2)+
        move.w d6,(a2)+
        move.l (a3),(a2)+
        move.l 4(a3),(a2)+
        move.w 8(a3),(a2)+
        clr.w (a2)+
        move.w 4(a3),d0
        add.w 4(sp),d0
        move.w d0,4(a4)
        move.w 6(a3),d0
        add.w 6(sp),d0
        move.w d0,6(a4)
        addq.w #1,d1
.next_part:
        addq.w #1,d6
        adda.w #10,a3
        adda.w #10,a4
        dbra d5,.change
.success:
        move.l d7,d0
        bra.s .return
.invalid:
        moveq #-1,d0
        moveq #0,d1
.return:
        addq.l #8,sp
        movem.l (sp)+,d2-d7/a0-a6
        rts
ot_move_end:
