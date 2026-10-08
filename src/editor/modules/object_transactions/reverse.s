; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Reverse one private object group before canonical publication.
; A0=SPT source; D0.w=bytes; A1=430-byte candidate; A2=inverse group;
; D1.w=inverse bytes (0,16,32,48,64). Buffers are aligned, disjoint and owned.
; D0.l=new SPT bytes or -1. All other registers preserved, except CCR.
; Invalid source/group/result leaves the caller's candidate untouched.
; Uses 448 private stack bytes in addition to saved registers and call frames.
        section .text,code
        xdef ot_reverse,ot_reverse_end
ot_reverse:
        movem.l d1-d7/a0-a6,-(sp)
        lea -448(sp),sp
        move.w d0,(sp)
        move.w d1,2(sp)
        moveq #0,d7
        move.w d0,d7
        movea.l a0,a4
        bsr .validate_spt
        tst.l d0
        bne .invalid
        move.w 2(sp),d6
        cmpi.w #64,d6
        bhi .invalid
        move.w d6,d0
        andi.w #15,d0
        bne .invalid
        tst.w d6
        beq.s .log_valid
        lsr.w #4,d6
        subq.w #1,d6
        moveq #0,d3
        movea.l a2,a3
.check_log:
        move.w (a3),d4
        tst.w d3
        bne.s .later
        tst.w d4
        bpl .invalid
        bra.s .tag
.later:
        tst.w d4
        bmi .invalid
.tag:
        andi.w #$7fff,d4
        cmpi.w #2,d4
        blo .invalid
        cmpi.w #4,d4
        bhi .invalid
        cmpi.w #43,2(a3)
        bhs .invalid
        tst.w 14(a3)
        bne .invalid
        cmpi.w #2,d4
        bne.s .old_record
        tst.l 4(a3)
        bne .invalid
        tst.l 8(a3)
        bne .invalid
        tst.l 12(a3)
        bne .invalid
        bra.s .next_log
.old_record:
        cmpi.w #$6e,12(a3)
        bhi .invalid
.next_log:
        adda.w #16,a3
        addq.w #1,d3
        dbra d6,.check_log
.log_valid:
        movea.l a0,a4
        lea 16(sp),a5
        move.w (sp),d6
        lsr.w #1,d6
        subq.w #1,d6
.copy_private:
        move.w (a4)+,(a5)+
        dbra d6,.copy_private
        movea.l a2,a3
        move.w 2(sp),d6
        move.w d6,4(sp)
        adda.w d6,a3
.reverse_next:
        tst.w 4(sp)
        beq .result
        subi.w #16,4(sp)
        lea -16(a3),a3
        moveq #0,d0
        move.w 2(a3),d0
        mulu.w #10,d0
        moveq #0,d4
        move.w (sp),d4
        move.w (a3),d5
        andi.w #$7fff,d5
        cmpi.w #3,d5
        beq.s .restore_deleted
        cmp.l d4,d0
        bhs .invalid
        lea 16(sp),a4
        adda.l d0,a4
        cmpi.w #4,d5
        beq.s .copy_record
        ; Undo insertion by shifting the remaining tail left.
        lea 10(a4),a5
        move.l d4,d1
        sub.l d0,d1
        subi.w #10,d1
        lsr.w #1,d1
        beq.s .removed
        subq.w #1,d1
.remove_tail:
        move.w (a5)+,(a4)+
        dbra d1,.remove_tail
.removed:
        subi.w #10,(sp)
        bra.s .reverse_next
.restore_deleted:
        cmp.l d4,d0
        bhi.s .invalid
        cmpi.w #420,d4
        bhi.s .invalid
        lea 16(sp),a4
        adda.l d4,a4
        lea 10(a4),a5
        move.l d4,d1
        sub.l d0,d1
        lsr.w #1,d1
        beq.s .tail_restored
        subq.w #1,d1
.insert_tail:
        move.w -(a4),-(a5)
        dbra d1,.insert_tail
.tail_restored:
        addi.w #10,(sp)
        lea 16(sp),a4
        adda.l d0,a4
.copy_record:
        move.l 4(a3),(a4)
        move.l 8(a3),4(a4)
        move.w 12(a3),8(a4)
        bra .reverse_next
.result:
        moveq #0,d7
        move.w (sp),d7
        lea 16(sp),a4
        bsr.s .validate_spt
        tst.l d0
        bne.s .invalid
        lea 16(sp),a4
        movea.l a1,a5
        move.w d7,d1
        lsr.w #1,d1
        subq.w #1,d1
.publish:
        move.w (a4)+,(a5)+
        dbra d1,.publish
        move.l d7,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        lea 448(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Read-only SPT structural check. A4=source, D7=byte length, D0=result.
.validate_spt:
        moveq #-1,d0
        cmpi.w #10,d7
        blo.s .validation_return
        cmpi.w #430,d7
        bhi.s .validation_return
        move.l d7,d1
        divu.w #10,d1
        move.w d1,d5
        swap d1
        tst.w d1
        bne.s .validation_return
        moveq #0,d3
.validate_root:
        moveq #0,d1
        move.w 8(a4),d1
        cmpi.w #$6e,d1
        bhi.s .validation_return
        lsl.w #2,d1
        lea ot_shared_recipes(pc),a5
        adda.w d1,a5
        moveq #0,d4
        move.b (a5)+,d4
        andi.w #3,d4
        move.w d3,d1
        addq.w #1,d1
        add.w d4,d1
        cmp.w d5,d1
        bhi.s .validation_return
        addq.w #1,d3
        adda.w #10,a4
        tst.w d4
        beq.s .validated_root
.validate_suffix:
        moveq #0,d1
        move.b (a5)+,d1
        cmp.w 8(a4),d1
        bne.s .validation_return
        addq.w #1,d3
        adda.w #10,a4
        subq.w #1,d4
        bne.s .validate_suffix
.validated_root:
        cmp.w d5,d3
        blo.s .validate_root
        moveq #0,d0
.validation_return:
        rts
ot_reverse_end:
