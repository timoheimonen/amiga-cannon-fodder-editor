; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef resize_spt_stage,resize_spt_stage_end,resize_spt_recipes

; Stage complete logical SPT items selected by their owner's world anchor.
; A0=source, D0.l=exact source bytes (10..430, divisible by ten).
; A1=destination, D1.l=capacity; D2.w/D3.w=new width/height.
; Return D0.l=retained SPT bytes, -1 refused input/buffer, -2 no item remains.
; Preserve every other register, SP and SR control bits. Stack: 56 bytes
; plus caller RTS. The saved D1 at 0(SP) remains the destination capacity.
; Output: +0 length.w, +2 removed logical items.w, +4 record mask 0..31.l,
; +8 record mask 32..42.l, +12 retained raw SPT. Unused tail is untouched.
; Root anchor is (stored X+16,Y). All exact companion suffix bytes stay with
; their owner; companion coordinates are never independently clipped.
; All checks finish before the first destination store. Buffer extents must
; be separate, even, unaliased caller-owned RAM, outside code/stack/other
; owners. No engine calls, allocations, canonical publication or repair.
resize_spt_stage:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l  #10,d0
        blo     .reject
        cmpi.l  #430,d0
        bhi     .reject
        move.l  d0,d6
        divu    #10,d6
        swap    d6
        tst.w   d6
        bne     .reject
        move.l  a0,d5
        move.l  a1,d6
        or.l    d6,d5
        btst    #0,d5
        bne     .reject
        move.l  a0,d5
        add.l   d0,d5
        bcs     .reject
        cmpi.l  #$1000000,d5
        bhi     .reject
        movea.l d5,a5
        cmpi.w  #19,d2
        blo     .reject
        cmpi.w  #15,d3
        blo     .reject
        move.w  d2,d6
        mulu    d3,d6
        cmpi.l  #7500,d6
        bhi     .reject
        lsl.w   #4,d2
        lsl.w   #4,d3
        movea.l a0,a2
        suba.l  a4,a4
        suba.l  a6,a6
        moveq   #0,d4
        moveq   #0,d5
        moveq   #0,d7
.group:
        moveq   #0,d0
        move.w  8(a2),d0
        cmpi.w  #$6E,d0
        bhi     .reject
        lea     resize_spt_recipes(pc),a3
        moveq   #0,d1
        move.b  (a3,d0.w),d1
        moveq   #3,d6
        and.w   d1,d6
        move.w  d6,d0
        addq.w  #1,d0
        mulu    #10,d0
        movea.l a2,a3
        adda.w  d0,a3
        cmpa.l  a5,a3
        bhi     .reject
        tst.w   d6
        beq.s   .anchor
        moveq   #18,d0
.suffix:
        cmpi.w  #1,d6
        bne.s   .inert
        btst    #7,d1
        beq.s   .inert
        cmpi.w  #$29,(a2,d0.w)
        bne     .reject
        bra.s   .next_suffix
.inert:
        cmpi.w  #4,(a2,d0.w)
        bne     .reject
.next_suffix:
        addi.w  #10,d0
        subq.w  #1,d6
        bne.s   .suffix
.anchor:
        move.w  4(a2),d0
        cmpi.w  #$7FEF,d0
        bhi     .reject
        move.w  6(a2),d1
        cmpi.w  #$8000,d1
        bhs     .reject
        addi.w  #16,d0
        cmp.w   d2,d0
        bhs.s   .remove
        cmp.w   d3,d1
        bhs.s   .remove
        move.l  a3,d0
        sub.l   a2,d0
        adda.w  d0,a4
        divu    #10,d0
        add.w   d0,d7
        bra.s   .advance
.remove:
        addq.l  #1,a6
        move.l  a3,d6
        sub.l   a2,d6
        divu    #10,d6
        subq.w  #1,d6
.mask:
        cmpi.w  #32,d7
        bhs.s   .high
        bset    d7,d4
        bra.s   .next_bit
.high:
        bset    d7,d5
.next_bit:
        addq.w  #1,d7
        dbf     d6,.mask
.advance:
        movea.l a3,a2
        cmpa.l  a5,a2
        blo     .group

        move.l  a4,d0
        beq.s   .empty
        addi.l  #12,d0
        cmp.l   (sp),d0
        bhi.s   .reject
        move.l  a1,d1
        add.l   d0,d1
        bcs.s   .reject
        cmpi.l  #$1000000,d1
        bhi.s   .reject
        cmpa.l  a5,a1
        bhs.s   .separate
        cmpa.l  d1,a0
        blo.s   .reject
.separate:
        move.l  a4,d0
        move.w  d0,(a1)
        move.l  a6,d0
        move.w  d0,2(a1)
        move.l  d4,4(a1)
        move.l  d5,8(a1)
        lea     12(a1),a3
        movea.l a0,a2
        move.w  d7,d6
        subq.w  #1,d6
        moveq   #0,d7
.copy_record:
        cmpi.w  #32,d7
        bhs.s   .test_high
        btst    d7,d4
        bra.s   .selected
.test_high:
        btst    d7,d5
.selected:
        bne.s   .skip
        move.l  (a2)+,(a3)+
        move.l  (a2)+,(a3)+
        move.w  (a2)+,(a3)+
        bra.s   .next_record
.skip:
        adda.w  #10,a2
.next_record:
        addq.w  #1,d7
        dbf     d6,.copy_record
        move.l  a4,d0
        bra.s   .return
.empty:
        moveq   #-2,d0
        bra.s   .return
.reject:
        moveq   #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l   d0
        rts

; Low two bits: suffix count. Bit 7: final suffix type is $29, otherwise
; every suffix type is $04. IDs absent from this table are independent items.
resize_spt_recipes:
        dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $00
        dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $10
        dc.b $00,$00,$00,$00,$00,$00,$00,$00,$83,$00,$83,$83,$83,$00,$00,$00 ; $20
        dc.b $00,$02,$02,$02,$02,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$01 ; $30
        dc.b $01,$01,$00,$00,$00,$82,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $40
        dc.b $82,$82,$82,$00,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; $50
        dc.b $00,$00,$00,$00,$00,$02,$02,$02,$02,$81,$81,$83,$00,$00,$00 ; $60
        even
resize_spt_stage_end:
