; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Resize map: three dialogs of the Slave's dialog service on the same band,
; one per RZ_MODE. 0 chooses the size (steppers that repeat while held and
; are disabled at 19 by 15 and at 7,500 cells); 1 confirms, says that Undo is
; cleared and lists the removed objects one at a time; 2 names a refusal.
; EXIT_CHOICE=0 Cancel, 1 confirmed, 2 unchanged. Canonical owners are
; read-only; Continue stages the placements in RZ_SPT.
RZ_ACCEPT           equ 1
RZ_PREVIOUS         equ 3
RZ_NEXT             equ 4
RZ_BACK             equ 5
RZ_STEP             equ 20  ; 20..23 width minus, plus, height minus, plus
RZ_VALUE_Y          equ 99
RZ_LINE_Y           equ 70

page_open:
        bsr.s resize_dialog_descriptor
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr resize_dialog_draw
        moveq #0,d0
.out:
        rts

; A0 = the descriptor of RZ_MODE.
resize_dialog_descriptor:
        lea dlg_resize(pc),a0
        tst.w RZ_MODE
        beq.s .done
        lea dlg_resize_confirm(pc),a0
        cmpi.w #1,RZ_MODE
        beq.s .done
        lea dlg_resize_refused(pc),a0
.done:
        rts

page_step:
        bsr dialog_poll
        bmi edtr_modal_idle
        cmpi.w #RZ_STEP,d0
        bhs .step
        cmpi.w #RZ_PREVIOUS,d0
        beq .previous
        cmpi.w #RZ_NEXT,d0
        beq .next
        cmpi.w #RZ_BACK,d0
        beq.s .back
        tst.w d0
        beq.s .finish
        cmpi.w #1,RZ_MODE
        beq.s .finish
        ; Continue: an unchanged size returns at once, otherwise stage.
        move.w RZ_WIDTH,d1
        cmp.w editor_map_width,d1
        bne.s .stage
        move.w RZ_HEIGHT,d1
        cmp.w editor_map_height,d1
        bne.s .stage
        moveq #2,d0
.finish:
        move.w d0,EXIT_CHOICE
        bra edtr_modal_finish
.stage:
        bsr resize_stage_placements
        tst.l d0
        bmi.s .refused
        move.w RZ_SPT+2,RZ_COUNT
        move.l RZ_SPT+4,RZ_MASK_LOW
        move.l RZ_SPT+8,RZ_MASK_HIGH
        clr.w RZ_INDEX
        move.w #1,RZ_MODE
        bra.s .switch
.refused:
        move.w d0,RZ_ERROR
        move.w #2,RZ_MODE
        bra.s .switch
.back:
        clr.w RZ_MODE
.switch:
        bsr resize_dialog_descriptor
        moveq #0,d2
        bsr dialog_open
        bne.s .failed
        bsr.s resize_dialog_draw
        bra edtr_modal_idle
.failed:
        moveq #-1,d0
        bra.s .finish
.previous:
        tst.w RZ_INDEX
        beq.s .redraw
        subq.w #1,RZ_INDEX
        bra.s .redraw
.next:
        move.w RZ_INDEX,d1
        addq.w #1,d1
        cmp.w RZ_COUNT,d1
        bhs.s .redraw
        move.w d1,RZ_INDEX
        bra.s .redraw
.step:
        subi.w #RZ_STEP,d0
        lea RZ_WIDTH,a0
        move.w RZ_HEIGHT,d3
        moveq #19,d4
        cmpi.w #2,d0
        blo.s .direction
        lea RZ_HEIGHT,a0
        move.w RZ_WIDTH,d3
        moveq #15,d4
.direction:
        moveq #-1,d2
        btst #0,d0
        beq.s .change
        moveq #1,d2
.change:
        add.w (a0),d2
        cmp.w d4,d2
        blo.s .redraw
        mulu d2,d3
        cmpi.l #7500,d3
        bhi.s .redraw
        move.w d2,(a0)
.redraw:
        bsr.s resize_dialog_draw
        bra edtr_modal_idle

; The values, texts and button states of RZ_MODE.
resize_dialog_draw:
        movem.l d0-d5/a0-a1,-(sp)
        tst.w RZ_MODE
        beq .dimensions
        cmpi.w #1,RZ_MODE
        bne .refused
        ; Confirmation: the new size, then the removed object on view.
        lea EXIT_TEXT,a0
        lea resize_to_text(pc),a1
        bsr dialog_copy
        bsr resize_size_text
        lea resize_undo_text(pc),a1
        bsr dialog_copy
        lea EXIT_TEXT,a1
        moveq #16,d1
        moveq #RZ_LINE_Y,d2
        move.w #284,d3
        moveq #UI_INK,d4
        moveq #UI_LEFT,d5
        bsr dialog_field
        lea resize_keeps_text(pc),a1
        moveq #UI_OK,d4
        tst.w RZ_COUNT
        beq.s .count
        lea EXIT_TEXT,a0
        lea resize_removes_text(pc),a1
        bsr dialog_copy
        move.w RZ_COUNT,d0
        bsr dialog_number
        lea resize_objects_text(pc),a1
        cmpi.w #1,RZ_COUNT
        bne.s .plural
        lea resize_object_text(pc),a1
.plural:
        bsr dialog_copy
        lea EXIT_TEXT,a1
        moveq #UI_WARN,d4
.count:
        moveq #RZ_LINE_Y+14,d2
        bsr dialog_field
        lea EXIT_TEXT,a0
        clr.b (a0)
        tst.w RZ_COUNT
        beq.s .item
        bsr resize_find_removed
        tst.w d0
        bne.s .item
        ; "1 of 8: 00 SOLDIER, cell 40,22": the palette's name and the
        ; cell, as in the Check results.
        move.w RZ_INDEX,d0
        addq.w #1,d0
        bsr dialog_number
        lea resize_of_text(pc),a1
        bsr dialog_copy
        move.w RZ_COUNT,d0
        bsr dialog_number
        lea resize_colon_text(pc),a1
        bsr dialog_copy
        move.w 8(a4),d0
        bsr resize_type_name
        bsr resize_cell_text
.item:
        lea EXIT_TEXT,a1
        moveq #RZ_LINE_Y+28,d2
        moveq #UI_INK,d4
        bsr dialog_field
        ; Previous and Next while there is more than one removed object.
        moveq #0,d2
        moveq #UI_DISABLED,d3
        tst.w RZ_INDEX
        beq.s .previous
        moveq #UI_NORMAL,d3
.previous:
        suba.l a0,a0
        bsr dialog_set
        moveq #1,d2
        moveq #UI_DISABLED,d3
        move.w RZ_INDEX,d0
        addq.w #1,d0
        cmp.w RZ_COUNT,d0
        bhs.s .next
        moveq #UI_NORMAL,d3
.next:
        bsr dialog_set
        bra .done
.refused:
        lea resize_bad_text(pc),a1
        cmpi.w #-2,RZ_ERROR
        bne.s .reason
        lea resize_empty_text(pc),a1
.reason:
        moveq #16,d1
        moveq #RZ_LINE_Y,d2
        move.w #284,d3
        moveq #UI_INK,d4
        moveq #UI_LEFT,d5
        bsr dialog_field
        bra .done
.dimensions:
        move.w RZ_WIDTH,d0
        move.w RZ_HEIGHT,d1
        moveq #0,d2
        cmpi.w #19,d0
        sne d3
        bsr resize_enable
        move.w d0,d4
        addq.w #1,d4
        mulu d1,d4
        cmpi.l #7500,d4
        sls d3
        bsr resize_enable
        cmpi.w #15,d1
        sne d3
        bsr resize_enable
        move.w d1,d4
        addq.w #1,d4
        mulu d0,d4
        cmpi.l #7500,d4
        sls d3
        bsr.s resize_enable
        lea EXIT_NUMBER,a0
        bsr dialog_number
        lea EXIT_NUMBER,a1
        moveq #84,d1
        moveq #RZ_VALUE_Y,d2
        moveq #26,d3
        moveq #UI_INK,d4
        moveq #UI_RIGHT,d5
        bsr dialog_field
        move.w RZ_HEIGHT,d0
        lea EXIT_NUMBER,a0
        bsr dialog_number
        move.w #228,d1
        bsr dialog_field
        lea EXIT_TEXT,a0
        move.w RZ_WIDTH,d0
        mulu RZ_HEIGHT,d0
        bsr dialog_number
        lea resize_cells_text(pc),a1
        bsr dialog_copy
        lea EXIT_TEXT,a1
        moveq #16,d1
        moveq #RZ_VALUE_Y+18,d2
        move.w #284,d3
        moveq #UI_DIM,d4
        moveq #UI_LEFT,d5
        bsr dialog_field
.done:
        movem.l (sp)+,d0-d5/a0-a1
        rts

; The stepper D2.w is enabled while D3.b is nonzero; D2 moves to the next.
resize_enable:
        move.w d0,-(sp)
        tst.b d3
        bne.s .enabled
        moveq #UI_DISABLED,d3
        bra.s .set
.enabled:
        moveq #UI_NORMAL,d3
.set:
        suba.l a0,a0
        bsr dialog_set
        addq.w #1,d2
        move.w (sp)+,d0
        rts

; "W x H" of the proposal at A0, which ends on the NUL. Clobbers D0/A1.
resize_size_text:
        move.w RZ_WIDTH,d0
        bsr dialog_number
        lea resize_times_text(pc),a1
        bsr dialog_copy
        move.w RZ_HEIGHT,d0
        bra dialog_number

; Return A4=the selected removed root, D0=0; refuse a stale ordinal.
resize_find_removed:
        movem.l d5-d7/a0,-(sp)
        lea EDITOR_SPT_BASE,a4
        moveq #0,d7
        move.w RZ_INDEX,d6
        moveq #0,d5
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d5
        divu #10,d5
.record:
        cmp.w d5,d7
        bhs.s .missing
        move.l RZ_MASK_LOW,d0
        cmpi.w #32,d7
        blo.s .test
        move.l RZ_MASK_HIGH,d0
.test:
        btst d7,d0
        beq.s .next
        tst.w d6
        beq.s .found
        subq.w #1,d6
.next:
        moveq #0,d0
        move.w 8(a4),d0
        lea resize_spt_recipes(pc),a0
        move.b (a0,d0.w),d0
        andi.w #3,d0
        addq.w #1,d0
        add.w d0,d7
        mulu #10,d0
        adda.w d0,a4
        bra.s .record
.found:
        moveq #0,d0
        bra.s .return
.missing:
        moveq #-1,d0
.return:
        movem.l (sp)+,d5-d7/a0
        rts

; D0.w object type: its name in the object palette's catalog, or its type
; in hexadecimal when the catalog has no root of that type, at A0.
resize_type_name:
        movem.l d1/a1-a2,-(sp)
        lea pal_catalog(pc),a2
        move.w 2(a2),d1
        lsr.w #2,d1
        subq.w #1,d1
.entry:
        cmp.w (a2),d0
        beq.s .found
        addq.l #4,a2
        dbf d1,.entry
        lea resize_type_text(pc),a1
        bsr dialog_copy
        move.w d0,d1
        lsr.w #4,d0
        bsr.s .digit
        move.w d1,d0
        bsr.s .digit
        clr.b (a0)
        bra.s .out
.digit:
        andi.w #15,d0
        addi.b #'0',d0
        cmpi.b #'9',d0
        bls.s .put
        addq.b #'A'-'9'-1,d0
.put:
        move.b d0,(a0)+
        rts
.found:
        lea pal_catalog(pc),a1
        adda.w 2(a2),a1
.name:
        move.b (a1)+,d1
        cmpi.b #$ff,d1
        beq.s .end
        move.b d1,(a0)+
        bra.s .name
.end:
        clr.b (a0)
.out:
        movem.l (sp)+,d1/a1-a2
        rts

; ", cell X,Y" of the object record A4 at A0: its map pixel position over 16.
resize_cell_text:
        lea resize_cell_label(pc),a1
        bsr dialog_copy
        move.w 4(a4),d0
        addi.w #16,d0
        lsr.w #4,d0
        bsr dialog_number
        move.b #',',(a0)+
        move.w 6(a4),d0
        lsr.w #4,d0
        bra dialog_number

resize_times_text: dc.b " x ",0
resize_cells_text: dc.b " of 7500 cells",0
resize_to_text: dc.b "Resize to ",0
resize_undo_text: dc.b " cells. Undo is cleared.",0
resize_keeps_text: dc.b "Every object stays on the map.",0
resize_removes_text: dc.b "Removes ",0
resize_objects_text: dc.b " objects outside the new size:",0
resize_object_text: dc.b " object outside the new size:",0
resize_of_text: dc.b " of ",0
resize_colon_text: dc.b ": ",0
resize_type_text: dc.b "type ",0
resize_cell_label: dc.b ", cell ",0
resize_bad_text: dc.b "Object data is not consistent; nothing changed.",0
resize_empty_text: dc.b "No object would remain; nothing changed.",0
        even

; All three share the band of the New mission dialog.
dlg_resize:
        dc.w 52,108,UI_SELECT
        dc.l resize_title,resize_body
        dc.w 4,0,6
        dc.w 62,96,18,14,RZ_STEP,UI_NORMAL|DIALOG_REPEAT
        dc.l resize_less
        dc.w 114,96,18,14,RZ_STEP+1,UI_NORMAL|DIALOG_REPEAT
        dc.l resize_more
        dc.w 206,96,18,14,RZ_STEP+2,UI_NORMAL|DIALOG_REPEAT
        dc.l resize_less
        dc.w 258,96,18,14,RZ_STEP+3,UI_NORMAL|DIALOG_REPEAT
        dc.l resize_more
        dc.w 16,138,92,14,RZ_ACCEPT,UI_NORMAL
        dc.l resize_continue
        dc.w 208,138,92,14,0,UI_NORMAL
        dc.l resize_cancel
resize_body:
        dc.w UI_TEXT,16,RZ_LINE_Y,284,UI_INK,UI_LEFT
        dc.b "New cells take the selected tile.",0
        dc.w UI_TEXT,16,RZ_LINE_Y+10,284,UI_DIM,UI_LEFT
        dc.b "Removed objects are listed before any change.",0
        even
        dc.w UI_TEXT,16,RZ_VALUE_Y,44,UI_DIM,UI_LEFT
        dc.b "Width",0
        even
        dc.w UI_TEXT,160,RZ_VALUE_Y,44,UI_DIM,UI_LEFT
        dc.b "Height",0
        even
        dc.w UI_END
dlg_resize_confirm:
        dc.w 52,108,UI_ERROR
        dc.l resize_confirm_title,0
        dc.w 3,0,4
        dc.w 16,138,68,14,RZ_PREVIOUS,UI_NORMAL
        dc.l resize_previous
        dc.w 88,138,68,14,RZ_NEXT,UI_NORMAL
        dc.l resize_next
        dc.w 160,138,68,14,RZ_ACCEPT,UI_NORMAL
        dc.l resize_resize
        dc.w 232,138,68,14,0,UI_NORMAL
        dc.l resize_cancel
dlg_resize_refused:
        dc.w 52,108,UI_ERROR
        dc.l resize_refused_title,resize_refused_body
        dc.w 0,0,2
        dc.w 16,138,92,14,RZ_BACK,UI_NORMAL
        dc.l resize_back
        dc.w 208,138,92,14,0,UI_NORMAL
        dc.l resize_cancel
resize_refused_body:
        dc.w UI_TEXT,16,RZ_LINE_Y+14,284,UI_DIM,UI_LEFT
        dc.b "Back chooses another size.",0
        even
        dc.w UI_END
resize_title: dc.b "Resize map",0
resize_confirm_title: dc.b "Resize map: confirm",0
resize_refused_title: dc.b "Cannot resize",0
resize_less: dc.b "-",0
resize_more: dc.b "+",0
resize_continue: dc.b "_Continue",0
resize_previous: dc.b "_Previous",0
resize_next: dc.b "_Next",0
resize_resize: dc.b "_Resize",0
resize_back: dc.b "_Back",0
resize_cancel: dc.b "Cancel",0
        even
