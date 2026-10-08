; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Synchronous internal callback. The inline word after BSR is
; severity(bit15), location(bits8..9), rule(low8). Skip it on return.
; Preserve all registers and the entire incoming SR, including BSET's Z.
; Row16: ordinal.l,severity.b,rule.b,phase.b,location.b,index.w,x.w,y.w,zero.w.
; All validation-rule branches remain in the original validator.
vald_emit:
        move.w sr,-(sp)
        movem.l d0-d3/a0-a1,-(sp)
        movea.l 26(sp),a1
        moveq #0,d0
        move.w (a1)+,d0
        move.l a1,26(sp)
        tst.w d0
        bmi.s .review_count
        addq.l #1,VD_ERRORS
        bra.s .counted
.review_count:
        addq.l #1,VD_REVIEWS
.counted:
        move.l VD_TOTAL,d1
        addq.l #1,VD_TOTAL
        cmp.l VD_SKIP,d1
        blo .return
        move.w VD_WRITTEN,d2
        cmp.w VD_CAPACITY,d2
        bhs .return
        addq.w #1,VD_WRITTEN
        lsl.w #4,d2
        lea VD_ROWS,a0
        adda.w d2,a0
        move.l d1,(a0)
        move.b d0,5(a0)
        move.b CFMD_PHASE_INDEX(a2),6(a0)
        move.w d0,d1
        lsr.w #8,d1
        move.w d1,d2
        lsr.w #7,d2
        move.b d2,4(a0)
        andi.w #3,d1
        move.b d1,7(a0)
        move.l #-1,8(a0)
        move.w #-1,12(a0)
        clr.w 14(a0)
        movea.l 16(sp),a1
        cmpi.w #1,d1
        beq.s .cell
        cmpi.w #2,d1
        beq.s .object
        cmpi.w #3,d1
        bne.s .return
        ; The aggregate marker-capacity issue points at its eleventh marker.
        lea 96(a5),a1
        moveq #0,d2
        move.w CFVR_WIDTH(a4),d2
        mulu.w CFVR_HEIGHT(a4),d2
        subq.w #1,d2
        moveq #10,d3
.marker:
        move.w (a1)+,d1
        andi.w #$E000,d1
        beq.s .next_marker
        dbra d3,.next_marker
        move.b #1,7(a0)
        bra.s .cell
.next_marker:
        dbra d2,.marker
        ; Unreachable for a structurally valid validator call; remain global.
        clr.b 7(a0)
        bra.s .return
.cell:
        move.l a1,d2
        sub.l a5,d2
        subi.l #98,d2
        lsr.l #1,d2
        move.w d2,8(a0)
        move.l d2,d3
        divu.w CFVR_WIDTH(a4),d3
        move.w d3,12(a0)
        swap d3
        move.w d3,10(a0)
        bra.s .return
.object:
        move.w d7,8(a0)
        move.w 4(a1),10(a0)
        move.w 6(a1),12(a0)
.return:
        movem.l (sp)+,d0-d3/a0-a1
        move.w (sp)+,sr
        rts
