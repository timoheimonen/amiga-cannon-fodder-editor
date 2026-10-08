; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private ordered-SPT insertion. Catalog admission remains a caller obligation.
; A0=source; D0.w=source bytes; D1.w=logical insertion boundary.
; D2.w=type; D3.w/D4.w=world X/Y; D5.w/D6.w=map tile dimensions.
; A1=430-byte candidate; A2=64-byte inverse candidate; disjoint aligned ownership.
; D0.l=new byte length, D1.l=inverse count, or D0=-1,D1=0 on refusal.
; D2-D7/A0-A6 preserved. Neither output is written until validation completes.
        section .text,code
        xdef ot_insert,ot_insert_end
ot_insert:
        movem.l d2-d7/a0-a6,-(sp)
        lea -24(sp),sp
        move.w d0,(sp)
        move.w d1,2(sp)
        move.w d2,4(sp)
        cmpi.w #$6e,d2
        bhi .invalid
        cmpi.w #19,d5
        blo .invalid
        cmpi.w #15,d6
        blo .invalid
        move.w d5,d0
        mulu.w d6,d0
        cmpi.l #7500,d0
        bhi .invalid
        cmpi.w #16,d3
        blo .invalid
        tst.w d3
        bmi .invalid
        tst.w d4
        bmi .invalid
        lsl.w #4,d5
        lsl.w #4,d6
        cmp.w d5,d3
        bhs .invalid
        cmp.w d6,d4
        bhs .invalid
        subi.w #16,d3
        move.w d3,6(sp)
        move.w d4,8(sp)
        moveq #0,d7
        move.w (sp),d7
        cmpi.w #10,d7
        blo .invalid
        cmpi.w #430,d7
        bhi .invalid
        move.l d7,d0
        divu.w #10,d0
        move.w d0,12(sp)
        swap d0
        tst.w d0
        bne .invalid
        move.w 2(sp),d0
        cmp.w 12(sp),d0
        bhi .invalid
        lsl.w #2,d2
        lea ot_shared_recipes(pc),a6
        adda.w d2,a6
        moveq #0,d0
        move.b (a6),d0
        move.w d0,20(sp)
        andi.w #3,d0
        addq.w #1,d0
        move.w d0,10(sp)
        mulu.w #10,d0
        add.l d7,d0
        cmpi.w #430,d0
        bhi .invalid
        move.w d0,16(sp)
        tst.b 21(sp)
        bpl.s .new_slot_ok
        move.w 2(sp),d0
        add.w 10(sp),d0
        cmpi.w #30,d0
        bhi .invalid
.new_slot_ok:
        clr.w 18(sp)
        tst.w 4(sp)
        bne.s .troop_ready
        addq.w #1,18(sp)
.troop_ready:
        clr.w 22(sp)
        moveq #0,d3
        movea.l a0,a4
.scan:
        cmp.w 2(sp),d3
        bne.s .boundary
        move.w #1,22(sp)
.boundary:
        moveq #0,d0
        move.w 8(a4),d0
        cmpi.w #$6e,d0
        bhi .invalid
        tst.w d0
        bne.s .troop_counted
        move.w 4(a4),d1
        addi.w #16,d1
        bmi.s .troop_counted
        addq.w #1,18(sp)
.troop_counted:
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a5
        adda.w d0,a5
        moveq #0,d4
        move.b (a5)+,d4
        move.w d4,d2
        andi.w #3,d4
        move.w d3,d0
        addq.w #1,d0
        add.w d4,d0
        cmp.w 12(sp),d0
        bhi .invalid
        tst.b d2
        bpl.s .existing_slot_ok
        cmp.w 2(sp),d3
        blo.s .primary_end
        add.w 10(sp),d0
.primary_end:
        cmpi.w #30,d0
        bhi .invalid
.existing_slot_ok:
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
        cmp.w 12(sp),d3
        blo .scan
        cmpi.w #8,18(sp)
        bhi .invalid
        cmp.w 2(sp),d3
        beq.s .validated
        tst.w 22(sp)
        beq .invalid
.validated:
        ; Copy the prefix, construct one ordered bundle, then copy the tail.
        move.w 2(sp),d3
        mulu.w #10,d3
        movea.l a0,a3
        move.w d3,d4
        lsr.w #1,d4
        beq.s .prefix_done
        subq.w #1,d4
.prefix:
        move.w (a3)+,(a1)+
        dbra d4,.prefix
.prefix_done:
        moveq #0,d5
        move.w 2(sp),d6
        move.w 10(sp),d4
        subq.w #1,d4
        move.w 4(sp),d2
        addq.l #1,a6
.new_record:
        clr.l (a1)+
        tst.w d5
        beq.s .active
        cmpi.w #$3c,4(sp)
        beq.s .active
        move.w #$8000,(a1)+
        clr.w (a1)+
        bra.s .record_type
.active:
        move.w 6(sp),(a1)+
        move.w 8(sp),(a1)+
.record_type:
        move.w d2,(a1)+
        move.w #2,d0
        tst.w d5
        bne.s .undo_tag
        ori.w #$8000,d0
.undo_tag:
        move.w d0,(a2)+
        move.w d6,(a2)+
        clr.l (a2)+
        clr.l (a2)+
        clr.l (a2)+
        addq.w #1,d5
        addq.w #1,d6
        moveq #0,d2
        move.b (a6)+,d2
        dbra d4,.new_record
        sub.l d3,d7
        lsr.w #1,d7
        beq.s .success
        subq.w #1,d7
.tail:
        move.w (a3)+,(a1)+
        dbra d7,.tail
.success:
        moveq #0,d0
        move.w 16(sp),d0
        moveq #0,d1
        move.w 10(sp),d1
        bra.s .return
.invalid:
        moveq #-1,d0
        moveq #0,d1
.return:
        lea 24(sp),sp
        movem.l (sp)+,d2-d7/a0-a6
        rts
ot_insert_end:
