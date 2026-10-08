; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef resize_map_stage,resize_map_stage_end

; Build a resized MAP in a separate, caller-owned staging buffer.
; A0=readable source, D0.l=exact source bytes; A1=writable destination,
; D1.l=destination capacity; D2.w=new width, D3.w=new height,
; D4.w=selected graphic tile (0..398). Both pointers must be even.
; Return D0.l=output bytes, or -1 without any destination writes.
; Preserve D1-D7/A0-A6/SP and SR control bits. Stack: 56 bytes plus caller RTS.
; No engine calls, allocations, metadata changes, undo changes or commit.
; Source names and resource ownership require the caller's structural check.
; Input extents must name RAM owned by the caller, never the executing code,
; stack, hardware, another owner or two aliases of the same physical memory.
; Exact source/destination extents may touch but must not overlap. Their ends
; must fit the 24-bit bus. All checks precede the first destination store.
; Keep the top-left overlap, including all cell bits and opaque header bytes.
; New cells contain only D4. Only the two dimension words change in the header.
resize_map_stage:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l  #98,d0
        blo     .reject
        cmpi.l  #15096,d0
        bhi     .reject
        move.l  a0,d5
        move.l  a1,d7
        or.l    d7,d5
        btst    #0,d5
        bne     .reject
        move.l  a0,d5
        add.l   d0,d5
        bcs     .reject
        cmpi.l  #$1000000,d5
        bhi     .reject
        cmpi.w  #19,d2
        blo     .reject
        cmpi.w  #15,d3
        blo     .reject
        cmpi.w  #398,d4
        bhi     .reject
        moveq   #0,d6
        move.w  d2,d6
        mulu    d3,d6
        cmpi.l  #7500,d6
        bhi     .reject
        add.l   d6,d6
        addi.l  #96,d6
        cmp.l   d6,d1
        blo     .reject
        add.l   d6,d7
        bcs     .reject
        cmpi.l  #$1000000,d7
        bhi     .reject
        cmpa.l  d5,a1
        bhs.s   .separate
        cmpa.l  d7,a0
        blo     .reject
.separate:
        cmpi.l  #$63666564,80(a0)
        bne     .reject
        moveq   #0,d5
        move.w  84(a0),d5
        beq.s   .reject
        move.w  86(a0),d7
        beq.s   .reject
        mulu    d7,d5
        cmpi.l  #7500,d5
        bhi.s   .reject
        add.l   d5,d5
        addi.l  #96,d5
        cmp.l   d0,d5
        bne.s   .reject

        movea.l a0,a2
        movea.l a1,a3
        moveq   #23,d0
.header:
        move.l  (a2)+,(a3)+
        dbf     d0,.header
        move.w  d2,84(a1)
        move.w  d3,86(a1)
        ; D5=overlap columns; D7=overlap rows. Fill first, then copy overlap.
        move.w  84(a0),d5
        cmp.w   d2,d5
        bls.s   .width
        move.w  d2,d5
.width:
        move.w  86(a0),d7
        cmp.w   d3,d7
        bls.s   .height
        move.w  d3,d7
.height:
        move.l  d6,d0
        subi.w  #96,d0
        lsr.w   #1,d0
        subq.w  #1,d0
.fill:
        move.w  d4,(a3)+
        dbf     d0,.fill
        lea     96(a1),a3
        move.w  84(a0),d1
        sub.w   d5,d1
        add.w   d1,d1
        sub.w   d5,d2
        add.w   d2,d2
        subq.w  #1,d5
        subq.w  #1,d7
.row:
        move.w  d5,d0
.cell:
        move.w  (a2)+,(a3)+
        dbf     d0,.cell
        adda.w  d1,a2
        adda.w  d2,a3
        dbf     d7,.row
        move.l  d6,d0
        bra.s   .return
.reject:
        moveq   #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l   d0
        rts
resize_map_stage_end:
