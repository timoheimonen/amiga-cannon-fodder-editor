; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef template_rnc_unpack,template_rnc_end

; Bounded RNC method 1 decoder for separate caller-owned staging buffers.
; A0/D0.l = even input pointer/exact bytes; A1/D1.l = even output/capacity.
; D0.l = decoded bytes, or -1. All other registers/SP/SR control preserved.
; Failure can leave partial output: no failed stage is authoritative.
; Source, destination capacity, code and stack must be distinct owned RAM.
; Scratch is a 216-byte stack frame plus saved registers and helper frames.
RNC_SOURCE_END  equ 0
RNC_OUTPUT_BASE equ 4
RNC_OUTPUT_END  equ 8
RNC_OUTPUT_SIZE equ 12
RNC_OUTPUT_CRC  equ 16
RNC_BITS_COUNT  equ 18
RNC_BITS        equ 20
RNC_TABLES      equ 24
RNC_FRAME       equ 216

template_rnc_unpack:
        movem.l d1-d7/a0-a6,-(sp)
        lea -RNC_FRAME(sp),sp
        movea.l sp,a6
        cmpi.l #18,d0
        blo rnc_bad
        move.l a0,d2
        move.l a1,d3
        move.l d2,d4
        or.l d3,d4
        btst #0,d4
        bne rnc_bad
        add.l d0,d2
        bcs rnc_bad
        cmpi.l #$1000000,d2
        bhi rnc_bad
        move.l d2,RNC_SOURCE_END(a6)
        add.l d1,d3
        bcs rnc_bad
        cmpi.l #$1000000,d3
        bhi rnc_bad
        cmpa.l d2,a1
        bhs.s .disjoint
        cmpa.l d3,a0
        blo rnc_bad
.disjoint:
        cmpi.l #$524E4301,(a0)
        bne rnc_bad
        subi.l #18,d0
        cmp.l 8(a0),d0
        bne rnc_bad
        move.l 4(a0),d2
        beq rnc_bad
        cmp.l d1,d2
        bhi rnc_bad
        move.l a1,RNC_OUTPUT_BASE(a6)
        move.l d2,RNC_OUTPUT_SIZE(a6)
        add.l a1,d2
        move.l d2,RNC_OUTPUT_END(a6)
        move.w 12(a0),RNC_OUTPUT_CRC(a6)
        moveq #0,d7
        move.b 17(a0),d7
        beq rnc_bad
        move.w 14(a0),d5
        movea.l a1,a5
        lea 18(a0),a4
        movea.l a4,a0
        move.l RNC_SOURCE_END(a6),d1
        sub.l a0,d1
        bsr rnc_crc16
        cmp.w d5,d0
        bne rnc_bad
        clr.w RNC_BITS_COUNT(a6)
        clr.l RNC_BITS(a6)
        moveq #2,d0
        bsr rnc_read_bits
        tst.l d0
        bne rnc_bad
.block:
        lea RNC_TABLES(a6),a3
        bsr rnc_read_table
        tst.l d0
        bmi rnc_bad
        lea RNC_TABLES+64(a6),a3
        bsr rnc_read_table
        tst.l d0
        bmi rnc_bad
        lea RNC_TABLES+128(a6),a3
        bsr rnc_read_table
        tst.l d0
        bmi rnc_bad
        moveq #16,d0
        bsr rnc_read_bits
        tst.l d0
        ble rnc_bad
        move.w d0,d6
        subq.w #1,d6
.run:
        lea RNC_TABLES(a6),a3
        bsr rnc_read_value
        tst.l d0
        bmi rnc_bad
        tst.w d0
        beq.s .literal_done
        move.l a4,d1
        add.l d0,d1
        cmp.l RNC_SOURCE_END(a6),d1
        bhi.s rnc_bad
        move.l a5,d1
        add.l d0,d1
        cmp.l RNC_OUTPUT_END(a6),d1
        bhi.s rnc_bad
        subq.w #1,d0
.literal:
        move.b (a4)+,(a5)+
        dbf d0,.literal
.literal_done:
        tst.w d6
        beq.s .block_done
        lea RNC_TABLES+64(a6),a3
        bsr rnc_read_value
        tst.l d0
        bmi.s rnc_bad
        addq.l #1,d0
        move.l d0,d5
        lea RNC_TABLES+128(a6),a3
        bsr rnc_read_value
        tst.l d0
        bmi.s rnc_bad
        addq.l #2,d0
        move.l a5,d1
        sub.l d5,d1
        bcs.s rnc_bad
        cmp.l RNC_OUTPUT_BASE(a6),d1
        blo.s rnc_bad
        movea.l d1,a0
        move.l a5,d1
        add.l d0,d1
        cmp.l RNC_OUTPUT_END(a6),d1
        bhi.s rnc_bad
        subq.w #1,d0
.copy:
        move.b (a0)+,(a5)+
        dbf d0,.copy
        subq.w #1,d6
        bra.s .run
.block_done:
        subq.w #1,d7
        bne .block
        cmpa.l RNC_OUTPUT_END(a6),a5
        bne.s rnc_bad
        movea.l RNC_OUTPUT_BASE(a6),a0
        move.l RNC_OUTPUT_SIZE(a6),d1
        bsr rnc_crc16
        cmp.w RNC_OUTPUT_CRC(a6),d0
        bne.s rnc_bad
        move.l RNC_OUTPUT_SIZE(a6),d0
        bra.s rnc_return
rnc_bad:
        moveq #-1,d0
rnc_return:
        lea RNC_FRAME(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; D0.w requested bits (1..16), returns unsigned value or -1.
; Clobbers D1/D2; A4 advances in little-endian words, with zero odd padding.
rnc_read_bits:
        move.w d0,d2
        moveq #0,d1
        move.w RNC_BITS_COUNT(a6),d1
        cmp.w d2,d1
        bhs.s .ready
        cmpa.l RNC_SOURCE_END(a6),a4
        bhs.s .bad
        moveq #0,d0
        move.b (a4)+,d0
        cmpa.l RNC_SOURCE_END(a6),a4
        bhs.s .odd
        move.b (a4)+,d0
        lsl.w #8,d0
        move.b -2(a4),d0
        bra.s .word
.odd:
        addq.l #1,a4
.word:
        lsl.l d1,d0
        or.l d0,RNC_BITS(a6)
        addi.w #16,RNC_BITS_COUNT(a6)
.ready:
        move.l RNC_BITS(a6),d0
        moveq #-1,d1
        lsl.l d2,d1
        not.l d1
        and.l d1,d0
        move.l RNC_BITS(a6),d1
        lsr.l d2,d1
        move.l d1,RNC_BITS(a6)
        sub.w d2,RNC_BITS_COUNT(a6)
        rts
.bad:
        moveq #-1,d0
        rts

; A3 = 16 (length.w, canonical-code.w) entries. D0=0/-1.
; Clobbers D1/D2/A0; preserves the block/run and output-copy registers.
rnc_read_table:
        movem.l d3-d7/a3,-(sp)
        movea.l a3,a0
        moveq #15,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        moveq #5,d0
        bsr.s rnc_read_bits
        tst.l d0
        bmi.s .bad
        cmpi.w #16,d0
        bhi.s .bad
        move.w d0,d6
        beq.s .codes
        movea.l a3,a0
        subq.w #1,d6
.length:
        moveq #4,d0
        bsr.s rnc_read_bits
        tst.l d0
        bmi.s .bad
        move.w d0,(a0)
        addq.l #4,a0
        dbf d6,.length
.codes:
        moveq #0,d3
        moveq #1,d4
.level:
        add.l d3,d3
        moveq #1,d6
        lsl.l d4,d6
        moveq #15,d5
        movea.l a3,a0
.symbol:
        cmp.w (a0),d4
        bne.s .next
        cmp.l d6,d3
        bhs.s .bad
        move.w d3,2(a0)
        addq.l #1,d3
.next:
        addq.l #4,a0
        dbf d5,.symbol
        addq.w #1,d4
        cmpi.w #16,d4
        blo.s .level
        moveq #0,d0
        bra.s .return
.bad:
        moveq #-1,d0
.return:
        movem.l (sp)+,d3-d7/a3
        rts

; A3 = table; D0 returns expanded unsigned value or -1.
; Clobbers D1/D2/A0, preserves D3-D7/A3-A6.
rnc_read_value:
        movem.l d3-d5/a3,-(sp)
        moveq #0,d3
        moveq #1,d4
.bit:
        moveq #1,d0
        bsr rnc_read_bits
        tst.l d0
        bmi.s .bad
        add.w d3,d3
        or.w d0,d3
        moveq #0,d5
        movea.l a3,a0
.symbol:
        cmp.w (a0),d4
        bne.s .next
        cmp.w 2(a0),d3
        beq.s .found
.next:
        addq.l #4,a0
        addq.w #1,d5
        cmpi.w #16,d5
        blo.s .symbol
        addq.w #1,d4
        cmpi.w #16,d4
        blo.s .bit
.bad:
        moveq #-1,d0
        bra.s .return
.found:
        move.w d5,d0
        cmpi.w #2,d0
        blo.s .return
        subq.w #1,d5
        move.w d5,d0
        bsr rnc_read_bits
        tst.l d0
        bmi.s .return
        bset d5,d0
.return:
        movem.l (sp)+,d3-d5/a3
        rts

; A0/D1.l = bytes. D0.w = CRC-16/ARC; clobbers D1-D3/A0.
rnc_crc16:
        moveq #0,d0
        tst.l d1
        beq.s .return
.byte:
        moveq #0,d3
        move.b (a0)+,d3
        eor.w d3,d0
        moveq #7,d2
.bit:
        lsr.w #1,d0
        bcc.s .next
        eori.w #$A001,d0
.next:
        dbf d2,.bit
        subq.l #1,d1
        bne.s .byte
.return:
        rts

template_rnc_end:
