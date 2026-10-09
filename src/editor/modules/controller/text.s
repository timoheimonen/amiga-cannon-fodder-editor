; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef text_preflight

; A0=read-only ASCII source, D0.l=exact length (1..63), A1=64-byte output.
; D1.w=font (0: hill group13, 1: briefing group1), D2.w=available width
; (1..320), D3.w=flags (bit0: explicitly project a..z to A..Z).
; Source and the complete output span must be disjoint. No engine calls.
; Success: D0=0, D1.l=pixel advance, D2.l=(available-advance)/2;
; writes projected bytes followed by FF, leaving the unused tail unchanged.
; Failure: D0=-1 argument, -2 unsupported glyph, -3 width, -4 overlap;
; D1/D2=0, and all output bytes remain unchanged. Authored bytes never change.
; Preserves D3-D7/A0-A6/SP. CCR undefined. Stack: 32 bytes plus caller JSR.
; Rendering requires matching installed descriptors, zero space substitution
; and zero alternate-renderer mode. This routine does not install font assets.
text_preflight:
        movem.l d3-d7/a2-a4,-(sp)
        tst.l   d0
        beq     .argument
        cmpi.l  #63,d0
        bhi     .argument
        cmpi.w  #1,d1
        bhi     .argument
        tst.w   d2
        beq     .argument
        cmpi.w  #320,d2
        bhi     .argument
        cmpi.w  #1,d3
        bhi     .argument
        move.l  a0,d4
        add.l   d0,d4
        bcs     .argument
        move.l  a1,d5
        addi.l  #64,d5
        bcs     .argument
        cmp.l   a0,d5
        bls.s   .disjoint
        cmp.l   a1,d4
        bhi     .overlap
.disjoint:
        lea     native_hill_widths,a2
        tst.w   d1
        beq.s   .font_ready
        lea     native_briefing_font,a2
.font_ready:
        movea.w d1,a4
        moveq   #0,d1
        move.l  a0,a3
        move.w  d0,d6
        subq.w  #1,d6
        moveq   #0,d7
.check:
        moveq   #0,d4
        move.b  (a3)+,d4
        cmpi.b  #'a',d4
        blo.s   .not_lower
        cmpi.b  #'z',d4
        bhi.s   .not_lower
        btst    #0,d3
        beq     .glyph
        subi.b  #32,d4
.not_lower:
        cmpi.b  #' ',d4
        beq.s   .width
        cmpi.b  #39,d4
        bne.s   .not_apostrophe
        cmpa.w  #0,a4
        beq     .glyph
        bra.s   .width
.not_apostrophe:
        cmpi.b  #'0',d4
        blo     .glyph
        cmpi.b  #'9',d4
        bls.s   .width
        cmpi.b  #'A',d4
        blo.s   .glyph
        cmpi.b  #'Z',d4
        bhi.s   .glyph
.width:
        moveq   #0,d5
        move.b  (a2,d4.w),d5
        add.w   d5,d7
        cmp.w   d2,d7
        bhi.s   .wide
        move.w  d7,d5
        cmpa.w  #0,a4
        bne.s   .briefing_ink
        cmpi.b  #'A',d4
        bne.s   .ink_end
        bra.s   .overhang
.briefing_ink:
        cmpi.b  #'Y',d4
        beq.s   .overhang
        cmpi.b  #'3',d4
        bne.s   .ink_end
.overhang:
        addq.w  #1,d5
.ink_end:
        cmp.w   d1,d5
        bls.s   .next
        move.w  d5,d1
.next:
        dbra    d6,.check
        move.w  d2,d5
        sub.w   d7,d2
        lsr.w   #1,d2
        add.w   d2,d1
        cmp.w   d5,d1
        bhi.s   .wide
        moveq   #0,d1
        move.w  d7,d1
        andi.l  #$FFFF,d2
        move.l  a0,a2
        move.l  a1,a3
        subq.w  #1,d0
.copy:
        move.b  (a2)+,d4
        cmpi.b  #'a',d4
        blo.s   .store
        cmpi.b  #'z',d4
        bhi.s   .store
        subi.b  #32,d4
.store:
        move.b  d4,(a3)+
        dbra    d0,.copy
        move.b  #$FF,(a3)
        moveq   #0,d0
        bra.s   .return
.argument:
        moveq   #-1,d0
        bra.s   .failed
.glyph:
        moveq   #-2,d0
        bra.s   .failed
.wide:
        moveq   #-3,d0
        bra.s   .failed
.overlap:
        moveq   #-4,d0
.failed:
        moveq   #0,d1
        moveq   #0,d2
.return:
        movem.l (sp)+,d3-d7/a2-a4
        rts
