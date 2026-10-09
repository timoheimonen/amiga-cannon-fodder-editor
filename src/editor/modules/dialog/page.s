; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef edtr_modal,edtr_modal_idle
        xdef edtr_modal_finish,edtr_modal_end

; Mode 2 modal of a page overlay: one dialog of the Slave's dialog service.
; The includer provides open_owner, page_open (D0.l=0 when the dialog is
; open) and page_step, one frame of input that continues at edtr_modal_idle
; or, with EXIT_CHOICE set, at edtr_modal_finish.
; D0.w=0. Returns D0=EXIT_CHOICE, negative on refused ownership. Preserves
; D1-D7/A0-A6/SP. Requires complete exit_view before entry. Owns the 224
; bytes at EXIT_UI until return. No disk calls.
; An includer whose WORK160..383 is in use defines EXIT_UI first.
        ifnd EXIT_UI
EXIT_UI             equ EDITOR_SERIAL_WORK_BASE+160
        endif
EXIT_LIST           equ EXIT_UI
EXIT_CHOICE         equ EXIT_UI+120
EXIT_HELD           equ EXIT_UI+122
EXIT_TEXT           equ EXIT_UI+128
EXIT_NUMBER         equ EXIT_UI+192
EXIT_UI_BYTES       equ 224

edtr_modal:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w d0
        bne.s page_refuse
        bsr open_owner
        bne.s page_refuse
        clr.w EXIT_CHOICE
        bsr page_open
        bne.s page_refuse

edtr_modal_idle:
        jsr wait_frame
        bra page_step

edtr_modal_finish:
        bsr.s dialog_close
        bsr.s dialog_release
        moveq #0,d0
        move.w EXIT_CHOICE,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
page_refuse:
        moveq #EDTR_VISUAL_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts
edtr_modal_end:
        ifgt EXIT_UI+EXIT_UI_BYTES-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Page dialog scratch exceeds WORK storage"
        endif
