; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Mission and phase settings: one dialog of the Slave's dialog service with
; every editable field of the private candidate. Objectives are toggle
; buttons with the completion rule of the last one changed, numbers have
; steppers that repeat while held and are disabled at their limits, and the
; other policies are toggles. Done records the intent and closes; all
; directory checks and COMMIT happen after the dialog has closed. The host
; supplies EXIT_LIST, EXIT_TEXT, EXIT_NUMBER, EXIT_HELD and EXIT_CHOICE.
PHD_DONE            equ 1
PHD_TITLE           equ 3   ; 3 mission title, 4 phase title
PHD_OBJECTIVE       equ 10  ; 10..17 objectives 1..8
PHD_STEP            equ 20  ; 20..27 minus and plus of the steppers
PHD_TOGGLE          equ 30  ; 30..34 fields 7..11
PHD_OBJECTIVE_BUTTON equ 2
PHD_STEP_BUTTON     equ 10
PHD_TOGGLE_BUTTON   equ 18
PHD_TITLE_CHARS     equ 32
PHD_RULE_Y          equ 119
PHD_REFUSED         equ EXIT_HELD

; Requires BEGIN. D0.l=0 open, otherwise refused.
phd_open:
        lea EXIT_TEXT,a0
        lea phd_phase_label(pc),a1
        bsr dialog_copy
        moveq #0,d0
        move.b AUR_BASE+AUR_SELECTED,d0
        addq.w #1,d0
        bsr dialog_number
        lea phd_of(pc),a1
        bsr dialog_copy
        moveq #0,d0
        move.b AUR_BASE+AUR_PHASE_COUNT,d0
        bsr dialog_number
        ; The rule line starts with the first objective of the phase.
        moveq #0,d0
        move.b PHM_DRAFT+CFMD_OBJECTIVES,d0
        move.w d0,PHM_OBJECTIVE
        clr.w PHD_REFUSED
        lea dlg_phase_settings(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr phd_refresh
        moveq #0,d0
.out:
        rts

; One frame of input. Returns through edtr_modal_idle or, with EXIT_CHOICE
; 0 cancel, 1 Done or 3 title entry for PHM_FIELD, through edtr_modal_finish.
phd_step:
        bsr dialog_poll
        bmi edtr_modal_idle
        clr.w PHD_REFUSED
        cmpi.w #PHD_DONE,d0
        bhi.s .control
        bne.s .finish
        move.w #1,PHM_READY
.finish:
        move.w d0,EXIT_CHOICE
        bra edtr_modal_finish
.control:
        cmpi.w #PHD_OBJECTIVE,d0
        bhs.s .objective
        subq.w #PHD_TITLE,d0
        move.w d0,PHM_FIELD
        moveq #3,d0
        bra.s .finish
.objective:
        cmpi.w #PHD_STEP,d0
        bhs.s .step
        subi.w #PHD_OBJECTIVE-1,d0
        move.w d0,PHM_OBJECTIVE
        bsr phm_toggle_objective
        bpl.s .redraw
        move.w #1,PHD_REFUSED
        bra.s .redraw
.step:
        move.w d0,d3
        cmpi.w #PHD_TOGGLE,d0
        bhs.s .toggle
        subi.w #PHD_STEP,d3
        moveq #0,d0
        move.w d3,d0
        lsr.w #1,d0
        move.b phd_step_fields(pc,d0.w),d0
        bsr phm_value_number
        subq.l #1,d1
        btst #0,d3
        beq.s .set
        addq.l #2,d1
        bra.s .set
.toggle:
        subi.w #PHD_TOGGLE-7,d0
        bsr phm_value_number
        tst.l d1
        seq d1
        andi.l #1,d1
        beq.s .set
        cmpi.w #7,d0
        bne.s .set
        moveq #2,d1
.set:
        bsr phm_set
.redraw:
        bsr.s phd_refresh
        bra edtr_modal_idle
phd_step_fields: dc.b 2,6,4,5
        even

; Redraw every value, button state and the rule line from the candidate.
phd_refresh:
        movem.l d0-d7/a0-a1,-(sp)
        lea PHM_DRAFT+CFMD_TITLE,a1
        moveq #26,d2
        bsr phd_title
        lea PHM_DRAFT+CFMD_PHASE_TITLE,a1
        moveq #41,d2
        bsr phd_title
        moveq #PHD_OBJECTIVE_BUTTON,d2
        moveq #0,d6
.objective:
        moveq #UI_NORMAL,d3
        btst d6,PHM_DRAFT+CFMD_OBJECTIVE_MASK
        beq.s .objective_state
        moveq #UI_ACTIVE,d3
.objective_state:
        suba.l a0,a0
        bsr dialog_set
        addq.w #1,d2
        addq.w #1,d6
        cmpi.w #8,d6
        blo.s .objective
        ; Recruits, rank and the aggression range.
        moveq #PHD_STEP_BUTTON,d6
        moveq #2,d0
        moveq #1,d4
        move.l #32767,d5
        bsr phd_stepper
        moveq #6,d0
        moveq #0,d4
        moveq #7,d5
        bsr phd_stepper
        moveq #4,d0
        moveq #0,d4
        moveq #0,d5
        move.b PHM_DRAFT+CFMD_AGGRESSION_MAX,d5
        bsr.s phd_stepper
        moveq #5,d0
        moveq #0,d4
        move.b PHM_DRAFT+CFMD_AGGRESSION_MIN,d4
        moveq #20,d5
        bsr.s phd_stepper
        ; Toggles: active and labelled with their value.
        moveq #7,d0
.toggle:
        bsr phm_value_number
        move.w d0,d7
        subq.w #7,d7
        lsl.w #3,d7
        lea phd_toggle_labels(pc),a1
        adda.w d7,a1
        moveq #UI_ACTIVE,d3
        tst.l d1
        bne.s .toggle_state
        moveq #UI_NORMAL,d3
        addq.l #4,a1
.toggle_state:
        movea.l (a1),a0
        move.w d6,d2
        move.w d0,d7
        bsr dialog_set
        move.w d7,d0
        addq.w #1,d6
        addq.w #1,d0
        cmpi.w #12,d0
        blo.s .toggle
        ; The completion rule of the last objective, or the refusal.
        lea phd_refused(pc),a1
        moveq #UI_ERROR,d4
        tst.w PHD_REFUSED
        bne.s .line
        move.w PHM_OBJECTIVE,d0
        subq.w #1,d0
        add.w d0,d0
        lea phd_rules(pc),a1
        adda.w (a1,d0.w),a1
        moveq #UI_DIM,d4
.line:
        moveq #8,d1
        moveq #PHD_RULE_Y,d2
        move.w #292,d3
        moveq #UI_LEFT,d5
        bsr dialog_field
        movem.l (sp)+,d0-d7/a0-a1
        rts

; D0.w field, D4.l lowest and D5.l highest value, D6.w index of the minus
; button; D6 advances to the next stepper. Clobbers D0-D5/D7/A0-A1.
phd_stepper:
        bsr.s phm_value_number
        move.l d1,d7
        moveq #UI_NORMAL,d3
        cmp.l d4,d7
        bhi.s .minus
        moveq #UI_DISABLED,d3
.minus:
        move.w d6,d2
        suba.l a0,a0
        bsr dialog_set
        moveq #UI_NORMAL,d3
        cmp.l d5,d7
        blo.s .plus
        moveq #UI_DISABLED,d3
.plus:
        addq.w #1,d2
        bsr dialog_set
        lea EXIT_NUMBER,a0
        move.w d7,d0
        bsr dialog_number
        move.w d6,d1
        lsl.w #4,d1
        lea dlg_phase_settings+DIALOG_BUTTONS(pc),a0
        move.w DIALOG_BUTTON_Y(a0,d1.w),d2
        move.w DIALOG_BUTTON_X(a0,d1.w),d1
        addi.w #14,d1
        addq.w #3,d2
        moveq #30,d3
        moveq #UI_ACCENT,d4
        moveq #UI_CENTER,d5
        lea EXIT_NUMBER,a1
        bsr dialog_field
        addq.w #2,d6
        rts

; D0.w=scalar field 2,4..11; D1.l=value. Preserves D0, clobbers D2/A0.
phm_value_number:
        moveq #0,d1
        cmpi.w #2,d0
        bne.s .byte
        move.w PHM_DRAFT+CFMD_RECRUITS,d1
        rts
.byte:
        cmpi.w #9,d0
        bhs.s .flag
        move.w d0,d2
        subi.w #4,d2
        lea PHM_DRAFT+CFMD_AGGRESSION_MIN,a0
        move.b (a0,d2.w),d1
        rts
.flag:
        move.w d0,d2
        subi.w #9,d2
        btst d2,PHM_DRAFT+CFMD_FLAGS
        beq.s .return
        moveq #1,d1
.return:
        rts

; A1 title ending with $FF, D2.w Y: at most PHD_TITLE_CHARS characters.
phd_title:
        lea EXIT_TEXT,a0
        moveq #PHD_TITLE_CHARS-1,d0
.copy:
        move.b (a1)+,d1
        cmpi.b #$FF,d1
        beq.s .end
        move.b d1,(a0)+
        dbf d0,.copy
.end:
        clr.b (a0)
        lea EXIT_TEXT,a1
        moveq #56,d1
        move.w #PHD_TITLE_CHARS*UI_CELL_WIDTH,d3
        moveq #UI_INK,d4
        moveq #UI_LEFT,d5
        bra dialog_field

phd_toggle_labels:
        dc.l phd_two_each,phd_none,phd_one_each,phd_none
        dc.l phd_on,phd_off,phd_on,phd_off,phd_on,phd_off
phd_rules:
        dc.w .one-phd_rules,.two-phd_rules,.three-phd_rules,.four-phd_rules
        dc.w .five-phd_rules,.six-phd_rules,.seven-phd_rules,.eight-phd_rules
.one: dc.b "Kill all enemy: every counted enemy must die.",0
.two: dc.b "Destroy buildings: every counted one must go.",0
.three: dc.b "Rescue hostages: the rescue count reaches zero.",0
.four: dc.b "Protect civilians: a civilian death fails.",0
.five: dc.b "Kidnap leader: the rescue count reaches zero.",0
.six: dc.b "Destroy factory: a label, 1 and 2 decide.",0
.seven: dc.b "Destroy computer: a label, 1 and 2 decide.",0
.eight: dc.b "Get civilian home: a civilian reaches home.",0
phd_refused: dc.b "A phase needs at least one objective.",0
phd_phase_label: dc.b "Phase ",0
phd_of: dc.b " of ",0
phd_two_each: dc.b "2 each",0
phd_one_each: dc.b "1 each",0
phd_none: dc.b "None",0
phd_on: dc.b "On",0
phd_off: dc.b "Off",0
        even

; Buttons in index order: two Rename, eight objectives, four steppers (minus
; then plus), five toggles, Done (default) and Cancel.
dlg_phase_settings:
        dc.w 8,216,UI_SELECT
        dc.l phd_heading,phd_body
        dc.w 23,0,25
        dc.w 252,23,48,13,PHD_TITLE,UI_NORMAL
        dc.l phd_rename
        dc.w 252,38,48,13,PHD_TITLE+1,UI_NORMAL
        dc.l phd_rename
        dc.w 8,65,144,12,PHD_OBJECTIVE,UI_NORMAL
        dc.l phd_kill
        dc.w 156,65,144,12,PHD_OBJECTIVE+1,UI_NORMAL
        dc.l phd_buildings
        dc.w 8,78,144,12,PHD_OBJECTIVE+2,UI_NORMAL
        dc.l phd_hostages
        dc.w 156,78,144,12,PHD_OBJECTIVE+3,UI_NORMAL
        dc.l phd_civilians
        dc.w 8,91,144,12,PHD_OBJECTIVE+4,UI_NORMAL
        dc.l phd_leader
        dc.w 156,91,144,12,PHD_OBJECTIVE+5,UI_NORMAL
        dc.l phd_factory
        dc.w 8,104,144,12,PHD_OBJECTIVE+6,UI_NORMAL
        dc.l phd_computer
        dc.w 156,104,144,12,PHD_OBJECTIVE+7,UI_NORMAL
        dc.l phd_home
        dc.w 96,132,14,13,PHD_STEP,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_less
        dc.w 140,132,14,13,PHD_STEP+1,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_more
        dc.w 240,132,14,13,PHD_STEP+2,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_less
        dc.w 284,132,14,13,PHD_STEP+3,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_more
        dc.w 96,147,14,13,PHD_STEP+4,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_less
        dc.w 140,147,14,13,PHD_STEP+5,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_more
        dc.w 240,147,14,13,PHD_STEP+6,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_less
        dc.w 284,147,14,13,PHD_STEP+7,UI_NORMAL|DIALOG_REPEAT
        dc.l phd_more
        dc.w 96,162,58,13,PHD_TOGGLE,UI_NORMAL
        dc.l phd_none
        dc.w 240,162,58,13,PHD_TOGGLE+1,UI_NORMAL
        dc.l phd_none
        dc.w 96,177,58,13,PHD_TOGGLE+2,UI_NORMAL
        dc.l phd_off
        dc.w 240,177,58,13,PHD_TOGGLE+3,UI_NORMAL
        dc.l phd_off
        dc.w 96,192,58,13,PHD_TOGGLE+4,UI_NORMAL
        dc.l phd_off
        dc.w 16,206,92,14,PHD_DONE,UI_NORMAL
        dc.l phd_done
        dc.w 208,206,92,14,0,UI_NORMAL
        dc.l dlg_cancel_label
phd_body:
        dc.w UI_TEXT_AT,128,12,172,UI_ACCENT,UI_RIGHT
        dc.l EXIT_TEXT
        dc.w UI_TEXT,8,26,46,UI_DIM,UI_LEFT
        dc.b "Mission",0
        dc.w UI_TEXT,8,41,46,UI_DIM,UI_LEFT
        dc.b "Phase",0
        dc.w UI_TEXT,8,55,288,UI_DIM,UI_LEFT
        dc.b "Objectives",0
        even
        dc.w UI_TEXT,8,135,86,UI_INK,UI_LEFT
        dc.b "Recruits",0
        even
        dc.w UI_TEXT,160,135,78,UI_INK,UI_LEFT
        dc.b "Recruit rank",0
        even
        dc.w UI_TEXT,8,150,86,UI_INK,UI_LEFT
        dc.b "Aggression",0
        even
        dc.w UI_TEXT,160,150,78,UI_INK,UI_LEFT
        dc.b "up to",0
        dc.w UI_TEXT,8,165,86,UI_INK,UI_LEFT
        dc.b "Grenades",0
        even
        dc.w UI_TEXT,160,165,78,UI_INK,UI_LEFT
        dc.b "Rockets",0
        dc.w UI_TEXT,8,180,86,UI_INK,UI_LEFT
        dc.b "Enemy grenades",0
        even
        dc.w UI_TEXT,160,180,78,UI_INK,UI_LEFT
        dc.b "Overview map",0
        even
        dc.w UI_TEXT,8,195,86,UI_INK,UI_LEFT
        dc.b "Countdown",0
        dc.w UI_END
phd_heading: dc.b "Mission and phase settings",0
phd_rename: dc.b "Rename",0
phd_kill: dc.b "Kill all enemy",0
phd_buildings: dc.b "Destroy buildings",0
phd_hostages: dc.b "Rescue hostages",0
phd_civilians: dc.b "Protect civilians",0
phd_leader: dc.b "Kidnap enemy leader",0
phd_factory: dc.b "Destroy factory",0
phd_computer: dc.b "Destroy computer",0
phd_home: dc.b "Get civilian home",0
phd_less: dc.b "-",0
phd_more: dc.b "+",0
phd_done: dc.b "_Done",0
        even
