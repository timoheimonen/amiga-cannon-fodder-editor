; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Calls into the Slave's dialog service (dialog.i). Every routine preserves
; all registers except D0 and returns with the flags of D0.l.

; A0=descriptor, D2.l=mask of disabled buttons. D0.l=0 open, 10 refused.
dialog_open:
        moveq #DIALOG_OPEN,d0
        bra.s dialog_call
; D0.l=-1 nothing chosen yet, otherwise the chosen code.
dialog_poll:
        moveq #DIALOG_POLL,d0
        bra.s dialog_call
dialog_close:
        moveq #DIALOG_CLOSE,d0
        bra.s dialog_call
; A0=UI command list drawn into the open panel.
dialog_draw:
        moveq #DIALOG_DRAW,d0
        bra.s dialog_call
; D2.w=button index, D3.w=state, A0=new label or 0.
dialog_set:
        moveq #DIALOG_SET,d0
dialog_call:
        move.l d1,-(sp)
        move.w d0,d1
        moveq #DIALOG_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        move.l (sp)+,d1
        tst.l d0
        rts

        ifd DIALOG_LIST_CLICKS
; A click on list row D0.w; A0 holds the row and field of the last click.
; D1.l=1 for a double click (the same row within DIALOG_DOUBLE_CLICK
; fields), otherwise 0. Records the click; a double click is not counted
; again by a third. Preserves all other registers.
dialog_double:
        movem.l d2-d3,-(sp)
        move.w native_field_counter,d2
        move.w d2,d3
        sub.w 2(a0),d3
        move.w d2,2(a0)
        moveq #0,d1
        cmp.w (a0),d0
        bne.s .record
        cmpi.w #DIALOG_DOUBLE_CLICK,d3
        bhs.s .record
        moveq #1,d1
        move.w #-1,(a0)
        bra.s .done
.record:
        move.w d0,(a0)
.done:
        movem.l (sp)+,d2-d3
        tst.l d1
        rts
        endif

; Wait until both mouse buttons are up, so the click that closed a dialog
; does not reach the screen behind it, and drop pending input.
dialog_release:
        clr.w native_last_key
        jsr wait_frame
        tst.w native_left_down
        bne.s dialog_release
        tst.w native_right_down
        bne.s dialog_release
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
        rts
