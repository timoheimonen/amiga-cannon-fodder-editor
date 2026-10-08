; Cannon Fodder In-Game Level Editor V1.0
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
