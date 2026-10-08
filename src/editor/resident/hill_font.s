; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_hill_font_exchange

; Exchange only the eight native hill-font pixel strips with their Chip positions.
; Two calls restore both images exactly. No storage allocation or engine calls.
; Caller owns the stopped phase and must exclude native hill/modal/completion,
; cache reloads, and unrelated users of these Chip rows until the second call.
; Descriptor pointers, masks and drawing remain the caller's responsibility.
; Preserves all registers, SR and SP. Local stack26 bytes, plus caller JSR4.
editor_hill_font_exchange:
        move.w  sr,-(sp)
        movem.l d0-d3/a0-a1,-(sp)
        lea     native_hill_cache,a0
        lea     native_hill_font_pixels,a1
        moveq   #7,d3
        move.w  #9080,d1
.strip:
        move.w  #129,d2
.long:
        move.l  (a0),d0
        move.l  (a1),(a0)+
        move.l  d0,(a1)+
        dbra    d2,.long
        adda.w  d1,a0
        adda.w  d1,a1
        eori.w  #9080^120,d1
        dbra    d3,.strip
        movem.l (sp)+,d0-d3/a0-a1
        move.w  (sp)+,sr
        rts
