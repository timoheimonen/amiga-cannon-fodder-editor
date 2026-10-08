; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef edtr_modal,edtr_modal_idle
        xdef edtr_modal_finish,edtr_modal_end

EXIT_UI                 equ EDITOR_UI_BASE
EXIT_KIND               equ EXIT_UI+116
EXIT_ERROR              equ EXIT_UI+118
EXIT_CHOICE             equ EXIT_UI+120
EXIT_TEXT               equ EXIT_UI+128
EXIT_NUMBER             equ EXIT_UI+192
EXIT_UI_BYTES           equ 224
DIALOG_LARGE_ONLY       equ 1

; FILL modal: the large-change confirmation of the Slave's dialog service.
; D0.w=LARGE only, D1.w=0. Pending FILL is required.
; Returns D0=0 Cancel,1 Continue, negative on refused ownership.
; Preserves D1-D7/A0-A6/SP. Requires complete exit_view before entry.
; Owns UI116..121 until return. No disk calls. Escape also cancels the
; pending fill through fill_poll.
edtr_modal:
        movem.l d1-d7/a0-a6,-(sp)
        move.w  d0,d7
        move.w  d1,d6
        cmpi.w  #EDTR_DIALOG_LARGE,d7
        bne.s   exit_ui_refuse
        tst.w   d6
        bne.s   exit_ui_refuse
        tst.w   edtr_view_live
        bne.s   exit_ui_refuse
        bsr     fill_owner
        bne.s   exit_ui_refuse
        move.w  d7,EXIT_KIND
        clr.w   EXIT_ERROR
        clr.w   EXIT_CHOICE
        bsr     dialog_standard_open
        bne.s   exit_ui_refuse
        bsr     fill_poll
        bne.s   edtr_modal_finish

edtr_modal_idle:
        jsr     wait_frame
        bsr     fill_poll
        bne.s   edtr_modal_finish
        bsr.s   dialog_poll
        bmi.s   edtr_modal_idle
        move.w  d0,EXIT_CHOICE

edtr_modal_finish:
        bsr.s   dialog_close
        ; Preserve an Escape edge delivered while the display was restored.
        bsr     fill_poll
        bsr.s   dialog_release
        moveq   #0,d0
        move.w  EXIT_CHOICE,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
exit_ui_refuse:
        moveq   #EDTR_VISUAL_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

exit_ui_blitter_idle:
        btst    #6,amiga_dmacon_read
        bne.s   exit_ui_blitter_idle
        rts
edtr_modal_end:
        ifgt EXIT_UI+EXIT_UI_BYTES-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Modal scratch exceeds UI storage"
        endif
