; Cannon Fodder In-Game Level Editor V1.2.6
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
; Nonzero while the whole begun text is selected: typing replaces it.
picker_selected   equ PICKER_BASE+18
; Insertion cursor position 0..picker_length.
picker_index      equ PICKER_BASE+20
picker_cursor     equ PICKER_BASE+20
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
PICKER_KEEP       equ -5
PICKER_LEFT       equ -6
PICKER_RIGHT      equ -7
PICKER_DELETE     equ -8

        xdef text_picker_begin,text_picker_event,text_picker_end

; A0=mutable source[64], D0.w=max length1..63, D1.w=hill width1..288,
; D2.w=briefing width0..320 (0 skips that font). Source is NUL-terminated.
; D0=0 success, -1 invalid arguments, -2 glyph, -3 width, -5 length.
; Empty input is allowed. Source is unchanged until ACCEPT. Other registers
; and SP are preserved; the fixed 160-byte context is scratch on failure.
; A nonempty text starts selected.
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
        bhi .invalid
        cmpi.w #320,d2
        bhi .invalid
        move.l a0,d3
        addi.l #64,d3
        bcs .invalid
        cmpi.l #PICKER_BASE,d3
        bls.s .disjoint
        cmpa.l #PICKER_BASE+PICKER_BYTES,a0
        blo .invalid
.disjoint:
        move.l a0,picker_source
        move.w d0,picker_limit
        move.w d1,picker_hill_width
        move.w d2,picker_brief_width
        clr.w picker_selected
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
        move.w d3,picker_selected
        move.w d3,picker_cursor
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
; While the text is selected a character replaces it, Backspace erases it and
; KEEP (a cursor key) only ends the selection.
text_picker_event:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l #PICKER_MAGIC,picker_magic
        bne .invalid
        cmpi.w #PICKER_CANCEL,d0
        beq .cancel
        cmpi.w #PICKER_ACCEPT,d0
        beq .accept
        cmpi.w #PICKER_KEEP,d0
        beq .keep
        cmpi.w #PICKER_LEFT,d0
        beq .left
        cmpi.w #PICKER_RIGHT,d0
        beq .right
        cmpi.w #PICKER_DELETE,d0
        beq .delete
        cmpi.w #PICKER_CLEAR,d0
        beq .clear
        cmpi.w #PICKER_BACKSPACE,d0
        beq .backspace
        cmpi.w #' ',d0
        blo .invalid
        cmpi.w #'~',d0
        bhi .invalid
        tst.w picker_selected
        bne .replace
        move.w picker_length,d4
        cmp.w picker_limit,d4
        bhs .length
        move.w picker_width,d5
        move.w picker_cursor,d6
        cmp.w d4,d6
        bls.s .ins_ok
        move.w d4,d6
        move.w d6,picker_cursor
.ins_ok:
        lea picker_edit,a0
        move.w d4,d3
.ins_shift:
        move.b (a0,d3.w),1(a0,d3.w)
        cmp.w d6,d3
        beq.s .ins_store
        subq.w #1,d3
        bra.s .ins_shift
.ins_store:
        move.b d0,(a0,d6.w)
        addq.w #1,picker_length
        bsr picker_measure
        tst.w d0
        bne.s .ins_revert
        addq.w #1,picker_cursor
        bra .return
.ins_revert:
        lea picker_edit,a0
        move.w d6,d3
.ins_un:
        move.b 1(a0,d3.w),(a0,d3.w)
        cmp.w d4,d3
        beq.s .ins_restored
        addq.w #1,d3
        bra.s .ins_un
.ins_restored:
        move.w d4,picker_length
        move.w d5,picker_width
        bra .return
.replace:
        lea picker_edit,a0
        move.w (a0),d6
        move.w picker_length,d4
        move.w picker_width,d5
        move.b d0,(a0)
        clr.b 1(a0)
        move.w #1,picker_length
        bsr picker_measure
        tst.w d0
        bne.s .restore
        clr.w picker_selected
        move.w #1,picker_cursor
        bra .return
.restore:
        move.w d6,picker_edit
        move.w d4,picker_length
        move.w d5,picker_width
        bra .return
.left:
        tst.w picker_selected
        beq.s .left_step
        clr.w picker_selected
        clr.w picker_cursor
        bra .measure
.left_step:
        tst.w picker_cursor
        beq .measure
        subq.w #1,picker_cursor
        bra .measure
.right:
        tst.w picker_selected
        bne.s .keep
        move.w picker_cursor,d0
        cmp.w picker_length,d0
        bhs .measure
        addq.w #1,picker_cursor
        bra .measure
.keep:
        clr.w picker_selected
        move.w picker_length,picker_cursor
        bra .measure
.clear:
        clr.w picker_selected
        clr.w picker_length
        clr.w picker_cursor
        clr.b picker_edit
        bra .measure
.delete:
        tst.w picker_selected
        bne.s .clear
        move.w picker_cursor,d3
        move.w picker_length,d4
        cmp.w d4,d3
        bhs .measure
        bra.s .erase_at
.backspace:
        tst.w picker_selected
        bne.s .clear
        move.w picker_cursor,d3
        beq .measure
        subq.w #1,d3
        move.w d3,picker_cursor
        move.w picker_length,d4
.erase_at:
        lea picker_edit,a0
.del_shift:
        move.b 1(a0,d3.w),(a0,d3.w)
        addq.w #1,d3
        cmp.w d4,d3
        blo.s .del_shift
        subq.w #1,picker_length
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
