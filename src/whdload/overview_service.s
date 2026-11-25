; Cannon Fodder In-Game Level Editor V1.2.6
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Overview minimap of the dialog service (functions DIALOG_OVERVIEW and
; DIALOG_OVERVIEW_POLL, see dialog.i). Drawn inside a standard dialog band
; directly by the Slave so it costs no BaseMem module budget and opens without
; reloading an overlay. Clicking on the minimap returns a positive packed
; origin ($40000000 | (x << 16) | y) for the caller to jump the camera.
OV_TOP              equ 8
OV_HEIGHT           equ 216
OV_BOX_X            equ 12
OV_BOX_Y            equ 24
OV_BOX_W            equ 280
OV_BOX_H            equ 160
OV_SPT_BYTES        equ EDITOR_METADATA_BASE+38

; D2.w=view_origin_x, D3.w=view_origin_y. Opens the Overview dialog and draws
; the terrain-class minimap, placed objects and current viewport frame.
; D0.l=0 open, 10 refused.
dialog_overview:
        movem.l d2-d7/a0-a6,-(sp)
        lea ov_origin_x(pc),a0
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w editor_map_width,d4
        move.w editor_map_height,d5
        tst.w d4
        beq .refuse
        tst.w d5
        beq .refuse
        cmpi.w #321,d4
        bhi .refuse
        cmpi.w #500,d5
        bhi .refuse
        move.w d4,(a0)+
        move.w d5,(a0)+
        ; Choose largest integer scale 1..8 fitting in 280x160, or downsample
        ; divisor D in 2..4 when wider than 280 or taller than 160.
        moveq #1,d6                 ; D = divisor (1 = upscaled)
        moveq #8,d7                 ; S = scale
        cmpi.w #OV_BOX_W,d4
        bhi.s .down
        cmpi.w #OV_BOX_H,d5
        bhi.s .down
.try_scale:
        move.w d4,d0
        mulu d7,d0
        cmpi.l #OV_BOX_W,d0
        bhi.s .next_scale
        move.w d5,d1
        mulu d7,d1
        cmpi.l #OV_BOX_H,d1
        bls.s .have_dims
.next_scale:
        subq.w #1,d7
        cmpi.w #1,d7
        bhi.s .try_scale
        move.w d4,d0
        move.w d5,d1
        bra.s .have_dims
.down:
        moveq #0,d7
        moveq #2,d6
.try_down:
        moveq #0,d0
        move.w d4,d0
        divu d6,d0
        moveq #0,d1
        move.w d5,d1
        divu d6,d1
        cmpi.w #OV_BOX_W,d0
        bhi.s .next_down
        cmpi.w #OV_BOX_H,d1
        bls.s .have_dims
.next_down:
        addq.w #1,d6
        cmpi.w #4,d6
        bls.s .try_down
        bra .refuse
.have_dims:
        tst.w d0
        beq .refuse
        tst.w d1
        beq .refuse
        move.w d7,(a0)+             ; ov_scale
        move.w d6,(a0)+             ; ov_div
        move.w d0,(a0)+             ; ov_disp_w
        move.w d1,(a0)+             ; ov_disp_h
        move.w #OV_BOX_W,d2
        sub.w d0,d2
        lsr.w #1,d2
        addi.w #OV_BOX_X+4,d2
        andi.w #$FFF8,d2            ; 8-px align ov_ox for packed byte writes
        move.w d2,(a0)+             ; ov_ox
        move.w #OV_BOX_H,d3
        sub.w d1,d3
        lsr.w #1,d3
        addi.w #OV_BOX_Y,d3
        move.w d3,(a0)+             ; ov_oy
        move.w native_left_down,(a0) ; ov_held
        ; Format "<W>x<H>" into ov_size_text.
        lea ov_size_text(pc),a0
        move.w d4,d0
        bsr ov_append_number
        move.b #'x',(a0)+
        move.w d5,d0
        bsr ov_append_number
        clr.b (a0)
        ; Build absolute descriptor copy (Slave has no relocations).
        lea ov_template(pc),a1
        move.l a1,d3
        lea ov_descriptor(pc),a0
        movea.l a0,a2
        move.l (a1)+,(a2)+
        move.w (a1)+,(a2)+
        bsr.s .abs
        bsr.s .abs
        move.l (a1)+,(a2)+
        move.w (a1)+,(a2)+
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        bsr.s .abs
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        ; Crop to the 224 dialog rows even when opened from the 240-row view;
        ; DIALOG_CLOSE restores editor_copper_fetch from ExpMem.
        move.w #$10b1,editor_copper_fetch
        bsr ov_draw_map
        moveq #0,d0
.out:
        movem.l (sp)+,d2-d7/a0-a6
        rts
.refuse:
        moveq #10,d0
        bra.s .out
.abs:
        move.l (a1)+,d0
        add.l d3,d0
        move.l d0,(a2)+
        rts

; One frame of Overview input. Returns -1 while open, 0 on Close/Esc/M/right,
; or $40000000 | (origin_x << 16) | origin_y when the user clicks the minimap.
dialog_overview_poll:
        movem.l d1-d5/a0,-(sp)
        move.w dlg_open(pc),d0
        beq .close
        ; M closes the Overview directly.
        move.w native_last_key,d0
        cmpi.w #'M',d0
        beq .key_close
        cmpi.w #'m',d0
        beq .key_close
        ; Left click inside the minimap jumps the camera there.
        lea ov_held(pc),a0
        tst.w native_left_down
        bne.s .left_down
        clr.w (a0)
        bra.s .delegate
.left_down:
        tst.w (a0)
        bne.s .delegate
        move.w native_mouse_x,d1
        addi.w #16,d1
        move.w native_mouse_y,d2
        sub.w ov_ox(pc),d1
        bmi.s .delegate
        cmp.w ov_disp_w(pc),d1
        bhs.s .delegate
        sub.w ov_oy(pc),d2
        bmi.s .delegate
        cmp.w ov_disp_h(pc),d2
        bhs.s .delegate
        move.w #1,(a0)
        ; Convert minimap offset (D1, D2) to map cell (cx, cy).
        move.w ov_scale(pc),d3
        beq.s .down_click
        ext.l d1
        divu d3,d1
        ext.l d2
        divu d3,d2
        bra.s .center
.down_click:
        move.w ov_div(pc),d3
        mulu d3,d1
        mulu d3,d2
.center:
        subi.w #9,d1
        bpl.s .cx_ok
        moveq #0,d1
.cx_ok:
        subq.w #6,d2
        bpl.s .cy_ok
        moveq #0,d2
.cy_ok:
        andi.l #$3FFF,d1
        swap d1
        andi.l #$FFFF,d2
        or.l d2,d1
        ori.l #$40000000,d1
        move.l d1,d0
        bra.s .done
.key_close:
        clr.w native_last_key
.close:
        moveq #0,d0
        bra.s .done
.delegate:
        bsr dialog_poll
.done:
        movem.l (sp)+,d1-d5/a0
        rts

; Draw the minimap, placed objects, viewport rectangle and header size text.
ov_draw_map:
        movem.l d0-d7/a0-a6,-(sp)
        ; Right-aligned map dimensions in the title strip via dialog_ui.
        lea dlg_list(pc),a0
        move.w #UI_TEXT_AT,(a0)+
        move.l #(212<<16)|12,(a0)+
        move.l #(88<<16)|UI_ACCENT,(a0)+
        move.w #UI_RIGHT,(a0)+
        lea ov_size_text(pc),a2
        move.l a2,(a0)+
        clr.w (a0)
        lea dlg_list(pc),a0
        bsr dialog_ui
        ; Target DIALOG_PANEL directly via ui_rect/ui_frame (A5=plane0, A1=stride).
        ; Must be loaded after dialog_ui, which overwrites A1 with dlg_target.
        lea DIALOG_PANEL,a5
        movea.l #DIALOG_PANEL_STRIDE,a1
        ; Frame around the minimap.
        move.w ov_ox(pc),d1
        subq.w #1,d1
        move.w ov_oy(pc),d2
        subq.w #1,d2
        move.w ov_disp_w(pc),d3
        addq.w #2,d3
        move.w ov_disp_h(pc),d6
        addq.w #2,d6
        moveq #UI_LIGHT,d4
        bsr ui_frame
        ; Render terrain cells into the minimap.
        lea editor_map_grid,a3
        lea editor_hit_table,a4
        move.w ov_scale(pc),d7
        beq .render_down
        cmpi.w #2,d7
        beq .render_2x2
        cmpi.w #1,d7
        beq .render_1x1
        ; Upscaled (S = 3..8 pixels per cell; small maps only).
        move.w ov_oy(pc),d2
        moveq #0,d5                 ; row y
.up_row:
        cmp.w ov_map_h(pc),d5
        bhs .objects
        move.w ov_ox(pc),d1
        moveq #0,d0                 ; col x
.up_col:
        cmp.w ov_map_w(pc),d0
        bhs.s .up_next_row
        move.w (a3)+,d4
        bsr ov_cell_colour
        move.w d7,d3
        move.w d7,d6
        bsr ui_rect
        add.w d7,d1
        addq.w #1,d0
        bra.s .up_col
.up_next_row:
        add.w d7,d2
        addq.w #1,d5
        bra.s .up_row
.render_2x2:
        ; Fast 8-aligned 2x2 cell path: packs 4 cells into 1 byte per plane,
        ; cutting chip-RAM traffic ~12x (pure byte writes for full 4-cell groups).
        move.w ov_oy(pc),d2
        mulu #UI_ROW_BYTES,d2
        move.w ov_ox(pc),d0
        lsr.w #3,d0
        add.w d0,d2
        lea (a5,d2.l),a0            ; row pointer in plane 0
        move.w ov_map_h(pc),d5
        subq.w #1,d5
.r2_row:
        movea.l a0,a2
        move.w ov_map_w(pc),d7
        move.w d7,d6
        lsr.w #2,d6                 ; full 4-cell bytes
        beq.s .r2_tail_init
        subq.w #1,d6
.r2_quad:
        ; Accumulate 4 cells' 4 bitplane bytes in D0 (p0|p1<<8) and D1 (p2|p3<<8).
        moveq #0,d0
        moveq #0,d1
        moveq #3,d2
.r2_qcell:
        add.w d0,d0
        add.w d0,d0
        andi.w #$FCFC,d0
        add.w d1,d1
        add.w d1,d1
        andi.w #$FCFC,d1
        move.w (a3)+,d4
        bsr ov_cell_colour
        btst #0,d4
        beq.s .r2_q1
        ori.b #3,d0
.r2_q1:
        btst #1,d4
        beq.s .r2_q2
        ori.w #$0300,d0
.r2_q2:
        btst #2,d4
        beq.s .r2_q3
        ori.b #3,d1
.r2_q3:
        btst #3,d4
        beq.s .r2_qn
        ori.w #$0300,d1
.r2_qn:
        dbra d2,.r2_qcell
        movea.l a2,a6
        move.b d0,(a6)
        move.b d0,UI_ROW_BYTES(a6)
        adda.l a1,a6
        lsr.w #8,d0
        move.b d0,(a6)
        move.b d0,UI_ROW_BYTES(a6)
        adda.l a1,a6
        move.b d1,(a6)
        move.b d1,UI_ROW_BYTES(a6)
        adda.l a1,a6
        lsr.w #8,d1
        move.b d1,(a6)
        move.b d1,UI_ROW_BYTES(a6)
        addq.l #1,a2
        dbra d6,.r2_quad
.r2_tail_init:
        andi.w #3,d7
        beq.s .r2_next_row
        move.w #$00C0,d1
        subq.w #1,d7
.r2_tail:
        move.w (a3)+,d4
        bsr ov_cell_colour
        move.b d1,d2
        not.b d2
        movea.l a2,a6
        moveq #0,d0
.r2_tplane:
        btst d0,d4
        beq.s .r2_tclr
        or.b d1,(a6)
        or.b d1,UI_ROW_BYTES(a6)
        bra.s .r2_tnp
.r2_tclr:
        and.b d2,(a6)
        and.b d2,UI_ROW_BYTES(a6)
.r2_tnp:
        adda.l a1,a6
        addq.w #1,d0
        cmpi.w #4,d0
        blo.s .r2_tplane
        lsr.b #2,d1
        dbra d7,.r2_tail
.r2_next_row:
        lea UI_ROW_BYTES*2(a0),a0
        dbra d5,.r2_row
        bra .objects
.render_1x1:
        ; Fast 1x1 cell path (zero mulu per cell).
        move.w ov_oy(pc),d2
        mulu #UI_ROW_BYTES,d2
        move.w ov_ox(pc),d0
        lsr.w #3,d0
        add.w d0,d2
        lea (a5,d2.l),a0
        move.w ov_map_h(pc),d5
        subq.w #1,d5
.r1_row:
        movea.l a0,a2
        move.w ov_ox(pc),d6
        andi.w #7,d6
        neg.w d6
        addq.w #7,d6
        move.w ov_map_w(pc),d7
        subq.w #1,d7
.r1_col:
        move.w (a3)+,d4
        bsr ov_cell_colour
        movea.l a2,a6
        moveq #0,d0
.r1_plane:
        btst d0,d4
        beq.s .r1_clr
        bset d6,(a6)
        bra.s .r1_np
.r1_clr:
        bclr d6,(a6)
.r1_np:
        adda.l a1,a6
        addq.w #1,d0
        cmpi.w #4,d0
        blo.s .r1_plane
        subq.w #1,d6
        bpl.s .r1_next
        moveq #7,d6
        addq.l #1,a2
.r1_next:
        dbra d7,.r1_col
        lea UI_ROW_BYTES(a0),a0
        dbra d5,.r1_row
        bra .objects
.render_down:
        ; Downsampled (D = 2..4 cells per pixel).
        move.w ov_div(pc),d7
        move.w ov_oy(pc),d2
        moveq #0,d5                 ; screen py
.dn_row:
        cmp.w ov_disp_h(pc),d5
        bhs.s .objects
        move.w d5,d6
        mulu d7,d6
        mulu ov_map_w(pc),d6
        add.l d6,d6
        lea 0(a3,d6.l),a2
        move.w ov_ox(pc),d1
        moveq #0,d0                 ; screen px
.dn_col:
        cmp.w ov_disp_w(pc),d0
        bhs.s .dn_next_row
        move.w d0,d6
        mulu d7,d6
        add.w d6,d6
        move.w 0(a2,d6.w),d4
        bsr ov_cell_colour
        bsr ov_plot_pixel
        addq.w #1,d1
        addq.w #1,d0
        bra.s .dn_col
.dn_next_row:
        addq.w #1,d2
        addq.w #1,d5
        bra.s .dn_row
.objects:
        ; Overlay placed objects from EDITOR_SPT_BASE.
        moveq #0,d7
        move.w OV_SPT_BYTES,d7
        cmpi.w #430,d7
        bhi .viewport
        divu #10,d7
        tst.w d7
        beq .viewport
        lea EDITOR_SPT_BASE,a3
        subq.w #1,d7
.obj_loop:
        cmpi.w #$7FEF,4(a3)
        bhi .obj_next
        tst.w 6(a3)
        bmi .obj_next
        move.w 8(a3),d0
        cmpi.w #110,d0
        bhi .obj_next
        ; Classify colour: 0=Soldier (white 15), enemies (red 10), else ink (6).
        moveq #15,d4
        tst.w d0
        beq.s .obj_pos
        moveq #UI_ERROR,d4
        cmpi.w #5,d0
        beq.s .obj_pos
        cmpi.w #6,d0
        beq.s .obj_pos
        cmpi.w #$14,d0
        beq.s .obj_pos
        cmpi.w #$3B,d0
        beq.s .obj_pos
        cmpi.w #$57,d0
        beq.s .obj_pos
        cmpi.w #$58,d0
        beq.s .obj_pos
        moveq #UI_INK,d4
.obj_pos:
        move.w 4(a3),d1
        addi.w #16,d1
        lsr.w #4,d1
        cmp.w ov_map_w(pc),d1
        blo.s .ox_ok
        move.w ov_map_w(pc),d1
        subq.w #1,d1
.ox_ok:
        move.w 6(a3),d2
        lsr.w #4,d2
        cmp.w ov_map_h(pc),d2
        blo.s .oy_ok
        move.w ov_map_h(pc),d2
        subq.w #1,d2
.oy_ok:
        move.w ov_scale(pc),d3
        beq.s .obj_down
        mulu d3,d1
        mulu d3,d2
        cmpi.w #2,d3
        bhs.s .obj_clamp
        moveq #2,d3
        bra.s .obj_clamp
.obj_down:
        move.w ov_div(pc),d3
        ext.l d1
        divu d3,d1
        ext.l d2
        divu d3,d2
        moveq #2,d3
.obj_clamp:
        move.w d3,d6
        move.w d1,d0
        add.w d3,d0
        cmp.w ov_disp_w(pc),d0
        bls.s .obj_w_ok
        move.w ov_disp_w(pc),d3
        sub.w d1,d3
.obj_w_ok:
        move.w d2,d0
        add.w d6,d0
        cmp.w ov_disp_h(pc),d0
        bls.s .obj_h_ok
        move.w ov_disp_h(pc),d6
        sub.w d2,d6
.obj_h_ok:
        add.w ov_ox(pc),d1
        add.w ov_oy(pc),d2
        bsr ui_rect
.obj_next:
        lea 10(a3),a3
        dbra d7,.obj_loop
.viewport:
        ; Draw current camera viewport box in UI_ACCENT (yellow).
        move.w ov_origin_x(pc),d1
        move.w ov_origin_y(pc),d2
        moveq #19,d3
        moveq #12,d6
        move.w ov_map_w(pc),d0
        sub.w d1,d0
        cmp.w d3,d0
        bhs.s .vw_c
        move.w d0,d3
.vw_c:
        move.w ov_map_h(pc),d0
        sub.w d2,d0
        cmp.w d6,d0
        bhs.s .vh_c
        move.w d0,d6
.vh_c:
        move.w ov_scale(pc),d7
        beq.s .vp_down
        mulu d7,d1
        mulu d7,d2
        mulu d7,d3
        mulu d7,d6
        bra.s .vp_draw
.vp_down:
        move.w ov_div(pc),d7
        ext.l d1
        divu d7,d1
        ext.l d2
        divu d7,d2
        ext.l d3
        divu d7,d3
        ext.l d6
        divu d7,d6
        cmpi.w #3,d3
        bhs.s .vpw_ok
        moveq #3,d3
.vpw_ok:
        cmpi.w #3,d6
        bhs.s .vp_draw
        moveq #3,d6
.vp_draw:
        add.w ov_ox(pc),d1
        add.w ov_oy(pc),d2
        moveq #UI_ACCENT,d4
        bsr ui_frame
        movem.l (sp)+,d0-d7/a0-a6
        rts

; D4.w map cell word -> D4.w UI palette colour index. A4 = editor_hit_table.
; Preserves D0-D3/D5-D7/A0-A6.
ov_cell_colour:
        ; Marker bits 13..15 highlight in yellow accent.
        move.w d4,d3
        andi.w #$E000,d3
        beq.s .terrain
        moveq #UI_ACCENT,d4
        rts
.terrain:
        andi.w #$1FF,d4
        cmpi.w #400,d4
        blo.s .lookup
        moveq #UI_BG,d4
        rts
.lookup:
        add.w d4,d4
        move.w 0(a4,d4.w),d4
        tst.w d4
        bpl.s .plain
        ; Mixed tile: prefer Shallows if either half is water/shallows, else dim.
        move.w d4,d3
        andi.w #15,d3
        cmpi.w #5,d3
        beq.s .shallows
        cmpi.w #6,d3
        beq.s .shallows
        move.w d4,d3
        lsr.w #4,d3
        andi.w #15,d3
        cmpi.w #5,d3
        beq.s .shallows
        cmpi.w #6,d3
        beq.s .shallows
        moveq #UI_DIM,d4
        rts
.shallows:
        moveq #UI_FACE_HOVER,d4
        rts
.plain:
        andi.w #15,d4
        move.b ov_class_colours(pc,d4.w),d4
        andi.w #15,d4
        rts
ov_class_colours:
        ; 0 Ground, 1-2 Rocks, 3 Blocked, 4 Quicksand, 5 Shallows, 6 Water,
        ; 7 Rough, 8 Slippery, 9 Drop, 10 Pit, 11 Sinking, 12..15 Slope/Ramp.
        dc.b UI_OK,UI_DIM,UI_DIM,UI_FACE,UI_WARN,UI_FACE_HOVER,UI_SELECT,UI_LIGHT
        dc.b UI_LIGHT,UI_WARN,UI_WARN,UI_WARN,UI_LIGHT,UI_LIGHT,UI_LIGHT,UI_LIGHT

; Fast 1x1 pixel plot at (D1.w=x, D2.w=y) in colour D4.w into DIALOG_PANEL
; (A5=plane0, A1=DIALOG_PANEL_STRIDE). Preserves D0-D2/D4-D7/A0-A6.
ov_plot_pixel:
        movem.l d3/d6/a2,-(sp)
        move.w d2,d3
        mulu #UI_ROW_BYTES,d3
        move.w d1,d6
        lsr.w #3,d6
        add.w d6,d3
        lea (a5,d3.l),a2
        moveq #7,d6
        and.w d1,d6
        neg.w d6
        addq.w #7,d6
        moveq #0,d3
.p:
        btst d3,d4
        beq.s .c
        bset d6,(a2)
        bra.s .n
.c:
        bclr d6,(a2)
.n:
        adda.l a1,a2
        addq.w #1,d3
        cmpi.w #4,d3
        blo.s .p
        movem.l (sp)+,d3/d6/a2
        rts

; Append unsigned D0.w (0..999) in decimal to A0. Clobbers D0-D2/A1.
ov_append_number:
        lea ov_num_buf(pc),a1
        moveq #0,d2
.div:
        andi.l #$FFFF,d0
        divu #10,d0
        swap d0
        addi.b #'0',d0
        move.b d0,(a1)+
        addq.w #1,d2
        swap d0
        tst.w d0
        bne.s .div
.copy:
        move.b -(a1),(a0)+
        subq.w #1,d2
        bne.s .copy
        rts

ov_template:
        dc.w OV_TOP,OV_HEIGHT,UI_SELECT
        dc.l ov_title-ov_template,ov_body-ov_template
        dc.w 0,0,1
        dc.w 224,202,68,14,0,UI_NORMAL
        dc.l ov_close_label-ov_template
ov_body:
        ; Legend swatches + labels on Y188.
        dc.w UI_RECT,12,189,6,6,UI_OK
        dc.w UI_TEXT,20,188,40,UI_DIM,UI_LEFT
        dc.b "Ground",0
        even
        dc.w UI_RECT,62,189,6,6,UI_SELECT
        dc.w UI_TEXT,70,188,34,UI_DIM,UI_LEFT
        dc.b "Water",0
        dc.w UI_RECT,106,189,6,6,UI_FACE
        dc.w UI_TEXT,114,188,34,UI_DIM,UI_LEFT
        dc.b "Block",0
        dc.w UI_RECT,150,189,6,6,UI_WARN
        dc.w UI_TEXT,158,188,40,UI_DIM,UI_LEFT
        dc.b "Hazard",0
        even
        dc.w UI_RECT,200,189,6,6,15
        dc.w UI_TEXT,208,188,22,UI_DIM,UI_LEFT
        dc.b "You",0
        dc.w UI_RECT,232,189,6,6,UI_ERROR
        dc.w UI_TEXT,240,188,34,UI_DIM,UI_LEFT
        dc.b "Enemy",0
        dc.w UI_TEXT,12,206,204,UI_DIM,UI_LEFT
        dc.b "Click map to jump. Esc/M: close.",0
        even
        dc.w UI_END

ov_title:       dc.b "Overview",0
ov_close_label: dc.b "_Close",0
        even
ov_origin_x:    dc.w 0
ov_origin_y:    dc.w 0
ov_map_w:       dc.w 0
ov_map_h:       dc.w 0
ov_scale:       dc.w 0
ov_div:         dc.w 0
ov_disp_w:      dc.w 0
ov_disp_h:      dc.w 0
ov_ox:          dc.w 0
ov_oy:          dc.w 0
ov_held:        dc.w 0
ov_size_text:   dcb.b 12,0
ov_num_buf:     dcb.b 8,0
ov_descriptor:  dcb.b DIALOG_BUTTONS+DIALOG_BUTTON_BYTES,0
        even
