; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The Template list: the game's own mission titles, eight rows at a time, then
; the phases of the chosen mission, with Previous, Next, Use and Back. The
; includer defines the words TPL_PICK_PHASE (0 missions, 1 phases),
; TPL_MISSION, TPL_PHASE and TPL_COUNT and a 64-byte EXIT_LIST, and links
; template_lookup. The game-disk prompt below also needs the word TPL_DRIVE.
TPL_ROWS            equ 8
TPL_ROW             equ 10
TPL_PREV            equ 20
TPL_NEXT            equ 21
TPL_DF0             equ 20

; Opens the list at the current choice. D0.l=0 open, otherwise refused.
tpl_list_open:
        movem.l d2/a0,-(sp)
        lea dlg_template(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr tpl_list_draw
        moveq #0,d0
.out:
        movem.l (sp)+,d2/a0
        rts

; D0.w polled code -> D0.l 0 cancel, 1 the phase is chosen, or -1 when the
; list changed and was redrawn. Back on the phase list returns to the
; missions; Use, Return or a click on the selected row moves on.
tpl_list_event:
        movem.l d1/a0,-(sp)
        lea TPL_MISSION,a0
        tst.w TPL_PICK_PHASE
        beq.s .index
        lea TPL_PHASE,a0
.index:
        tst.w d0
        beq.s .back
        cmpi.w #1,d0
        beq.s .use
        moveq #-1,d1
        cmpi.w #TPL_PREV,d0
        beq.s .step
        moveq #1,d1
        cmpi.w #TPL_NEXT,d0
        beq.s .step
        subi.w #TPL_ROW,d0
        move.w (a0),d1
        andi.w #-TPL_ROWS,d1
        add.w d1,d0
        cmp.w TPL_COUNT,d0
        bhs.s .stay
        cmp.w (a0),d0
        beq.s .use
        move.w d0,(a0)
        bra.s .redraw
.step:
        add.w (a0),d1
        bpl.s .high
        move.w TPL_COUNT,d1
        subq.w #1,d1
.high:
        cmp.w TPL_COUNT,d1
        blo.s .set
        moveq #0,d1
.set:
        move.w d1,(a0)
        bra.s .redraw
.back:
        tst.w TPL_PICK_PHASE
        beq.s .cancel
        clr.w TPL_PICK_PHASE
        move.w #24,TPL_COUNT
        bra.s .redraw
.use:
        tst.w TPL_PICK_PHASE
        bne.s .accept
        move.w TPL_MISSION,d0
        moveq #0,d1
        bsr template_lookup
        bmi.s .cancel
        move.w d1,TPL_COUNT
        move.w #1,TPL_PICK_PHASE
        clr.w TPL_PHASE
.redraw:
        bsr.s tpl_list_draw
.stay:
        moveq #-1,d0
        bra.s .out
.cancel:
        moveq #0,d0
        bra.s .out
.accept:
        moveq #1,d0
.out:
        movem.l (sp)+,d1/a0
        rts

; The heading and the page of eight titles around the current choice.
tpl_list_draw:
        movem.l d0-d7/a0-a2,-(sp)
        lea EXIT_LIST,a0
        move.w #UI_RECT,(a0)+
        move.l #(8<<16)|46,(a0)+
        move.l #(296<<16)|UI_LINE_HEIGHT,(a0)+
        move.w #UI_PANEL,(a0)+
        move.w #UI_TEXT_AT,(a0)+
        move.l #(12<<16)|46,(a0)+
        move.l #(288<<16)|UI_DIM,(a0)+
        move.w #UI_LEFT,(a0)+
        lea tpl_missions_heading(pc),a1
        tst.w TPL_PICK_PHASE
        beq.s .heading
        lea tpl_phases_heading(pc),a1
        move.l a1,(a0)+
        ; "Phases of " is ten cells wide; the mission title follows it.
        move.w #UI_TEXT_AT,(a0)+
        move.l #(72<<16)|46,(a0)+
        move.l #(228<<16)|UI_INK,(a0)+
        move.w #UI_LEFT,(a0)+
        move.w TPL_MISSION,d0
        bsr tpl_mission_title
.heading:
        move.l a1,(a0)+
        clr.w (a0)
        lea EXIT_LIST,a0
        bsr dialog_draw
        move.w TPL_MISSION,d6
        tst.w TPL_PICK_PHASE
        beq.s .current
        move.w TPL_PHASE,d6
.current:
        move.w d6,d7
        andi.w #-TPL_ROWS,d7
        moveq #0,d2
.row:
        move.w d7,d0
        add.w d2,d0
        moveq #UI_DISABLED,d3
        lea tpl_none(pc),a0
        cmp.w TPL_COUNT,d0
        bhs.s .set
        moveq #UI_NORMAL,d3
        cmp.w d6,d0
        bne.s .title
        moveq #UI_ACTIVE,d3
.title:
        tst.w TPL_PICK_PHASE
        bne.s .phase
        bsr.s tpl_mission_title
        bra.s .label
.phase:
        move.w d0,d1
        move.w TPL_MISSION,d0
        bsr template_lookup
        bmi.s .set
        lea native_phase_title_table,a0
        move.l #native_phase_titles_start,d4
        move.l #native_phase_titles_end,d5
        bsr.s tpl_table_title
.label:
        movea.l a1,a0
.set:
        bsr dialog_set
        addq.w #1,d2
        cmpi.w #TPL_ROWS,d2
        blo.s .row
        movem.l (sp)+,d0-d7/a0-a2
        rts

; D0.w mission -> A1 its title in the game's table.
tpl_mission_title:
        movem.l d4-d5/a0,-(sp)
        addq.w #1,d0
        lea native_mission_title_table,a0
        move.l #native_mission_titles_start,d4
        move.l #native_mission_titles_end,d5
        bsr.s tpl_table_title
        movem.l (sp)+,d4-d5/a0
        rts
; D0.w one-based index into the pointer table A0 -> A1 its $FF-terminated
; title, or a placeholder when the pointer leaves the string region D4..D5.
tpl_table_title:
        subq.w #1,d0
        lsl.w #2,d0
        movea.l 0(a0,d0.w),a1
        cmpa.l d4,a1
        blo.s .bad
        cmpa.l d5,a1
        blo.s .out
.bad:
        lea tpl_unknown(pc),a1
.out:
        rts

; Prev, Next, Use and Back keep their old hit zones on Y132-147.
dlg_template:
        dc.w 30,126,UI_SELECT
        dc.l tpl_title,0
        dc.w 10,0,12
        dc.w 8,58,292,9,TPL_ROW,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,67,292,9,TPL_ROW+1,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,76,292,9,TPL_ROW+2,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,85,292,9,TPL_ROW+3,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,94,292,9,TPL_ROW+4,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,103,292,9,TPL_ROW+5,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,112,292,9,TPL_ROW+6,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,121,292,9,TPL_ROW+7,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,134,92,14,TPL_PREV,UI_NORMAL
        dc.l tpl_prev_label
        dc.w 104,134,68,14,TPL_NEXT,UI_NORMAL
        dc.l tpl_next_label
        dc.w 176,134,68,14,1,UI_NORMAL
        dc.l tpl_use_label
        dc.w 248,134,52,14,0,UI_NORMAL
        dc.l tpl_back_label
tpl_title: dc.b "Template",0
tpl_missions_heading: dc.b "Choose an original mission",0
tpl_phases_heading: dc.b "Phases of",0
tpl_unknown: dc.b "?",0
tpl_none: dc.b 0
tpl_prev_label: dc.b "Previous",0
tpl_next_label: dc.b "Next",0
tpl_use_label: dc.b "Use",0
tpl_back_label: dc.b "Back",0
        
; Game disk prompt: DF0..DF3 (the chosen one selected), Retry and Cancel.
; Drive buttons DF0..DF3 (indices 0..3), the chosen one selected.
tpl_drive_draw:
        movem.l d0-d3/a0,-(sp)
        moveq #0,d2
.drive:
        moveq #UI_NORMAL,d3
        cmp.w TPL_DRIVE,d2
        bne.s .set
        moveq #UI_ACTIVE,d3
.set:
        suba.l a0,a0
        bsr dialog_set
        addq.w #1,d2
        cmpi.w #4,d2
        blo.s .drive
        movem.l (sp)+,d0-d3/a0
        rts

dlg_template_disk2:
        dc.w 52,96,UI_ERROR
        dc.l tpl_disk_title,tpl_disk2_body
        dc.w 4,0,6
        dc.w 16,100,68,14,TPL_DF0,UI_NORMAL
        dc.l tpl_df0
        dc.w 88,100,68,14,TPL_DF0+1,UI_NORMAL
        dc.l tpl_df1
        dc.w 160,100,68,14,TPL_DF0+2,UI_NORMAL
        dc.l tpl_df2
        dc.w 232,100,68,14,TPL_DF0+3,UI_NORMAL
        dc.l tpl_df3
        dc.w 16,132,124,14,1,UI_NORMAL
        dc.l tpl_retry_label
        dc.w 176,132,124,14,0,UI_NORMAL
        dc.l tpl_cancel_label
dlg_template_disk3:
        dc.w 52,96,UI_ERROR
        dc.l tpl_disk_title,tpl_disk3_body
        dc.w 4,0,6
        dc.w 16,100,68,14,TPL_DF0,UI_NORMAL
        dc.l tpl_df0
        dc.w 88,100,68,14,TPL_DF0+1,UI_NORMAL
        dc.l tpl_df1
        dc.w 160,100,68,14,TPL_DF0+2,UI_NORMAL
        dc.l tpl_df2
        dc.w 232,100,68,14,TPL_DF0+3,UI_NORMAL
        dc.l tpl_df3
        dc.w 16,132,124,14,1,UI_NORMAL
        dc.l tpl_retry_label
        dc.w 176,132,124,14,0,UI_NORMAL
        dc.l tpl_cancel_label
tpl_disk2_body:
        dc.w UI_TEXT,16,70,288,UI_INK,UI_LEFT
        dc.b "The template needs game disk 2. Choose the",0
        even
        dc.w UI_TEXT,16,82,288,UI_INK,UI_LEFT
        dc.b "drive that holds it, then Retry.",0
        even
        dc.w UI_END
tpl_disk3_body:
        dc.w UI_TEXT,16,70,288,UI_INK,UI_LEFT
        dc.b "The template needs game disk 3. Choose the",0
        even
        dc.w UI_TEXT,16,82,288,UI_INK,UI_LEFT
        dc.b "drive that holds it, then Retry.",0
        even
        dc.w UI_END
tpl_disk_title: dc.b "Game disk needed",0
tpl_retry_label: dc.b "Retry",0
tpl_cancel_label: dc.b "Cancel",0
tpl_df0: dc.b "DF0",0
tpl_df1: dc.b "DF1",0
tpl_df2: dc.b "DF2",0
tpl_df3: dc.b "DF3",0
        even
