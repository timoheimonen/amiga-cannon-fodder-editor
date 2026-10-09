; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Rebase the 37 native hill font descriptors into the owned strip below the
; 48-line tool bar and copy the cached font pixels there; the Object view's
; H marker of invisible anchors draws from it. D0=0, or EDTR_VISUAL_ERROR
; when a descriptor lies outside the cached font; CCR from D0. Clobbers
; D6-D7/A0-A3.
font_strip_prepare:
        lea editor_hill_font_frames,a0
        lea font_frames+PCREL(pc),a1
        moveq #36,d7
.frame:
        movea.l a1,a2
        moveq #3,d6
.copy:
        move.l (a0)+,(a1)+
        dbra d6,.copy
        move.l (a2),d0
        subi.l #native_hill_font_pixels,d0
        cmpi.w #17,d7
        bhs.s .first_strip
        subi.l #240*40,d0
        cmpi.l #520,d0
        bhs.s .invalid
        addi.l #520,d0
        bra.s .rebase
.first_strip:
        cmpi.l #520,d0
        bhs.s .invalid
.rebase:
        addi.l #BAR_BITMAP+BAR_FONT_STRIP,d0
        move.l d0,(a2)
        move.w #BAR_PLANE,12(a2)
        dbra d7,.frame
        move.l #-1,(a1)
        lea font_table+PCREL(pc),a0
        moveq #13,d0
.table:
        move.l #font_frames,(a0)+
        dbra d0,.table
        lea native_hill_cache,a0
        lea BAR_BITMAP,a1
        moveq #3,d7
.plane:
        movea.l a1,a2
        move.w #BAR_FONT_STRIP/4-1,d0
.clear:
        clr.l (a2)+
        dbra d0,.clear
        movea.l a0,a3
        move.w #520/4-1,d0
.first:
        move.l (a3)+,(a2)+
        dbra d0,.first
        lea 240*40(a0),a3
        move.w #520/4-1,d0
.second:
        move.l (a3)+,(a2)+
        dbra d0,.second
        lea $2800(a0),a0
        lea BAR_PLANE(a1),a1
        dbra d7,.plane
        moveq #0,d0
        rts
.invalid:
        moveq #EDTR_VISUAL_ERROR,d0
        rts
