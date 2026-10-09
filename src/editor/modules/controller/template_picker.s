; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

TPL_STAGE       equ EDITOR_UI_BASE+106
TPL_TOP         equ EDITOR_UI_BASE+108
TPL_MISSION     equ EDITOR_UI_BASE+110
TPL_PHASE       equ EDITOR_UI_BASE+112
TPL_COUNT       equ EDITOR_UI_BASE+114
TPL_PICK_PHASE  equ TPL_STAGE
        xdef template_picker,template_picker_idle,template_picker_return

; The shared Template list (dialog/template_list.s), opened from the New
; dialog. Return D0=0 selection or 1 Back; NEW_CHOICE=2 identifies a Template
; receipt. No persistent writes or disk I/O.
template_picker:
        movem.l d1-d7/a0-a6,-(sp)
        clr.w TPL_STAGE
        clr.w TPL_TOP
        clr.w TPL_MISSION
        clr.w TPL_PHASE
        move.w #24,TPL_COUNT
        bsr tpl_list_open
        bne.s template_picker_refused
template_picker_idle:
        jsr wait_frame
        bsr tpl_list_key
        bpl.s .event
        bsr dialog_poll
        bmi.s template_picker_idle
.event:
        bsr tpl_list_event
        bmi.s template_picker_idle
        beq.s .back
        move.w #2,NEW_CHOICE
        moveq #0,d0
        bra.s .close
.back:
        moveq #1,d0
.close:
        bsr.s template_picker_close
template_picker_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
template_picker_refused:
        moveq #1,d0
        bra.s template_picker_return
; Preserves D0.
template_picker_close:
        move.l d0,-(sp)
        bsr dialog_close
        bsr dialog_release
        move.l (sp)+,d0
        rts
