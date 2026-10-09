; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef controller_new_setup,controller_new_idle,controller_new_publish
NEW_FAMILY      equ EDITOR_UI_BASE+96
NEW_WIDTH       equ EDITOR_UI_BASE+98
NEW_HEIGHT      equ EDITOR_UI_BASE+100
NEW_CHOICE      equ EDITOR_UI_BASE+104
; Dialog scratch: numbers, the saved fade state and redrawn-field lists.
EXIT_NUMBER     equ EDITOR_UI_BASE+128
NEW_FADE        equ EDITOR_UI_BASE+160
EXIT_LIST       equ EDITOR_UI_BASE+192
NEW_DIALOG_FAMILY equ NEW_FAMILY
NEW_DIALOG_WIDTH equ NEW_WIDTH
NEW_DIALOG_HEIGHT equ NEW_HEIGHT
NEW_DIALOG_WITH_TEMPLATE equ 1

; Runs only on the initial New CTRL pass, before campaign capture: the shared
; New dialog with Template..., a dialog of the Slave's dialog service. No disk
; I/O or authored mutation occurs while it is open. D0=0 accepted, 1 Cancel,
; any other nonzero value is a cancellation status. All other registers and
; SP are preserved.
controller_new_setup:
        movem.l d1-d7/a0-a6,-(sp)
        clr.w NEW_FAMILY
        move.w #19,NEW_WIDTH
        move.w #15,NEW_HEIGHT
        move.w #1,NEW_CHOICE
        bsr new_fade_own
controller_new_open:
        bsr new_dialog_open
        bne.s controller_new_failed
controller_new_idle:
        jsr wait_frame
        bsr dialog_poll
        bmi.s controller_new_idle
        bsr new_dialog_event
        bmi.s controller_new_idle
        beq.s controller_new_finish
        cmpi.w #NEW_DIALOG_FROM_TEMPLATE,d0
        beq.s controller_new_template
        clr.w NEW_CHOICE
        bra.s controller_new_finish
controller_new_template:
        bsr dialog_close
        bsr dialog_release
        bsr template_picker
        beq.s controller_new_chosen
        bra.s controller_new_open
controller_new_failed:
        bsr new_fade_restore
        bra controller_new_return
controller_new_finish:
        bsr dialog_close
        bsr dialog_release
controller_new_chosen:
        bsr new_fade_restore
        cmpi.w #1,NEW_CHOICE
        beq.s .cancelled
        bsr controller_epoch
        bne.s controller_new_return
        cmpi.w #2,NEW_CHOICE
        beq.s .template
        bra.s controller_new_publish
.cancelled:
        moveq #1,d0
        bra.s controller_new_return
.template:
        move.w TPL_MISSION,d0
        move.w TPL_PHASE,d1
        bsr template_lookup
        bmi.s controller_new_return
        move.w TPL_MISSION,BROWSER_TEMPLATE_MISSION
        move.w TPL_PHASE,BROWSER_TEMPLATE_PHASE
        move.w d0,BROWSER_TEMPLATE_MAP
        move.w #BROWSER_TEMPLATE_VALID,BROWSER_NEW_TAG
        moveq #0,d0
        bra.s controller_new_return
controller_new_publish:
        move.w NEW_WIDTH,BROWSER_NEW_WIDTH
        move.w NEW_HEIGHT,BROWSER_NEW_HEIGHT
        move.w NEW_FAMILY,BROWSER_NEW_FAMILY
        move.w #BROWSER_NEW_VALID,BROWSER_NEW_TAG
        moveq #0,d0
controller_new_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; The SOFT IRQ still consumes Escape at fade level 16 even while gameplay is
; inactive. The dialogs own a stable full-bright fade state meanwhile.
new_fade_own:
        movem.l d0/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea editor_fade_state,a0
        lea NEW_FADE,a1
        moveq #3,d0
.save:
        move.l (a0)+,(a1)+
        dbf d0,.save
        move.w #15,editor_fade_state
        move.w #15,editor_fade_state+4
        move.w (sp)+,sr
        movem.l (sp)+,d0/a0-a1
        rts
new_fade_restore:
        movem.l d0/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea NEW_FADE,a0
        lea editor_fade_state,a1
        moveq #3,d0
.restore:
        move.l (a0)+,(a1)+
        dbf d0,.restore
        move.w (sp)+,sr
        movem.l (sp)+,d0/a0-a1
        rts

        ifgt EXIT_LIST+64-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "New dialog scratch exceeds UI storage"
        endif
