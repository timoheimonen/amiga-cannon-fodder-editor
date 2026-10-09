; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

TPL_PICK_PHASE equ EDITOR_UI_BASE
TPL_MISSION    equ EDITOR_UI_BASE+2
TPL_PHASE      equ EDITOR_UI_BASE+4
TPL_COUNT      equ EDITOR_UI_BASE+6
TPL_DRIVE      equ EDITOR_UI_BASE+8
TPL_MAP        equ EDITOR_UI_BASE+10
TPL_RESULT     equ EDITOR_UI_BASE+12
TPL_RETRY_WAIT equ EDITOR_UI_BASE+14
TPL_CUSTOM_DRIVE equ EDITOR_UI_BASE+16
TPL_TEXT       equ EDITOR_UI_BASE+160

        xdef edtr_modal,edtr_modal_idle
        xdef edtr_modal_finish,edtr_modal_end

; Template dialogs of the Slave's dialog service over the darkened map.
; D0.w kind: 0 picks an original mission, then one of its phases, from lists
; of the game's own titles; 1 says the game disk could not be read; 2 asks
; to restore the Custom directory. D1 ignored. Returns 0 cancel, 1 use or
; retry; kinds 1 and 2 retry by themselves every 100 frames without a press.
; Owns WORK160..383 and UI160..223 until return. No disk calls.
EXIT_UI             equ EDITOR_SERIAL_WORK_BASE+160
EXIT_LIST           equ EXIT_UI
EXIT_KIND           equ EXIT_UI+116
EXIT_CHOICE         equ EXIT_UI+120
EXIT_UI_BYTES       equ 224

edtr_modal:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d7
        cmpi.w #2,d7
        bhi tpl_dialog_refuse
        bsr aur_validate
        bne tpl_dialog_refuse
        bsr template_owner
        bne tpl_dialog_refuse
        move.w d7,EXIT_KIND
        clr.w EXIT_CHOICE
        move.w #100,TPL_RETRY_WAIT
        moveq #0,d2
        tst.w d7
        bne.s .prompt
        bsr tpl_list_open
        bne tpl_dialog_refuse
        bra.s edtr_modal_idle
.prompt:
        lea dlg_template_custom(pc),a0
        cmpi.w #2,d7
        beq.s .custom
        lea dlg_template_disk2(pc),a0
        cmpi.w #36,TPL_MAP
        bls.s .open
        lea dlg_template_disk3(pc),a0
        bra.s .open
.custom:
        ; The marker name is shown by value, bounded to its 32-byte field.
        lea AUR_BASE+AUR_DISK_NAME,a1
        lea TPL_TEXT,a2
        moveq #30,d0
.name:
        move.b (a1)+,(a2)+
        dbeq d0,.name
        clr.b (a2)
.open:
        bsr dialog_open
        bne.s tpl_dialog_refuse

edtr_modal_idle:
        jsr wait_frame
        tst.w EXIT_KIND
        beq.s .poll
        tst.w native_left_down
        bne.s .poll
        subq.w #1,TPL_RETRY_WAIT
        bne.s .poll
        moveq #1,d0
        bra.s .chosen
.poll:
        tst.w EXIT_KIND
        bne.s .dialog
        bsr tpl_list_key
        bpl.s .event
.dialog:
        bsr dialog_poll
        bmi.s edtr_modal_idle
        tst.w EXIT_KIND
        bne.s .chosen
.event:
        bsr tpl_list_event
        bmi.s edtr_modal_idle
.chosen:
        move.w d0,EXIT_CHOICE

edtr_modal_finish:
        bsr dialog_close
        bsr dialog_release
        moveq #0,d0
        move.w EXIT_CHOICE,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
tpl_dialog_refuse:
        moveq #EDTR_VISUAL_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Retry and Cancel keep the old hit zones on Y105-117.
dlg_template_custom:
        dc.w 52,72,UI_ERROR
        dc.l tpl_custom_title,tpl_custom_body
        dc.w 0,0,2
        dc.w 16,104,124,14,1,UI_NORMAL
        dc.l tpl_retry_label
        dc.w 176,104,124,14,0,UI_NORMAL
        dc.l tpl_cancel_label
tpl_custom_body:
        dc.w UI_TEXT,16,68,288,UI_INK,UI_LEFT
        dc.b "Custom no longer holds this mission's marker:",0
        even
        dc.w UI_TEXT_AT,16,78,288,UI_ACCENT,UI_LEFT
        dc.l TPL_TEXT
        dc.w UI_TEXT,16,88,288,UI_DIM,UI_LEFT
        dc.b "Restore it and Retry, or Cancel.",0
        even
        dc.w UI_END

tpl_custom_title: dc.b "Custom directory changed",0
        even
edtr_modal_end:
