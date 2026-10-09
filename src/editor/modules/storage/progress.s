; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The Saving panel: a dialog of the Slave's dialog service that names the
; mission while the save checks it and says that the screen stays dark
; while the files are written. WHDLoad keeps the display dark during each
; write, so the panel closes before the first one instead of flashing
; between them; the editor shows "Saved." afterwards. It stays at least
; SAVE_PANEL_FIELDS fields so that it can be read.
SAVE_PANEL_OPEN     equ EDITOR_UI_BASE+128
SAVE_PANEL_SINCE    equ EDITOR_UI_BASE+130
SAVE_PANEL_FIELDS   equ 25

; Opens the panel when the display allows it. Preserves all registers.
cf_save_panel_open:
        movem.l d0/d2/a0,-(sp)
        clr.w SAVE_PANEL_OPEN
        lea dlg_saving(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        move.w #1,SAVE_PANEL_OPEN
        move.w native_field_counter,SAVE_PANEL_SINCE
.out:
        movem.l (sp)+,d0/d2/a0
        rts

; Closes the panel, if open, once it has been shown long enough. Preserves
; all registers.
cf_save_panel_close:
        tst.w SAVE_PANEL_OPEN
        beq.s .out
        move.l d0,-(sp)
.wait:
        move.w native_field_counter,d0
        sub.w SAVE_PANEL_SINCE,d0
        cmpi.w #SAVE_PANEL_FIELDS,d0
        bhs.s .close
        jsr wait_frame
        bra.s .wait
.close:
        bsr dialog_close
        clr.w SAVE_PANEL_OPEN
        move.l (sp)+,d0
.out:
        rts

dlg_saving:
        dc.w 76,60,UI_SELECT
        dc.l save_panel_title,save_panel_body
        dc.w -1,-1,0
save_panel_body:
        dc.w UI_TEXT_AT,16,94,288,UI_INK,UI_LEFT_CLIPPED
        dc.l EDITOR_METADATA_BASE+CFMD_TITLE
        dc.w UI_TEXT,16,108,288,UI_DIM,UI_LEFT
        dc.b "The screen stays dark while WHDLoad writes",0
        even
        dc.w UI_TEXT,16,120,288,UI_DIM,UI_LEFT
        dc.b "the files. This takes a few seconds.",0
        even
        dc.w UI_END
save_panel_title: dc.b "Saving the mission",0
        even
