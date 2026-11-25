; Cannon Fodder In-Game Level Editor V1.2.6
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

; The heading, the page of eight titles and the selected template's terrain
; family and size.
tpl_list_draw:
        movem.l d0-d7/a0-a2,-(sp)
        lea EXIT_LIST,a0
        move.w #UI_RECT,(a0)+
        move.l #(8<<16)|34,(a0)+
        move.l #(296<<16)|UI_LINE_HEIGHT,(a0)+
        move.w #UI_PANEL,(a0)+
        move.w #UI_TEXT_AT,(a0)+
        move.l #(12<<16)|34,(a0)+
        move.l #(288<<16)|UI_DIM,(a0)+
        move.w #UI_LEFT,(a0)+
        lea tpl_missions_heading(pc),a1
        tst.w TPL_PICK_PHASE
        beq.s .heading
        lea tpl_phases_heading(pc),a1
        move.l a1,(a0)+
        ; "Phases of " is ten cells wide; the mission title follows it.
        move.w #UI_TEXT_AT,(a0)+
        move.l #(72<<16)|34,(a0)+
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
        bsr tpl_detail
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
        move.l #(240<<16)|34,(a0)+
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

; Terrain family and size (or phase count) of the highlighted template on Y122.
tpl_detail:
        movem.l d0-d5/a0-a2,-(sp)
        lea -80(sp),sp
        movea.l sp,a0
        move.w #UI_RECT,(a0)+
        move.l #(8<<16)|121,(a0)+
        move.l #(296<<16)|9,(a0)+
        move.w #UI_PANEL,(a0)+
        move.w #UI_TEXT,(a0)+
        move.l #(12<<16)|122,(a0)+
        move.l #(288<<16)|UI_ACCENT,(a0)+
        move.w #UI_LEFT,(a0)+
        move.w TPL_MISSION,d0
        moveq #0,d1
        tst.w TPL_PICK_PHASE
        beq.s .lookup
        move.w TPL_PHASE,d1
.lookup:
        bsr template_lookup
        bmi .empty
        move.w d0,d2
        move.w d1,d3
        subq.w #1,d2
        mulu #3,d2
        lea tpl_map_info(pc),a2
        adda.w d2,a2
        moveq #0,d4
        move.b (a2),d4
        move.w d4,d0
        bsr.s .append_family
        tst.w TPL_PICK_PHASE
        bne.s .show_size
        ; Check whether later phases in this mission use another terrain family.
        move.w d3,d5
        subq.w #1,d5
        beq.s .show_single
        movea.l a2,a1
.scan:
        addq.l #3,a1
        cmp.b (a1),d4
        beq.s .scan_next
        move.b #'/',(a0)+
        moveq #0,d0
        move.b (a1),d0
        bsr.s .append_family
        bra.s .show_phases
.scan_next:
        subq.w #1,d5
        bne.s .scan
.show_phases:
        lea tpl_sep(pc),a1
        bsr dialog_copy
        move.w d3,d0
        bsr dialog_number
        lea tpl_phases_suffix(pc),a1
        bsr dialog_copy
        bra.s .finish
.show_single:
        bsr.s .append_size
        lea tpl_one_phase(pc),a1
        bsr dialog_copy
        bra.s .finish
.show_size:
        bsr.s .append_size
        lea tpl_cells_suffix(pc),a1
        bsr dialog_copy
.finish:
        addq.l #2,a0
        move.l a0,d0
        bclr #0,d0
        movea.l d0,a0
        clr.w (a0)
        movea.l sp,a0
        bsr dialog_draw
.empty:
        lea 80(sp),sp
        movem.l (sp)+,d0-d5/a0-a2
        rts
.append_family:
        add.w d0,d0
        lea tpl_family_names(pc),a1
        adda.w (a1,d0.w),a1
        bra dialog_copy
.append_size:
        lea tpl_sep(pc),a1
        bsr dialog_copy
        moveq #0,d0
        move.b 1(a2),d0
        bsr dialog_number
        move.b #'x',(a0)+
        moveq #0,d0
        move.b 2(a2),d0
        bra dialog_number

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

; Prev, Next, Use and Back keep their old hit zones on Y134-147.
dlg_template:
        dc.w 18,138,UI_SELECT
        dc.l tpl_title,0
        dc.w 10,0,12
        dc.w 8,46,292,9,TPL_ROW,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,55,292,9,TPL_ROW+1,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,64,292,9,TPL_ROW+2,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,73,292,9,TPL_ROW+3,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,82,292,9,TPL_ROW+4,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,91,292,9,TPL_ROW+5,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,100,292,9,TPL_ROW+6,UI_NORMAL|DIALOG_ROW
        dc.l tpl_none
        dc.w 8,109,292,9,TPL_ROW+7,UI_NORMAL|DIALOG_ROW
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
tpl_sep: dc.b "  ",0
tpl_phases_suffix: dc.b " phases",0
tpl_one_phase: dc.b "  1 phase",0
tpl_cells_suffix: dc.b " cells",0
tpl_prev_label: dc.b "_Previous",0
tpl_next_label: dc.b "_Next",0
tpl_use_label: dc.b "_Use",0
tpl_back_label: dc.b "Back",0
        even
tpl_family_names:
        dc.w .jun0-tpl_family_names,.jun1-tpl_family_names
        dc.w .ice-tpl_family_names,.des-tpl_family_names
        dc.w .mor-tpl_family_names,.int-tpl_family_names
.jun0: dc.b "Jungle A",0
.jun1: dc.b "Jungle B",0
.ice: dc.b "Ice",0
.des: dc.b "Desert",0
.mor: dc.b "Moor",0
.int: dc.b "Interior",0
; Terrain family (0..5) and map dimensions (width, height) for maps 1..72.
tpl_map_info:
        dc.b 0,19,15,0,46,36,0,46,34,2,40,34
        dc.b 1,76,52,1,19,15,0,60,45,1,50,45
        dc.b 2,100,15,2,80,50,2,60,40,3,40,32
        dc.b 3,60,60,2,26,70,2,65,50,2,50,40
        dc.b 0,49,30,0,35,30,0,74,80,0,40,56
        dc.b 2,40,26,2,26,60,3,40,40,3,45,45
        dc.b 3,26,45,3,19,30,3,40,45,0,70,60
        dc.b 0,32,35,0,76,78,2,60,30,2,26,60
        dc.b 2,60,45,2,40,60,2,40,45,2,40,30
        dc.b 4,40,36,3,46,52,3,42,45,3,42,52
        dc.b 4,68,25,4,45,35,4,65,70,5,70,30
        dc.b 5,68,15,4,55,51,5,70,40,5,19,58
        dc.b 5,46,25,5,103,15,5,59,45,5,60,42
        dc.b 4,50,70,4,50,70,4,95,70,4,60,80
        dc.b 5,21,15,3,50,65,3,19,34,3,120,15
        dc.b 3,40,30,4,65,35,4,60,60,4,45,45
        dc.b 4,65,41,4,40,30,5,40,45,5,40,27
        dc.b 5,19,45,5,60,40,5,19,60,5,41,40
        even
        
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
