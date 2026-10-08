; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef edtr_modal,edtr_modal_idle
        xdef edtr_modal_finish,edtr_modal_end

; Open mission: a dialog of the Slave's dialog service over the darkened map.
; The four list rows of the current page, Up, Down, New..., Open, Files... and
; Back. The dialog returns before every disk operation.
; Choices: 0 cancel, 1 Open, 2 selection, 4 guarded New, 5 files.
EXIT_UI             equ EDITOR_SERIAL_WORK_BASE+160
OPEN_ROW_TEXT       equ EXIT_UI
OPEN_ROW_BYTES      equ 48
EXIT_CHOICE         equ EXIT_UI+192
EXIT_UI_BYTES       equ 224
OPEN_ROW            equ 10
OPEN_UP             equ 20
OPEN_DOWN           equ 21
; Row text starts at OPEN_TEXT_X in 6-pixel cells. A title within the title
; entry limit can have more characters than fit before the Phases heading, so
; a row shows its first OPEN_TITLE_CHARS characters.
OPEN_TEXT_X         equ 12
OPEN_PHASES_X       equ 180
OPEN_TITLE_CHARS    equ 27
OPEN_PHASE_COLUMN   equ 30
OPEN_STATUS_COLUMN  equ 36

; D0.w=0, D1 ignored. Preserves D1-D7/A0-A6/SP. Owns WORK160..383 and
; UI160..223 until return; needs the page that open_page prepared.
edtr_modal:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w d0
        bne open_dialog_refuse
        bsr open_owner
        bne open_dialog_refuse
        clr.w EXIT_CHOICE
        bsr open_dialog_texts
        bsr open_dialog_mask
        lea dlg_open(pc),a0
        bsr dialog_open
        bne open_dialog_refuse
        tst.w OPN_COUNT
        bne.s .selected
        lea open_dialog_none(pc),a0
        bsr dialog_draw
        bra.s edtr_modal_idle
.selected:
        move.w OPN_SELECTED,d2
        sub.w OPN_TOP,d2
        moveq #UI_ACTIVE,d3
        suba.l a0,a0
        bsr dialog_set

edtr_modal_idle:
        jsr wait_frame
        moveq #-1,d1
        cmpi.w #$CC,native_last_key
        beq.s .key
        moveq #1,d1
        cmpi.w #$CD,native_last_key
        bne.s .poll
.key:
        clr.w native_last_key
        bra.s open_dialog_move
.poll:
        bsr dialog_poll
        bmi.s edtr_modal_idle
        moveq #-1,d1
        cmpi.w #OPEN_UP,d0
        beq.s open_dialog_move
        moveq #1,d1
        cmpi.w #OPEN_DOWN,d0
        beq.s open_dialog_move
        cmpi.w #OPEN_ROW,d0
        bhs.s .row
        move.w d0,EXIT_CHOICE
        bra.s edtr_modal_finish
.row:
        subi.w #OPEN_ROW,d0
        add.w OPN_TOP,d0
        cmp.w OPN_COUNT,d0
        bhs.s edtr_modal_idle
        cmp.w OPN_SELECTED,d0
        beq.s edtr_modal_idle
        move.w d0,d1
        bra.s open_dialog_select
open_dialog_move:
        add.w OPN_SELECTED,d1
        cmp.w OPN_COUNT,d1
        bhs.s edtr_modal_idle
open_dialog_select:
        move.w d1,OPN_SELECTED
        move.w #2,EXIT_CHOICE

edtr_modal_finish:
        bsr dialog_close
        bsr dialog_release
        moveq #0,d0
        move.w EXIT_CHOICE,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
open_dialog_refuse:
        moveq #EDTR_VISUAL_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; D2.w = disabled buttons: rows past the list, Up on the first mission, Down
; on the last, Open unless a mission is selected and openable (status 1..3).
open_dialog_mask:
        moveq #0,d2
        moveq #0,d0
.rows:
        move.w d0,d1
        add.w OPN_TOP,d1
        cmp.w OPN_COUNT,d1
        blo.s .row_ok
        bset d0,d2
.row_ok:
        addq.w #1,d0
        cmpi.w #4,d0
        blo.s .rows
        tst.w OPN_SELECTED
        bne.s .up
        bset #4,d2
.up:
        move.w OPN_SELECTED,d0
        addq.w #1,d0
        cmp.w OPN_COUNT,d0
        blo.s .down
        bset #5,d2
.down:
        tst.w OPN_COUNT
        beq.s .closed
        cmpi.w #2,OPN_STATUS
        blo.s .closed
        cmpi.w #3,OPN_STATUS
        bls.s .done
.closed:
        bset #7,d2
.done:
        rts

; Row labels (title, phases, status in fixed columns) and the free-space line.
open_dialog_texts:
        movem.l d0-d7/a0-a4,-(sp)
        lea OPN_ROWS,a4
        lea OPEN_ROW_TEXT,a3
        moveq #0,d6
.row:
        movea.l a3,a1
        move.w d6,d0
        add.w OPN_TOP,d0
        cmp.w OPN_COUNT,d0
        bhs .end
        movea.l a4,a0
        moveq #OPEN_TITLE_CHARS-1,d1
.title:
        move.b (a0)+,d2
        beq.s .pad
        move.b d2,(a1)+
        dbf d1,.title
.pad:
        lea OPEN_PHASE_COLUMN(a3),a2
.spaces:
        move.b #' ',(a1)+
        cmpa.l a2,a1
        blo.s .spaces
        moveq #0,d0
        move.b 65(a4),d0
        move.b #' ',(a1)+
        cmpi.w #10,d0
        bhs.s .phases
        move.b #' ',(a1)+
.phases:
        bsr open_decimal
        lea OPEN_STATUS_COLUMN(a3),a2
.gap:
        move.b #' ',(a1)+
        cmpa.l a2,a1
        blo.s .gap
        lea open_status_damaged(pc),a0
        tst.w 66(a4)
        beq.s .status
        lea open_status_none(pc),a0
        move.w d6,d0
        add.w OPN_TOP,d0
        cmp.w OPN_SELECTED,d0
        bne.s .status
        move.w OPN_STATUS,d0
        lea open_status_invalid(pc),a0
        cmpi.w #2,d0
        beq.s .status
        lea open_status_review(pc),a0
        cmpi.w #3,d0
        beq.s .status
        lea open_status_blocked(pc),a0
.status:
        move.b (a0)+,(a1)+
        bne.s .status
        subq.l #1,a1
.end:
        clr.b (a1)
        lea OPEN_ROW_BYTES(a3),a3
        lea OPN_ROW_BYTES(a4),a4
        addq.w #1,d6
        cmpi.w #4,d6
        blo .row
        lea OPN_TEXT,a1
        lea open_free_text(pc),a0
        bsr.s open_dialog_append
        moveq #0,d0
        move.w OPN_FREE_RECORDS,d0
        bsr.s open_decimal
        lea open_files_text(pc),a0
        bsr.s open_dialog_append
        move.l OPN_FREE_BYTES,d0
        bsr.s open_decimal
        lea open_bytes_text(pc),a0
        bsr.s open_dialog_append
        clr.b (a1)
        movem.l (sp)+,d0-d7/a0-a4
        rts

; A0 string appended at A1 without its NUL.
open_dialog_append:
        move.b (a0)+,(a1)+
        bne.s open_dialog_append
        subq.l #1,a1
        rts

; D0.l=0..999999, A1=output; suppress leading zeroes. NUL is caller-owned.
open_decimal:
        movem.l d1-d4/a2,-(sp)
        lea .powers(pc),a2
        moveq #5,d4
        moveq #0,d3
.digit:
        move.l (a2)+,d2
        moveq #'0',d1
.subtract:
        cmp.l d2,d0
        blo.s .emit
        sub.l d2,d0
        addq.b #1,d1
        bra.s .subtract
.emit:
        cmpi.b #'0',d1
        bne.s .write
        tst.w d3
        bne.s .write
        tst.w d4
        bne.s .next
.write:
        move.b d1,(a1)+
        moveq #1,d3
.next:
        dbf d4,.digit
        movem.l (sp)+,d1-d4/a2
        rts
.powers: dc.l 100000,10000,1000,100,10,1

; Rows and footer keep the old hit zones of Open, New and Files.
dlg_open:
        dc.w 52,112,UI_SELECT
        dc.l open_dialog_title,open_dialog_body
        dc.w 7,0,10
        dc.w 8,90,292,12,OPEN_ROW,UI_NORMAL|DIALOG_ROW
        dc.l OPEN_ROW_TEXT
        dc.w 8,103,292,12,OPEN_ROW+1,UI_NORMAL|DIALOG_ROW
        dc.l OPEN_ROW_TEXT+OPEN_ROW_BYTES
        dc.w 8,116,292,12,OPEN_ROW+2,UI_NORMAL|DIALOG_ROW
        dc.l OPEN_ROW_TEXT+2*OPEN_ROW_BYTES
        dc.w 8,129,292,12,OPEN_ROW+3,UI_NORMAL|DIALOG_ROW
        dc.l OPEN_ROW_TEXT+3*OPEN_ROW_BYTES
        dc.w 8,144,34,14,OPEN_UP,UI_NORMAL
        dc.l open_up_label
        dc.w 44,144,34,14,OPEN_DOWN,UI_NORMAL
        dc.l open_down_label
        dc.w 80,144,52,14,4,UI_NORMAL
        dc.l open_new_label
        dc.w 134,144,66,14,1,UI_NORMAL
        dc.l open_open_label
        dc.w 202,144,54,14,5,UI_NORMAL
        dc.l open_files_label
        dc.w 258,144,42,14,0,UI_NORMAL
        dc.l open_back_label
open_dialog_body:
        dc.w UI_TEXT_AT,128,56,168,UI_ACCENT,UI_RIGHT
        dc.l OPN_DISK_NAME
        dc.w UI_TEXT_AT,12,67,288,UI_DIM,UI_LEFT
        dc.l OPN_TEXT
        dc.w UI_TEXT,OPEN_TEXT_X,79,160,UI_DIM,UI_LEFT
        dc.b "Mission",0
        dc.w UI_TEXT,OPEN_PHASES_X,79,40,UI_DIM,UI_LEFT
        dc.b "Phases",0
        even
        dc.w UI_TEXT,228,79,60,UI_DIM,UI_LEFT
        dc.b "Status",0
        even
        dc.w UI_END
open_dialog_none:
        dc.w UI_TEXT,12,92,288,UI_DIM,UI_LEFT
        dc.b "No missions in Custom yet. New... creates one.",0
        even
        dc.w UI_END

open_dialog_title: dc.b "Open mission",0
open_free_text: dc.b "Room left for ",0
open_files_text: dc.b " files and ",0
open_bytes_text: dc.b " bytes",0
open_status_none: dc.b 0
open_status_damaged: dc.b "Damaged",0
open_status_invalid: dc.b "Invalid",0
open_status_review: dc.b "Review",0
open_status_blocked: dc.b "Blocked",0
open_up_label: dc.b "Up",0
open_down_label: dc.b "Down",0
open_new_label: dc.b "New...",0
open_open_label: dc.b "Open",0
open_files_label: dc.b "Files...",0
open_back_label: dc.b "Back",0
        even
edtr_modal_end:
        ifgt EXIT_UI+EXIT_UI_BYTES-EDITOR_SERIAL_WORK_BASE-1024
        fail "Open dialog scratch exceeds the open work area"
        endif
        ifgt OPEN_TEXT_X+OPEN_TITLE_CHARS*UI_CELL_WIDTH-OPEN_PHASES_X
        fail "Open row titles reach the Phases column"
        endif
