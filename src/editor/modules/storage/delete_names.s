; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        ifd CF_DELETE_RECORD_SET
; Masks are 20 bytes, record i is bit i&7 of byte i>>3. Padding is never authority.
cf_del_validate_set:
        movem.l d1-d6/a0-a2,-(sp)
        moveq #CF_DELETE_INVALID,d0
        cmp.w BDQ_CONTEXT+BDQ_LIVE_COUNT,d7
        bne.s .return
        clr.w cf_del_set_count
        moveq #0,d6
.bit:
        move.w d6,d1
        lsr.w #3,d1
        lea BDQ_SELECTED,a0
        adda.w d1,a0
        lea BDQ_PROTECTED,a1
        adda.w d1,a1
        move.w d6,d1
        andi.w #7,d1
        cmp.w d7,d6
        blo.s .in_count
        btst d1,(a0)
        bne.s .return
        btst d1,(a1)
        bne.s .return
        bra.s .next
.in_count:
        btst d1,(a0)
        beq.s .next
        btst d1,(a1)
        bne.s .return
        addq.w #1,cf_del_set_count
.next:
        addq.w #1,d6
        cmpi.w #160,d6
        blo.s .bit
        move.w cf_del_set_count,d1
        beq.s .return
        cmp.w BDQ_CONTEXT+BDQ_FILE_COUNT,d1
        bne.s .return
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d6/a0-a2
        tst.w d0
        rts

; D6 is a validated native record index. D0=0 selected, -1 not selected.
cf_del_set_member:
        movem.l d1/a0,-(sp)
        move.w d6,d1
        lsr.w #3,d1
        lea BDQ_SELECTED,a0
        adda.w d1,a0
        move.w d6,d1
        andi.w #7,d1
        moveq #-1,d0
        btst d1,(a0)
        beq.s .return
        moveq #0,d0
.return:
        movem.l (sp)+,d1/a0
        rts

; Only canonical generation names may be selected, independent of caller masks.
; Case folding uses a bounded stack copy, never the confirmed directory bytes.
cf_del_set_name:
        movem.l d1-d2/a0-a1,-(sp)
        lea -16(sp),sp
        movea.l sp,a1
        moveq #15,d1
.fold:
        move.b (a0)+,d2
        cmpi.b #'A',d2
        blo.s .store
        cmpi.b #'Z',d2
        bhi.s .store
        ori.b #32,d2
.store:
        move.b d2,(a1)+
        dbf d1,.fold
        movea.l sp,a0
        bsr read_valid_target
        lea 16(sp),sp
        movem.l (sp)+,d1-d2/a0-a1
        tst.w d0
        rts
        endif
