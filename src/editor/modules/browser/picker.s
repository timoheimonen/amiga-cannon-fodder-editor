; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Synchronous text editing on a caller-owned hill-font display. Link text.s
; from the controller for text_preflight. UI bytes 0..95 remain caller-owned.
PICKER_BASE       equ EDITOR_UI_BASE+96
picker_magic      equ PICKER_BASE
picker_source     equ PICKER_BASE+4
picker_limit      equ PICKER_BASE+8
picker_hill_width equ PICKER_BASE+10
picker_brief_width equ PICKER_BASE+12
picker_length     equ PICKER_BASE+14
picker_width      equ PICKER_BASE+16
picker_held       equ PICKER_BASE+18
picker_index      equ PICKER_BASE+20
picker_error      equ PICKER_BASE+22
picker_number     equ PICKER_BASE+24
picker_edit       equ PICKER_BASE+32
picker_projected  equ PICKER_BASE+96
PICKER_BYTES      equ 160
PICKER_MAGIC      equ $54585031
PICKER_BACKSPACE  equ -1
PICKER_CLEAR      equ -2
PICKER_ACCEPT     equ -3
PICKER_CANCEL     equ -4

        xdef text_picker_begin,text_picker_event,text_picker_end

; A0=mutable source[64], D0.w=max length1..63, D1.w=hill width1..288,
; D2.w=briefing width0..320 (0 skips that font). Source is NUL-terminated.
; D0=0 success, -1 invalid arguments, -2 glyph, -3 width, -5 length.
; Empty input is allowed. Source is unchanged until ACCEPT. Other registers
; and SP are preserved; the fixed 160-byte context is scratch on failure.
text_picker_begin:
        movem.l d1-d7/a0-a6,-(sp)
        clr.l picker_magic
        tst.w d0
        beq .invalid
        cmpi.w #63,d0
        bhi .invalid
        tst.w d1
        beq .invalid
        cmpi.w #TITLE_HILL_WIDTH,d1
        bhi.s .invalid
        cmpi.w #320,d2
        bhi.s .invalid
        move.l a0,d3
        addi.l #64,d3
        bcs.s .invalid
        cmpi.l #PICKER_BASE,d3
        bls.s .disjoint
        cmpa.l #PICKER_BASE+PICKER_BYTES,a0
        blo.s .invalid
.disjoint:
        move.l a0,picker_source
        move.w d0,picker_limit
        move.w d1,picker_hill_width
        move.w d2,picker_brief_width
        clr.w picker_held
        clr.w picker_error
        lea picker_edit,a1
        moveq #0,d3
.copy:
        move.b (a0)+,d4
        beq.s .terminated
        cmp.w picker_limit,d3
        bhs.s .length
        move.b d4,(a1)+
        addq.w #1,d3
        bra.s .copy
.terminated:
        clr.b (a1)
        move.w d3,picker_length
        bsr picker_measure
        tst.w d0
        bne.s .return
        move.l #PICKER_MAGIC,picker_magic
        bra.s .return
.length:
        moveq #-5,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; D0.w=ASCII character or PICKER_* action. D0=0 edited,1 accepted,2 cancelled;
; negative statuses refuse the event without changing the source. -6 is empty.
; Every refused insertion leaves the editable text and width unchanged.
text_picker_event:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l #PICKER_MAGIC,picker_magic
        bne .invalid
        cmpi.w #PICKER_CANCEL,d0
        beq .cancel
        cmpi.w #PICKER_ACCEPT,d0
        beq .accept
        cmpi.w #PICKER_CLEAR,d0
        beq.s .clear
        cmpi.w #PICKER_BACKSPACE,d0
        beq.s .backspace
        cmpi.w #' ',d0
        blo .invalid
        cmpi.w #'~',d0
        bhi .invalid
        move.w picker_length,d4
        cmp.w picker_limit,d4
        bhs .length
        move.w picker_width,d5
        lea picker_edit,a0
        move.b d0,(a0,d4.w)
        clr.b 1(a0,d4.w)
        addq.w #1,picker_length
        bsr picker_measure
        tst.w d0
        beq .return
        lea picker_edit,a0
        clr.b (a0,d4.w)
        move.w d4,picker_length
        move.w d5,picker_width
        bra.s .return
.clear:
        clr.w picker_length
        clr.b picker_edit
        bra.s .measure
.backspace:
        move.w picker_length,d0
        beq.s .measure
        subq.w #1,d0
        move.w d0,picker_length
        lea picker_edit,a0
        clr.b (a0,d0.w)
.measure:
        bsr.s picker_measure
        bra.s .return
.accept:
        tst.w picker_length
        beq.s .empty
        bsr.s picker_measure
        tst.w d0
        bne.s .return
        lea picker_edit,a0
        movea.l picker_source,a1
        move.w picker_length,d1
.publish:
        move.b (a0)+,(a1)+
        dbf d1,.publish
        clr.l picker_magic
        moveq #1,d0
        bra.s .return
.cancel:
        clr.l picker_magic
        moveq #2,d0
        bra.s .return
.empty:
        moveq #-6,d0
        bra.s .return
.length:
        moveq #-5,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        move.w d0,picker_error
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

picker_measure:
        movem.l d1-d3/a0-a1,-(sp)
        moveq #0,d0
        move.w picker_length,d0
        bne.s .hill
        clr.w picker_width
        bra.s .return
.hill:
        lea picker_edit,a0
        lea picker_projected,a1
        moveq #0,d1
        move.w picker_hill_width,d2
        moveq #1,d3
        bsr text_preflight
        tst.w d0
        bne.s .return
        move.w d1,picker_width
        tst.w picker_brief_width
        beq.s .return
        moveq #0,d0
        move.w picker_length,d0
        moveq #1,d1
        move.w picker_brief_width,d2
        bsr text_preflight
.return:
        movem.l (sp)+,d1-d3/a0-a1
        tst.w d0
        rts

picker_characters: dc.b "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        even
text_picker_end:
        ifgt PICKER_BASE+PICKER_BYTES-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Text picker exceeds caller's UI slice"
        endif
