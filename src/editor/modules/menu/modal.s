; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef edtr_modal,edtr_modal_idle
        xdef edtr_modal_finish,edtr_modal_end

EXIT_UI                 equ EDITOR_SERIAL_WORK_BASE+160
; A dialog's scratch command list.
EXIT_LIST               equ EXIT_UI
EXIT_KIND               equ EXIT_UI+116
EXIT_ERROR              equ EXIT_UI+118
EXIT_CHOICE             equ EXIT_UI+120
EXIT_HELD               equ EXIT_UI+122
; Nonzero while a dialog of the Slave's dialog service is open.
EXIT_NEW                equ EXIT_UI+126
EXIT_TEXT               equ EXIT_UI+128
EXIT_NUMBER             equ EXIT_UI+192
EXIT_UI_BYTES           equ 224

; Mode 2 modal: every kind is a dialog of the Slave's dialog service.
; D0.w=dialog kind; D1.w is a signed error (0 none).
; Returns D0=0 CANCEL/OK,1 SAVE,2 EXIT/DISCARD, negative on refused ownership.
; Preserves D1-D7/A0-A6/SP. Requires complete exit_view before entry.
; Owns WORK160..383 until return. No disk calls.
edtr_modal:
        movem.l d1-d7/a0-a6,-(sp)
        move.w  d0,d7
        move.w  d1,d6
        cmpi.w  #MENU_DIALOG_PHASE_TITLE,d7
        bhi     exit_ui_refuse
        tst.w   edtr_view_live
        bne     exit_ui_refuse
        bsr     aur_validate
        bne     exit_ui_refuse
        bsr     menu_owner
        bne     exit_ui_refuse
        move.w  d7,EXIT_KIND
        move.w  d6,EXIT_ERROR
        clr.w   EXIT_CHOICE
        clr.w   EXIT_HELD
        clr.w   EXIT_NEW
        cmpi.w  #MENU_DIALOG_PHASE,d7
        bne.s   .new
        bsr     phd_open
        bra.s   .opened
.new:
        cmpi.w  #MENU_DIALOG_NEW,d7
        bne.s   .title
        bsr     new_dialog_open
        bra.s   .opened
.title:
        cmpi.w  #MENU_DIALOG_TITLE,d7
        beq.s   .title_open
        cmpi.w  #MENU_DIALOG_PHASE_TITLE,d7
        bne.s   .standard
.title_open:
        bsr     menu_title_open
        bra.s   .opened
.standard:
        bsr     dialog_standard_open
.opened:
        bne.s   exit_ui_refuse
        move.w  #1,EXIT_NEW

edtr_modal_idle:
        jsr wait_frame
        cmpi.w #MENU_DIALOG_PHASE,EXIT_KIND
        beq phd_step
        cmpi.w #MENU_DIALOG_NEW,EXIT_KIND
        beq menu_new_step
        cmpi.w #MENU_DIALOG_TITLE,EXIT_KIND
        beq menu_title_step
        cmpi.w #MENU_DIALOG_PHASE_TITLE,EXIT_KIND
        beq menu_title_step
        bsr.s dialog_poll
        bmi.s edtr_modal_idle
        move.w d0,EXIT_CHOICE

edtr_modal_finish:
        bsr.s   dialog_close
        clr.w   EXIT_NEW
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
        even
edtr_modal_end:
        ifgt EXIT_UI+EXIT_UI_BYTES-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Menu snapshot exceeds WORK storage"
        endif
