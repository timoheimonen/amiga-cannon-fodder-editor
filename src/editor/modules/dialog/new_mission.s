; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; New mission: a dialog of the Slave's dialog service. Six terrain buttons,
; width and height steppers that repeat while held and are disabled at the
; limits (19 by 15 cells at least, 7,500 cells at most), Create and Cancel;
; with NEW_DIALOG_WITH_TEMPLATE also Template.... NEW_DIALOG_PHASE titles
; it for a blank phase. The includer defines the words NEW_DIALOG_FAMILY,
; _WIDTH and _HEIGHT and includes text.s.
NEW_DIALOG_CREATE     equ 1
NEW_DIALOG_FROM_TEMPLATE equ 2
NEW_DIALOG_TERRAIN    equ 10
NEW_DIALOG_WIDTH_LESS equ 20
NEW_DIALOG_WIDTH_MORE equ 21
NEW_DIALOG_HEIGHT_LESS equ 22
NEW_DIALOG_HEIGHT_MORE equ 23
NEW_DIALOG_VALUE_Y    equ 113
NEW_DIALOG_CELLS_Y    equ 127

; D0.l=0 open, otherwise refused.
new_dialog_open:
        lea dlg_new_mission(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr.s new_dialog_draw
        moveq #0,d0
.out:
        rts

; D0.w polled code -> D0.l 0 Cancel, 1 Create, 2 Template, or -1 when the
; choice changed the dialog, which is redrawn.
new_dialog_event:
        cmpi.w #NEW_DIALOG_FROM_TEMPLATE,d0
        bhi.s .control
        ext.l d0
        rts
.control:
        movem.l d1-d4/a0,-(sp)
        subi.w #NEW_DIALOG_TERRAIN,d0
        cmpi.w #6,d0
        bhs.s .dimension
        move.w d0,NEW_DIALOG_FAMILY
        bra.s .draw
.dimension:
        subi.w #NEW_DIALOG_WIDTH_LESS-NEW_DIALOG_TERRAIN,d0
        lea NEW_DIALOG_WIDTH,a0
        move.w NEW_DIALOG_HEIGHT,d3
        moveq #19,d4
        cmpi.w #2,d0
        blo.s .step
        lea NEW_DIALOG_HEIGHT,a0
        move.w NEW_DIALOG_WIDTH,d3
        moveq #15,d4
.step:
        moveq #-1,d2
        btst #0,d0
        beq.s .apply
        moveq #1,d2
.apply:
        add.w (a0),d2
        cmp.w d4,d2
        blo.s .draw
        mulu d2,d3
        cmpi.l #7500,d3
        bhi.s .draw
        move.w d2,(a0)
.draw:
        bsr.s new_dialog_draw
        movem.l (sp)+,d1-d4/a0
        moveq #-1,d0
        rts

; Terrain selection, stepper states, the two values and the cell count.
new_dialog_draw:
        movem.l d0-d5/a0-a1,-(sp)
        moveq #0,d2
.terrain:
        moveq #UI_NORMAL,d3
        cmp.w NEW_DIALOG_FAMILY,d2
        bne.s .terrain_state
        moveq #UI_ACTIVE,d3
.terrain_state:
        suba.l a0,a0
        bsr dialog_set
        addq.w #1,d2
        cmpi.w #6,d2
        blo.s .terrain
        move.w NEW_DIALOG_WIDTH,d0
        move.w NEW_DIALOG_HEIGHT,d1
        cmpi.w #19,d0
        sne d3
        bsr new_dialog_enable
        move.w d0,d4
        addq.w #1,d4
        mulu d1,d4
        cmpi.l #7500,d4
        sls d3
        bsr new_dialog_enable
        cmpi.w #15,d1
        sne d3
        bsr new_dialog_enable
        move.w d1,d4
        addq.w #1,d4
        mulu d0,d4
        cmpi.l #7500,d4
        sls d3
        bsr.s new_dialog_enable
        lea EXIT_NUMBER,a0
        bsr dialog_number
        lea EXIT_NUMBER,a1
        moveq #84,d1
        moveq #NEW_DIALOG_VALUE_Y,d2
        moveq #26,d3
        moveq #UI_INK,d4
        moveq #UI_RIGHT,d5
        bsr dialog_field
        move.w NEW_DIALOG_HEIGHT,d0
        lea EXIT_NUMBER,a0
        bsr dialog_number
        move.w #228,d1
        bsr dialog_field
        move.w NEW_DIALOG_WIDTH,d0
        mulu NEW_DIALOG_HEIGHT,d0
        lea EXIT_NUMBER,a0
        bsr dialog_number
        lea new_dialog_cells(pc),a1
        bsr dialog_copy
        lea EXIT_NUMBER,a1
        moveq #16,d1
        moveq #NEW_DIALOG_CELLS_Y,d2
        move.w #272,d3
        moveq #UI_DIM,d4
        moveq #UI_LEFT,d5
        bsr dialog_field
        movem.l (sp)+,d0-d5/a0-a1
        rts

; The stepper D2.w is enabled while D3.b is nonzero; D2 moves to the next.
new_dialog_enable:
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

new_dialog_cells: dc.b " of 7500 cells",0
        even
; Create keeps the old hit zone on Y136-151.
dlg_new_mission:
        dc.w 52,108,UI_SELECT
        dc.l new_dialog_title,new_dialog_body
        ifd NEW_DIALOG_WITH_TEMPLATE
        dc.w 10,0,13
        else
        dc.w 10,0,12
        endif
        dc.w 16,77,92,14,NEW_DIALOG_TERRAIN,UI_NORMAL
        dc.l new_dialog_jungle_a
        dc.w 112,77,92,14,NEW_DIALOG_TERRAIN+1,UI_NORMAL
        dc.l new_dialog_jungle_b
        dc.w 208,77,92,14,NEW_DIALOG_TERRAIN+2,UI_NORMAL
        dc.l new_dialog_ice
        dc.w 16,93,92,14,NEW_DIALOG_TERRAIN+3,UI_NORMAL
        dc.l new_dialog_desert
        dc.w 112,93,92,14,NEW_DIALOG_TERRAIN+4,UI_NORMAL
        dc.l new_dialog_moor
        dc.w 208,93,92,14,NEW_DIALOG_TERRAIN+5,UI_NORMAL
        dc.l new_dialog_interior
        dc.w 62,110,18,14,NEW_DIALOG_WIDTH_LESS,UI_NORMAL|DIALOG_REPEAT
        dc.l new_dialog_less
        dc.w 114,110,18,14,NEW_DIALOG_WIDTH_MORE,UI_NORMAL|DIALOG_REPEAT
        dc.l new_dialog_more
        dc.w 206,110,18,14,NEW_DIALOG_HEIGHT_LESS,UI_NORMAL|DIALOG_REPEAT
        dc.l new_dialog_less
        dc.w 258,110,18,14,NEW_DIALOG_HEIGHT_MORE,UI_NORMAL|DIALOG_REPEAT
        dc.l new_dialog_more
        dc.w 16,138,92,14,NEW_DIALOG_CREATE,UI_NORMAL
        dc.l new_dialog_create
        dc.w 208,138,92,14,0,UI_NORMAL
        dc.l new_dialog_cancel
        ifd NEW_DIALOG_WITH_TEMPLATE
        dc.w 112,138,92,14,NEW_DIALOG_FROM_TEMPLATE,UI_NORMAL
        dc.l new_dialog_template
        endif
new_dialog_body:
        dc.w UI_TEXT_AT,16,67,272,UI_DIM,UI_LEFT
        dc.l new_dialog_terrain
        dc.w UI_TEXT_AT,16,NEW_DIALOG_VALUE_Y,44,UI_DIM,UI_LEFT
        dc.l new_dialog_width
        dc.w UI_TEXT_AT,160,NEW_DIALOG_VALUE_Y,44,UI_DIM,UI_LEFT
        dc.l new_dialog_height
        dc.w UI_END
        ifd NEW_DIALOG_PHASE
new_dialog_title: dc.b "Add blank phase",0
        else
new_dialog_title: dc.b "New mission",0
        endif
new_dialog_terrain: dc.b "Terrain",0
new_dialog_width: dc.b "Width",0
new_dialog_height: dc.b "Height",0
new_dialog_less: dc.b "-",0
new_dialog_more: dc.b "+",0
new_dialog_create: dc.b "Create",0
new_dialog_cancel: dc.b "Cancel",0
        ifd NEW_DIALOG_WITH_TEMPLATE
new_dialog_template: dc.b "Template...",0
        endif
new_dialog_jungle_a: dc.b "Jungle A",0
new_dialog_jungle_b: dc.b "Jungle B",0
new_dialog_ice: dc.b "Ice",0
new_dialog_desert: dc.b "Desert",0
new_dialog_moor: dc.b "Moor",0
new_dialog_interior: dc.b "Interior",0
        even
