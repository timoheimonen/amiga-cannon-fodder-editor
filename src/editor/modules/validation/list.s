; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Check results: a dialog of the Slave's dialog service. The title counts the
; mission's errors and issues to review, the line below it the visible range
; and the phases tested in this session; eight rows show severity, phase,
; place and the problem, and the explanation of the selected row follows.
; Show on map (default) jumps to a located issue; Previous and Next return to
; the caller, which reads the next page before the dialog opens again.
VDM_ROW_CODE        equ 20  ; 20..27 rows
VDM_JUMP_CODE       equ 2
VDM_PREVIOUS_CODE   equ 3
VDM_ROW_TEXT        equ EDITOR_READBACK_BASE
VDM_ROW_TEXT_BYTES  equ 50
VDM_PLACE_END       equ 22
VDM_DETAIL_Y        equ 151
VDM_HINT_Y          equ 163
; Row and field of the last click on an issue.
VDM_CLICK           equ EXIT_UI+124

; Every text is built before the dialog opens; the rows and the header
; stay in place while it is open.
page_open:
        move.w #-1,VDM_CLICK
        bsr vdm_list_texts
        lea dlg_validation(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr vdm_list_refresh
        moveq #0,d0
.out:
        rts

; A row selects; Show on map, Previous, Next and Close return 2, 1, 1, 0.
; Up and Down move the selection on the page; a double click on an issue
; with a place shows it on the map, like Show on map.
page_step:
        moveq #-1,d1
        cmpi.w #$CC,native_last_key
        beq.s .key
        moveq #1,d1
        cmpi.w #$CD,native_last_key
        bne.s .poll
.key:
        clr.w native_last_key
        add.w VDM_FOCUS,d1
        bmi edtr_modal_idle
        cmp.w VDM_PAGE_COUNT,d1
        bhs edtr_modal_idle
        move.w d1,VDM_FOCUS
        bsr.s vdm_list_refresh
        bra edtr_modal_idle
.poll:
        bsr dialog_poll
        bmi edtr_modal_idle
        cmpi.w #VDM_ROW_CODE,d0
        blo.s .button
        subi.w #VDM_ROW_CODE,d0
        lea VDM_CLICK,a0
        bsr dialog_double
        beq.s .focus
        move.w d0,d1
        lsl.w #4,d1
        lea VDM_PAGE,a0
        tst.b 7(a0,d1.w)
        beq edtr_modal_idle
        moveq #VDM_JUMP_CODE,d0
        bra.s .finish
.focus:
        move.w d0,VDM_FOCUS
        bsr.s vdm_list_refresh
        bra edtr_modal_idle
.button:
        cmpi.w #VDM_PREVIOUS_CODE,d0
        blo.s .finish
        ; Previous is disabled on the first page and Next on the last.
        move.l VDM_SKIP,d1
        cmpi.w #VDM_PREVIOUS_CODE,d0
        bne.s .forward
        subq.l #VDM_PAGE_ROWS,d1
        bcc.s .store
        moveq #0,d1
        bra.s .store
.forward:
        addq.l #VDM_PAGE_ROWS,d1
.store:
        move.l d1,VDM_SKIP
        moveq #1,d0
.finish:
        move.w d0,EXIT_CHOICE
        bra edtr_modal_finish

; Button states, the explanation of the selected row and the hint.
vdm_list_refresh:
        movem.l d0-d7/a0-a4,-(sp)
        moveq #0,d7
        move.w VDM_PAGE_COUNT,d0
.rows:
        cmpi.w #VDM_PAGE_ROWS,d0
        bhs.s .rows_done
        bset d0,d7
        addq.w #1,d0
        bra.s .rows
.rows_done:
        moveq #0,d6
        move.w VDM_FOCUS,d0
        cmp.w VDM_PAGE_COUNT,d0
        bhs.s .no_jump
        lsl.w #4,d0
        lea VDM_PAGE,a2
        adda.w d0,a2
        moveq #1,d6
        tst.b 7(a2)
        bne.s .jump
.no_jump:
        bset #8,d7
.jump:
        tst.l VDM_SKIP
        bne.s .previous
        bset #9,d7
.previous:
        move.l VDM_SKIP,d0
        addq.l #VDM_PAGE_ROWS,d0
        cmp.l VDM_TOTAL,d0
        blo.s .next
        bset #10,d7
.next:
        moveq #0,d2
.state:
        moveq #UI_DISABLED,d3
        btst d2,d7
        bne.s .set
        moveq #UI_NORMAL,d3
        cmp.w VDM_FOCUS,d2
        bne.s .set
        moveq #UI_ACTIVE,d3
.set:
        suba.l a0,a0
        bsr dialog_set
        addq.w #1,d2
        cmpi.w #11,d2
        blo.s .state
        ; D6: 0 no row, 1 a row; bit 8 of D7 clear when it is located.
        lea vdm_clean_detail(pc),a1
        lea vdm_clean_hint(pc),a3
        moveq #UI_OK,d4
        tst.w d6
        beq.s .detail
        bsr.s vdm_rule
        movea.l a4,a1
        moveq #UI_INK,d4
        lea vdm_global_hint(pc),a3
        btst #8,d7
        bne.s .detail
        lea vdm_located_hint(pc),a3
.detail:
        moveq #8,d1
        move.w #VDM_DETAIL_Y,d2
        move.w #292,d3
        moveq #UI_LEFT,d5
        bsr dialog_field
        movea.l a3,a1
        move.w #VDM_HINT_Y,d2
        moveq #UI_DIM,d4
        bsr dialog_field
        movem.l (sp)+,d0-d7/a0-a4
        rts

; A2 issue record -> A1 its short text, A4 its explanation. Clobbers D0.
vdm_rule:
        moveq #0,d0
        move.b 5(a2),d0
        lea vdm_errors(pc),a1
        tst.b 4(a2)
        beq.s .table
        lea vdm_reviews(pc),a1
.table:
        cmpi.w #32,d0
        blo.s .index
        subi.w #32,d0
        lea vdm_structural(pc),a1
.index:
        lsl.w #2,d0
        movea.l a1,a4
        adda.w 2(a1,d0.w),a4
        adda.w (a1,d0.w),a1
        rts

; The title in EXIT_TEXT, the header line in VDM_TEXT and the page's rows.
vdm_list_texts:
        movem.l d0-d6/a0-a4,-(sp)
        lea EXIT_TEXT,a0
        lea vdm_check_text(pc),a1
        bsr dialog_copy
        move.l VDM_ERRORS,d0
        or.l VDM_REVIEWS,d0
        bne.s .counts
        lea vdm_clean(pc),a1
        bsr dialog_copy
        bra.s .header
.counts:
        move.l VDM_ERRORS,d0
        bsr vdm_decimal
        lea vdm_errors_word(pc),a1
        cmpi.l #1,VDM_ERRORS
        bne.s .plural
        lea vdm_error_word(pc),a1
.plural:
        bsr dialog_copy
        move.l VDM_REVIEWS,d0
        bsr vdm_decimal
        lea vdm_to_review(pc),a1
        bsr dialog_copy
.header:
        lea VDM_TEXT,a0
        lea vdm_no_issues(pc),a1
        tst.l VDM_TOTAL
        beq.s .range_done
        lea vdm_issues(pc),a1
        bsr dialog_copy
        move.l VDM_SKIP,d0
        addq.l #1,d0
        bsr vdm_decimal
        move.b #'-',(a0)+
        moveq #0,d0
        move.w VDM_PAGE_COUNT,d0
        add.l VDM_SKIP,d0
        bsr vdm_decimal
        lea vdm_of(pc),a1
        bsr dialog_copy
        move.l VDM_TOTAL,d0
        bsr vdm_decimal
        lea vdm_stop(pc),a1
.range_done:
        bsr dialog_copy
        lea vdm_tested(pc),a1
        bsr dialog_copy
        bsr vdm_test_mask
        moveq #0,d1
        moveq #0,d2
.phase:
        cmp.b VDM_OWNER+AUR_PHASE_COUNT,d2
        bhs.s .phases_done
        btst d2,d0
        beq.s .untested
        move.b #' ',(a0)+
        move.b d2,(a0)
        addi.b #'1',(a0)+
        moveq #1,d1
.untested:
        addq.w #1,d2
        bra.s .phase
.phases_done:
        clr.b (a0)
        tst.w d1
        bne.s .rows
        lea vdm_tested_none(pc),a1
        bsr dialog_copy
.rows:
        lea VDM_ROW_TEXT,a3
        lea VDM_PAGE,a2
        moveq #0,d6
.row:
        movea.l a3,a0
        clr.b (a0)
        cmp.w VDM_PAGE_COUNT,d6
        bhs.s .row_next
        lea vdm_error_tag(pc),a1
        tst.b 4(a2)
        beq.s .severity
        lea vdm_review_tag(pc),a1
.severity:
        bsr dialog_copy
        move.b #'P',(a0)+
        move.b 6(a2),d0
        addi.b #'1',d0
        move.b d0,(a0)+
        move.b #' ',(a0)+
        move.b 7(a2),d0
        beq.s .place_done
        lea vdm_cell(pc),a1
        cmpi.b #1,d0
        beq.s .cell
        lea vdm_object(pc),a1
        bsr dialog_copy
        move.w 8(a2),d0
        addq.w #1,d0
        bsr dialog_number
        bra.s .place_done
.cell:
        bsr dialog_copy
        move.w 10(a2),d0
        bsr dialog_number
        move.b #',',(a0)+
        move.w 12(a2),d0
        bsr dialog_number
.place_done:
        lea VDM_PLACE_END(a3),a4
.pad:
        move.b #' ',(a0)+
        cmpa.l a4,a0
        blo.s .pad
        bsr vdm_rule
        bsr dialog_copy
.row_next:
        lea 16(a2),a2
        lea VDM_ROW_TEXT_BYTES(a3),a3
        addq.w #1,d6
        cmpi.w #VDM_PAGE_ROWS,d6
        blo .row
        movem.l (sp)+,d0-d6/a0-a4
        rts

; D0.l below 655360 written in decimal at A0, which ends on the NUL.
vdm_decimal:
        movem.l d0-d1,-(sp)
        moveq #0,d1
.divide:
        divu #10,d0
        swap d0
        addi.w #'0',d0
        move.w d0,-(sp)
        addq.w #1,d1
        clr.w d0
        swap d0
        tst.l d0
        bne.s .divide
        subq.w #1,d1
.emit:
        move.w (sp)+,d0
        move.b d0,(a0)+
        dbra d1,.emit
        clr.b (a0)
        movem.l (sp)+,d0-d1
        rts

vdm_test_mask:
        moveq #0,d0
        cmpi.l #E7_TAG,E7_CONTEXT
        bne.s .return
        move.b E7_TESTED,d0
        cmpi.w #63,d0
        bls.s .return
        moveq #0,d0
.return:
        rts

vdm_check_text: dc.b "Check: ",0
vdm_clean: dc.b "no problems found",0
vdm_errors_word: dc.b " errors, ",0
vdm_error_word: dc.b " error, ",0
vdm_to_review: dc.b " to review",0
vdm_no_issues: dc.b "No issues.",0
vdm_issues: dc.b "Issues ",0
vdm_of: dc.b " of ",0
vdm_stop: dc.b ".",0
vdm_tested: dc.b " Tested:",0
vdm_tested_none: dc.b " none",0
vdm_error_tag: dc.b "Error  ",0
vdm_review_tag: dc.b "Review ",0
vdm_cell: dc.b "Cell ",0
vdm_object: dc.b "Object ",0
vdm_clean_detail: dc.b "Nothing to fix in this mission.",0
vdm_clean_hint: dc.b "Test plays the phase being edited.",0
vdm_located_hint: dc.b "Show on map goes to this place.",0
vdm_global_hint: dc.b "This issue has no place on the map.",0
        even

; Rule texts: offsets of the short row text and of the explanation.
vdm_errors:
        dc.w .s0-vdm_errors,.d0-vdm_errors
        dc.w .s1-vdm_errors,.d1-vdm_errors
        dc.w .s2-vdm_errors,.d2-vdm_errors
        dc.w .s3-vdm_errors,.d3-vdm_errors
        dc.w .s4-vdm_errors,.d4-vdm_errors
        dc.w .s5-vdm_errors,.d5-vdm_errors
        dc.w .s6-vdm_errors,.d6-vdm_errors
        dc.w .s7-vdm_errors,.d7-vdm_errors
        dc.w .s8-vdm_errors,.d8-vdm_errors
        dc.w .s9-vdm_errors,.d9-vdm_errors
        dc.w .s10-vdm_errors,.d10-vdm_errors
        dc.w .s11-vdm_errors,.d11-vdm_errors
        dc.w .s12-vdm_errors,.d12-vdm_errors
        dc.w .s13-vdm_errors,.d13-vdm_errors
        dc.w .s14-vdm_errors,.d14-vdm_errors
        dc.w .s15-vdm_errors,.d15-vdm_errors
        dc.w .s16-vdm_errors,.d16-vdm_errors
        dc.w .s17-vdm_errors,.d17-vdm_errors
        dc.w .s18-vdm_errors,.d18-vdm_errors
        dc.w .s19-vdm_errors,.d19-vdm_errors
        dc.w .s20-vdm_errors,.d20-vdm_errors
.s0: dc.b "Map below 19 x 15",0
.d0: dc.b "Resize the map to at least 19 by 15 cells.",0
.s1: dc.b "Tile not in the terrain",0
.d1: dc.b "The cell uses a tile this terrain does not have.",0
.s2: dc.b "More than ten markers",0
.d2: dc.b "The game collects ten markers at most.",0
.s3: dc.b "Building parts missing",0
.d3: dc.b "Parts that must follow this object are missing.",0
.s4: dc.b "Too many objects to draw",0
.d4: dc.b "Its parts cross the 43-object drawing limit.",0
.s5: dc.b "Too many actors",0
.d5: dc.b "Its parts cross the first 30 object slots.",0
.s6: dc.b "Object X ends the list",0
.d6: dc.b "This X position ends the game's object list.",0
.s7: dc.b "Disabled object alone",0
.d7: dc.b "Only parts of a building may be disabled.",0
.s8: dc.b "Object X out of range",0
.d8: dc.b "This X position switches the object off.",0
.s9: dc.b "Counted object disabled",0
.d9: dc.b "A disabled object still counts for the goals.",0
.s10: dc.b "Object Y is negative",0
.d10: dc.b "Move the object onto the map.",0
.s11: dc.b "Actor after slot 30",0
.d11: dc.b "Soldiers, vehicles and pads need slots 1-30.",0
.s12: dc.b "No player soldier",0
.d12: dc.b "Place a soldier among the first 30 objects.",0
.s13: dc.b "More than 8 soldiers",0
.d13: dc.b "The squad holds eight soldiers at most.",0
.s14: dc.b "No objective can finish",0
.d14: dc.b "Choose an objective that ends the phase.",0
.s15: dc.b "Needs objectives 1 and 2",0
.d15: dc.b "Factory and computer also need goals 1 and 2.",0
.s16: dc.b "No computer to destroy",0
.d16: dc.b "Place a computer for this objective.",0
.s17: dc.b "No hostage or leader",0
.d17: dc.b "Place someone to rescue or kidnap.",0
.s18: dc.b "No rescue tent",0
.d18: dc.b "Place a rescue tent to bring them to.",0
.s19: dc.b "No civilian home",0
.d19: dc.b "Place a civilian home for this objective.",0
.s20: dc.b "Countdown needs no map",0
.d20: dc.b "The final-map countdown needs the overview off.",0
        even
vdm_reviews:
        dc.w .s0-vdm_reviews,.d0-vdm_reviews
        dc.w .s1-vdm_reviews,.d1-vdm_reviews
        dc.w .s2-vdm_reviews,.d2-vdm_reviews
        dc.w .s3-vdm_reviews,.d3-vdm_reviews
        dc.w .s4-vdm_reviews,.d4-vdm_reviews
        dc.w .s5-vdm_reviews,.d5-vdm_reviews
        dc.w .s6-vdm_reviews,.d6-vdm_reviews
        dc.w .s7-vdm_reviews,.d7-vdm_reviews
        dc.w .s8-vdm_reviews,.d8-vdm_reviews
        dc.w .s9-vdm_reviews,.d9-vdm_reviews
        dc.w .s10-vdm_reviews,.d10-vdm_reviews
.s0: dc.b "Tile 399 has no graphics",0
.d0: dc.b "The game draws garbage there. Use another tile.",0
.s1: dc.b "Reserved cell bits set",0
.d1: dc.b "Imported cell bits that the game does not use.",0
.s2: dc.b "Marker class 5 to 7",0
.d2: dc.b "Marker classes 5 to 7 have no known effect.",0
.s3: dc.b "Marker affects sight",0
.d3: dc.b "Markers change line of sight. Test the phase.",0
.s4: dc.b "Object outside the map",0
.d4: dc.b "Check that it appears where you want it.",0
.s5: dc.b "No enemies at start",0
.d5: dc.b "Kill all enemy is done at once without them.",0
.s6: dc.b "No buildings at start",0
.d6: dc.b "Destroy buildings is done at once without them.",0
.s7: dc.b "Factory is only a label",0
.d7: dc.b "Check that the right targets end the phase.",0
.s8: dc.b "Several rescue tents",0
.d8: dc.b "Only one tent takes the hostages. Test it.",0
.s9: dc.b "Civilian home untested",0
.d9: dc.b "Test the civilian's way home, and its death.",0
.s10: dc.b "Play once to confirm",0
.d10: dc.b "Some things are only confirmed by playing.",0
        even
vdm_structural:
        dc.w .s0-vdm_structural,.d0-vdm_structural
        dc.w .s1-vdm_structural,.d1-vdm_structural
        dc.w .s2-vdm_structural,.d2-vdm_structural
        dc.w .s3-vdm_structural,.d3-vdm_structural
        dc.w .s4-vdm_structural,.d4-vdm_structural
        dc.w .s5-vdm_structural,.d5-vdm_structural
        dc.w .s6-vdm_structural,.d6-vdm_structural
.s0: dc.b "Check failed",0
.d0: dc.b "The checker received a bad request.",0
.s1: dc.b "Settings damaged",0
.d1: dc.b "The phase settings record is damaged.",0
.s2: dc.b "Wrong file length",0
.d2: dc.b "A phase file has the wrong length.",0
.s3: dc.b "Checksum differs",0
.d3: dc.b "A phase file is damaged: its checksum differs.",0
.s4: dc.b "Map file damaged",0
.d4: dc.b "The map file of the phase is damaged.",0
.s5: dc.b "Terrain files differ",0
.d5: dc.b "The terrain's resource files do not match.",0
.s6: dc.b "Object file damaged",0
.d6: dc.b "The object file of the phase is damaged.",0
        even

; Rows on Y44-146; Show on map, Previous, Next and Close on Y180-193.
dlg_validation:
        dc.w 16,186,UI_SELECT
        dc.l EXIT_TEXT,vdm_body
        dc.w 8,0,12
        dc.w 8,44,292,12,VDM_ROW_CODE,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT
        dc.w 8,57,292,12,VDM_ROW_CODE+1,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+VDM_ROW_TEXT_BYTES
        dc.w 8,70,292,12,VDM_ROW_CODE+2,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+2*VDM_ROW_TEXT_BYTES
        dc.w 8,83,292,12,VDM_ROW_CODE+3,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+3*VDM_ROW_TEXT_BYTES
        dc.w 8,96,292,12,VDM_ROW_CODE+4,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+4*VDM_ROW_TEXT_BYTES
        dc.w 8,109,292,12,VDM_ROW_CODE+5,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+5*VDM_ROW_TEXT_BYTES
        dc.w 8,122,292,12,VDM_ROW_CODE+6,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+6*VDM_ROW_TEXT_BYTES
        dc.w 8,135,292,12,VDM_ROW_CODE+7,UI_NORMAL|DIALOG_ROW
        dc.l VDM_ROW_TEXT+7*VDM_ROW_TEXT_BYTES
        dc.w 8,180,100,14,VDM_JUMP_CODE,UI_NORMAL
        dc.l vdm_show_label
        dc.w 112,180,60,14,VDM_PREVIOUS_CODE,UI_NORMAL
        dc.l vdm_previous_label
        dc.w 176,180,60,14,VDM_PREVIOUS_CODE+1,UI_NORMAL
        dc.l vdm_next_label
        dc.w 240,180,60,14,0,UI_NORMAL
        dc.l vdm_close_label
vdm_body:
        dc.w UI_TEXT_AT,8,32,292,UI_DIM,UI_LEFT
        dc.l VDM_TEXT
        dc.w UI_END
vdm_show_label: dc.b "_Show on map",0
vdm_previous_label: dc.b "_Previous",0
vdm_next_label: dc.b "_Next",0
vdm_close_label: dc.b "_Close",0
        even
