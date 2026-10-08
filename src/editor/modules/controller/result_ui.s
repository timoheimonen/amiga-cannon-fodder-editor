; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef controller_result_ui,controller_result_ui_idle
        xdef controller_result_ui_finish,controller_result_ui_end

; The phase result: a dialog of the Slave's dialog service over black. The
; title names the outcome, a line explains it and, after a failed
; transaction, a red line gives its status. Retry, Next phase and Return to
; hill (default, also Escape); R and N stay as keys. With TEST_RELOAD_UI the
; title says that the editor could not be reloaded.
RESULT_UI                 equ EDITOR_UI_BASE
RESULT_ALLOWED            equ RESULT_UI+116
RESULT_ERROR              equ RESULT_UI+118
RESULT_CHOICE             equ RESULT_UI+120
; The title, drawn once at open; the status line reuses it afterwards.
RESULT_TEXT               equ RESULT_UI
RESULT_UI_BYTES           equ 224
        ifnd EXIT_LIST
EXIT_NUMBER               equ RESULT_UI+128
EXIT_LIST                 equ RESULT_UI+192
        endif
RESULT_LINE_Y             equ 84

; Stopped custom outcome only: no live renderer, fader, hill or asset reload.
; D0.w bits0/1 allow RETRY/NEXT; D1.w is a signed transaction error (0 none).
; Returns D0=0 RETURN,1 RETRY,2 NEXT; preserves D1-D7/A0-A6 and SP.
; Owns UI0..223 until normal return. No disk calls. The Slave restores the
; display it borrowed before the choice is returned.
controller_result_ui:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w  #1,session_custom_mode
        bne     result_ui_refuse
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne     result_ui_refuse
        tst.w   native_gameplay_active
        bne     result_ui_refuse
        tst.w   native_fifth_plane
        bne     result_ui_refuse
        andi.w  #3,d0
        move.w  d0,RESULT_ALLOWED
        move.w  d1,RESULT_ERROR
        clr.w   RESULT_CHOICE
        ; The outcome names the title and its explanation.
        ifd TEST_RELOAD_UI
        lea     result_ui_reload(pc),a1
        lea     result_ui_reload_line(pc),a2
        moveq   #UI_INK,d4
        else
        lea     result_ui_ended(pc),a1
        lea     result_ui_ended_line(pc),a2
        moveq   #UI_INK,d4
        tst.w   session_outcome_no_squad
        beq.s   .squad
        lea     result_ui_no_soldiers(pc),a1
        lea     result_ui_no_soldiers_line(pc),a2
        moveq   #UI_ERROR,d4
        bra.s   .title
.squad:
        btst    #2,session_outcome_sr+1
        beq.s   .title
        tst.w   session_outcome_failure
        bne.s   .title
        tst.w   session_outcome_success
        beq.s   .title
        lea     result_ui_complete(pc),a1
        lea     result_ui_complete_line(pc),a2
        moveq   #UI_OK,d4
.title:
        endif
        lea     RESULT_TEXT,a0
        bsr     dialog_copy
        ; Retry and Next phase only when the controller allows them.
        moveq   #0,d2
        btst    #0,RESULT_ALLOWED+1
        bne.s   .retry
        bset    #0,d2
.retry:
        btst    #1,RESULT_ALLOWED+1
        bne.s   .next
        bset    #1,d2
.next:
        lea     dlg_result(pc),a0
        bsr     dialog_open
        bne     result_ui_refuse
        movea.l a2,a1
        moveq   #16,d1
        moveq   #RESULT_LINE_Y,d2
        move.w  #284,d3
        moveq   #UI_LEFT,d5
        bsr     dialog_field
        move.w  RESULT_ERROR,d0
        beq.s   controller_result_ui_idle
        lea     RESULT_TEXT,a0
        lea     result_ui_error(pc),a1
        bsr     dialog_copy
        move.w  RESULT_ERROR,d0
        bpl.s   .magnitude
        move.b  #'-',(a0)+
        neg.w   d0
.magnitude:
        bsr     dialog_number
        lea     RESULT_TEXT,a1
        moveq   #RESULT_LINE_Y+14,d2
        moveq   #UI_ERROR,d4
        bsr     dialog_field

controller_result_ui_idle:
        jsr     wait_frame
        move.w  native_last_key,d1
        moveq   #1,d0
        cmpi.w  #'R',d1
        beq.s   .key
        moveq   #2,d0
        cmpi.w  #'N',d1
        bne.s   .poll
.key:
        clr.w   native_last_key
        move.w  d0,d1
        subq.w  #1,d1
        btst    d1,RESULT_ALLOWED+1
        bne.s   .chosen
        bra.s   controller_result_ui_idle
.poll:
        bsr     dialog_poll
        bmi.s   controller_result_ui_idle
.chosen:
        move.w  d0,RESULT_CHOICE

controller_result_ui_finish:
        bsr     dialog_close
        bsr     dialog_release
        moveq   #0,d0
        move.w  RESULT_CHOICE,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
result_ui_refuse:
        moveq   #0,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Retry, Next phase and Return to hill (default) keep the old row Y128-143.
dlg_result:
        dc.w 64,88,UI_SELECT
        dc.l RESULT_TEXT,0
        dc.w 2,0,3
        dc.w 16,126,92,14,1,UI_NORMAL
        dc.l result_ui_retry_text
        dc.w 112,126,92,14,2,UI_NORMAL
        dc.l result_ui_next_text
        dc.w 208,126,92,14,0,UI_NORMAL
        dc.l result_ui_return_text
        ifd TEST_RELOAD_UI
result_ui_reload: dc.b "Could not reload the editor",0
result_ui_reload_line: dc.b "The saved mission could not be read again.",0
        else
result_ui_complete: dc.b "Phase complete",0
result_ui_complete_line: dc.b "All objectives of the phase are done.",0
result_ui_ended: dc.b "Phase ended",0
result_ui_ended_line: dc.b "The phase ended before its objectives.",0
result_ui_no_soldiers: dc.b "Squad lost",0
result_ui_no_soldiers_line: dc.b "No soldier of the squad is left.",0
        endif
result_ui_error: dc.b "Could not continue: status ",0
result_ui_retry_text: dc.b "Retry",0
result_ui_next_text: dc.b "Next phase",0
result_ui_return_text: dc.b "Return to hill",0
        even
controller_result_ui_end:
        ifgt RESULT_UI_BYTES-EDITOR_UI_BYTES
        fail "Result screen owner record exceeds UI storage"
        endif
