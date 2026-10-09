; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The Template list: the game's own mission titles, eight rows at a time, then
; the phases of the chosen mission, with Previous, Next, Use and Back. The
; heading line shows the position of the selection. The includer defines the
; words TPL_PICK_PHASE (0 missions, 1 phases), TPL_MISSION, TPL_PHASE and
; TPL_COUNT and a 64-byte EXIT_LIST, and links template_lookup.
TPL_ROWS            equ 8
TPL_ROW             equ 10
TPL_PREV            equ 20
TPL_NEXT            equ 21
TPL_UP              equ 22
TPL_DOWN            equ 23
TPL_PREV_BUTTON     equ 8

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

; Up and Down move the selection one row. D0.l=-1 when neither was
; pressed, otherwise TPL_UP or TPL_DOWN.
tpl_list_key:
        moveq #TPL_UP,d0
        cmpi.w #$CC,native_last_key
        beq.s .key
        moveq #TPL_DOWN,d0
        cmpi.w #$CD,native_last_key
        beq.s .key
        moveq #-1,d0
        rts
.key:
        clr.w native_last_key
        tst.l d0
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
        beq .use
        moveq #-1,d1
        cmpi.w #TPL_UP,d0
        beq.s .step
        moveq #1,d1
        cmpi.w #TPL_DOWN,d0
        beq.s .step
        moveq #-TPL_ROWS,d1
        cmpi.w #TPL_PREV,d0
        beq.s .page
        moveq #TPL_ROWS,d1
        cmpi.w #TPL_NEXT,d0
        beq.s .page
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
        ; The arrow keys wrap around at either end.
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
        ; Previous and Next turn the page; the selection keeps its row and
        ; stops at the first and the last title.
.page:
        add.w (a0),d1
        bpl.s .not_first
        moveq #0,d1
.not_first:
        cmp.w TPL_COUNT,d1
        blo.s .set
        move.w TPL_COUNT,d1
        subq.w #1,d1
        bra.s .set
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
        move.l #(180<<16)|UI_INK,(a0)+
        move.w #UI_LEFT_CLIPPED,(a0)+
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
        bsr tpl_position
        ; Previous and Next while there is another page.
        move.w d6,d7
        andi.w #-TPL_ROWS,d7
        moveq #TPL_PREV_BUTTON,d2
        moveq #UI_DISABLED,d3
        tst.w d7
        beq.s .previous
        moveq #UI_NORMAL,d3
.previous:
        suba.l a0,a0
        bsr dialog_set
        moveq #TPL_PREV_BUTTON+1,d2
        moveq #UI_DISABLED,d3
        move.w d7,d0
        addq.w #TPL_ROWS,d0
        cmp.w TPL_COUNT,d0
        bhs.s .next
        moveq #UI_NORMAL,d3
.next:
        bsr dialog_set
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
        bsr tpl_mission_title
        bra.s .label
.phase:
        move.w d0,d1
        move.w TPL_MISSION,d0
        bsr template_lookup
        bmi.s .set
        lea native_phase_title_table,a0
        move.l #native_phase_titles_start,d4
        move.l #native_phase_titles_end,d5
        bsr tpl_table_title
.label:
        movea.l a1,a0
.set:
        bsr dialog_set
        addq.w #1,d2
        cmpi.w #TPL_ROWS,d2
        blo.s .row
        movem.l (sp)+,d0-d7/a0-a2
        rts

; "3 of 24" for the selection D6.w, right-aligned on the heading line.
tpl_position:
        movem.l d0/a0-a1,-(sp)
        lea -32(sp),sp
        movea.l sp,a0
        move.w #UI_TEXT,(a0)+
        move.l #(240<<16)|46,(a0)+
        move.l #(60<<16)|UI_DIM,(a0)+
        move.w #UI_RIGHT,(a0)+
        move.w d6,d0
        addq.w #1,d0
        bsr dialog_number
        lea tpl_of(pc),a1
        bsr dialog_copy
        move.w TPL_COUNT,d0
        bsr dialog_number
        addq.l #2,a0
        move.l a0,d0
        bclr #0,d0
        movea.l d0,a0
        clr.w (a0)
        movea.l sp,a0
        bsr dialog_draw
        lea 32(sp),sp
        movem.l (sp)+,d0/a0-a1
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
tpl_of: dc.b " of ",0
tpl_prev_label: dc.b "_Previous",0
tpl_next_label: dc.b "_Next",0
tpl_use_label: dc.b "_Use",0
tpl_back_label: dc.b "Back",0
        
; Game disk prompt: under WHDLoad the disks are the files Disk.2 and Disk.3
; of the install. Retry and Cancel on the row of the Custom prompt.
dlg_template_disk2:
        dc.w 52,72,UI_ERROR
        dc.l tpl_disk_title,tpl_disk2_body
        dc.w 0,0,2
        dc.w 16,104,124,14,1,UI_NORMAL
        dc.l tpl_retry_label
        dc.w 176,104,124,14,0,UI_NORMAL
        dc.l tpl_cancel_label
dlg_template_disk3:
        dc.w 52,72,UI_ERROR
        dc.l tpl_disk_title,tpl_disk3_body
        dc.w 0,0,2
        dc.w 16,104,124,14,1,UI_NORMAL
        dc.l tpl_retry_label
        dc.w 176,104,124,14,0,UI_NORMAL
        dc.l tpl_cancel_label
tpl_disk2_body:
        dc.w UI_TEXT,16,70,288,UI_INK,UI_LEFT
        dc.b "The template reads game disk 2, the file Disk.2",0
        even
        dc.w UI_TEXT,16,82,288,UI_INK,UI_LEFT
        dc.b "of the WHDLoad install. Check it, then Retry.",0
        even
        dc.w UI_END
tpl_disk3_body:
        dc.w UI_TEXT,16,70,288,UI_INK,UI_LEFT
        dc.b "The template reads game disk 3, the file Disk.3",0
        even
        dc.w UI_TEXT,16,82,288,UI_INK,UI_LEFT
        dc.b "of the WHDLoad install. Check it, then Retry.",0
        even
        dc.w UI_END
tpl_disk_title: dc.b "Game disk could not be read",0
tpl_retry_label: dc.b "_Retry",0
tpl_cancel_label: dc.b "Cancel",0
        even
