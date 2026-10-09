; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Display ownership shared by the map view (EDTR, OBJV) and the tile and
; object pages (TILE, OPAL). display_acquire saves the native display globals
; at edtr_state and shows CANVAS above the 48-line tool bar; display_release
; puts everything back. The including module supplies set_ring, which places
; the ring origin of its canvas. Both routines clobber D0-D7/A0-A6.

; The native globals the view saves lie at $80010..$828A6, within (d16,A5)
; reach of the executable's base; native_mask_discarded_guard and the copper
; list are addressed absolutely.
DISPLAY_BASE    equ FODDERS_BASE
DISPLAY_SLOTS   equ edtr_state

display_acquire:
        lea DISPLAY_BASE,a5
        lea DISPLAY_SLOTS,a6
        move.w native_gameplay_active-DISPLAY_BASE(a5),saved_active-DISPLAY_SLOTS(a6)
        clr.w native_gameplay_active-DISPLAY_BASE(a5)
        move.w native_cursor_active-DISPLAY_BASE(a5),saved_sidebar_mode-DISPLAY_SLOTS(a6)
        clr.w native_cursor_active-DISPLAY_BASE(a5)
        move.l display_draw_buffer-DISPLAY_BASE(a5),saved_draw-DISPLAY_SLOTS(a6)
        move.l display_visible_buffer-DISPLAY_BASE(a5),saved_visible-DISPLAY_SLOTS(a6)
        move.l CAMERA_X-DISPLAY_BASE(a5),saved_camera-DISPLAY_SLOTS(a6)
        move.l CAMERA_Y-DISPLAY_BASE(a5),saved_camera+4-DISPLAY_SLOTS(a6)
        move.l RING_X-DISPLAY_BASE(a5),saved_ring-DISPLAY_SLOTS(a6)
        move.l RING_Y-DISPLAY_BASE(a5),saved_ring+4-DISPLAY_SLOTS(a6)
        move.w native_mask_discarded_guard,saved_mask_guard-DISPLAY_SLOTS(a6)
        move.l native_text_x_width-DISPLAY_BASE(a5),saved_text-DISPLAY_SLOTS(a6)
        move.l native_text_y_height-DISPLAY_BASE(a5),saved_text+4-DISPLAY_SLOTS(a6)
        move.l native_descriptor_table-DISPLAY_BASE(a5),saved_table-DISPLAY_SLOTS(a6)
        move.w native_mask_mode-DISPLAY_BASE(a5),saved_mask_mode-DISPLAY_SLOTS(a6)
        move.w native_fifth_plane-DISPLAY_BASE(a5),saved_fifth-DISPLAY_SLOTS(a6)
        move.w native_text_space_substitute-DISPLAY_BASE(a5),saved_space-DISPLAY_SLOTS(a6)
        move.w native_text_alternate-DISPLAY_BASE(a5),saved_alternate-DISPLAY_SLOTS(a6)
        move.l native_cursor_offsets-DISPLAY_BASE(a5),saved_cursor_offsets-DISPLAY_SLOTS(a6)
        clr.l native_cursor_offsets-DISPLAY_BASE(a5)
        movem.l editor_fade_state-DISPLAY_BASE(a5),d0-d3
        movem.l d0-d3,saved_fade-DISPLAY_SLOTS(a6)
        movem.l editor_native_palette-DISPLAY_BASE(a5),d0-d7
        movem.l d0-d7,saved_palette-DISPLAY_SLOTS(a6)
        move.l #CANVAS,display_draw_buffer-DISPLAY_BASE(a5)
        lea editor_copper_list,a0
        lea saved_copper,a1
        move.w #$c00/4-1,d0
.save_copper:
        move.l (a0)+,(a1)+
        dbra d0,.save_copper
        clr.l EMPTY_SPRITE
        lea native_sidebar_pointer_high,a0
        moveq #5,d0
.hide_sidebar:
        move.w #EMPTY_SPRITE>>16,(a0)
        move.w #EMPTY_SPRITE&$ffff,4(a0)
        addq.l #8,a0
        dbra d0,.hide_sidebar
        lea copper_template(pc),a0
        lea BAR_COPPER,a1
        moveq #(copper_end-copper_template)/4-1,d0
.copper:
        move.l (a0)+,(a1)+
        dbra d0,.copper
        ; The terrain palette goes to the game's palette, the copper colours
        ; 0-15 and the tool bar's lower band.
        lea editor_base_palette,a0
        lea editor_native_palette-DISPLAY_BASE(a5),a1
        lea native_copper_color0,a2
        lea BAR_COPPER+toolbar_palette-copper_template+2,a3
        moveq #15,d0
.base_palette:
        move.w (a0)+,d1
        move.w d1,(a1)+
        move.w d1,(a2)
        move.w d1,(a3)
        addq.l #4,a2
        addq.l #4,a3
        dbra d0,.base_palette
        ; A2 now addresses color 16. Colors 16-31 belong to the attached
        ; pointer, which the outgoing screen left black.
        lea pointer_palette(pc),a0
        moveq #15,d0
.pointer_palette:
        move.w (a0)+,(a2)
        addq.l #4,a2
        dbra d0,.pointer_palette
        moveq #15,d0
        move.w d0,editor_fade_state-DISPLAY_BASE(a5)
        move.w d0,editor_fade_state+4-DISPLAY_BASE(a5)
        moveq #0,d0
        move.l d0,RING_X-DISPLAY_BASE(a5)
        move.l d0,RING_Y-DISPLAY_BASE(a5)
        move.l d0,CAMERA_X-DISPLAY_BASE(a5)
        move.l d0,CAMERA_Y-DISPLAY_BASE(a5)
        bsr set_ring
        bsr.s publish_ring
        move.l #$00840000+(WRAP_COPPER>>16),editor_copper_tail
        move.l #$00860000+(WRAP_COPPER&$ffff),editor_copper_tail+4
        move.l #$008a0000,editor_copper_tail+8
        clr.w editor_copper_scroll
        ; DIWSTOP: X 304 and line 288 for the 48-line bar; release restores it.
        move.w #$20b1,editor_copper_fetch
        move.l #CANVAS,d0
        bsr.s display_planes
        move.l #-1,last_camera
        rts

; Point the four copper bitplane pointers at D0, DISPLAY_PLANE apart.
; Clobbers D0-D1/A0.
display_planes:
        lea editor_copper_planes,a0
        moveq #3,d1
.plane:
        swap d0
        move.w d0,(a0)
        swap d0
        move.w d0,4(a0)
        add.l #DISPLAY_PLANE,d0
        addq.l #8,a0
        dbra d1,.plane
        rts

; Copy the canvas's first row into each plane's guard row, show the ring from
; ring_base and split it where it wraps. Records the camera it shows.
publish_ring:
.busy:
        btst #6,amiga_dmacon_read
        bne.s .busy
        lea CANVAS,a0
        moveq #3,d0
.guard_plane:
        movea.l a0,a1
        lea RING_BYTES(a0),a2
        moveq #ROW_BYTES/4-1,d1
.guard_long:
        move.l (a1)+,(a2)+
        dbra d1,.guard_long
        lea DISPLAY_PLANE(a0),a0
        dbra d0,.guard_plane
        moveq #0,d0
        move.w ring_base+PCREL(pc),d0
        add.l #CANVAS,d0
        bsr.s display_planes
        move.w #256+48,d2
        sub.w RING_Y,d2
        moveq #0,d0
        move.w RING_X,d0
        lsr.w #3,d0
        cmp.w #240,d2
        blo.s .wrap
        moveq #48,d2
        move.w ring_base+PCREL(pc),d0
.wrap:
        lsl.w #8,d2
        or.w #1,d2
        move.w d2,WRAP_COPPER
        move.w #$fffe,WRAP_COPPER+2
        add.l #CANVAS,d0
        lea WRAP_COPPER+4,a0
        move.w #$e0,d2
        moveq #3,d1
.wrap_planes:
        move.w d2,(a0)+
        addq.w #2,d2
        swap d0
        move.w d0,(a0)+
        swap d0
        move.w d2,(a0)+
        addq.w #2,d2
        move.w d0,(a0)+
        add.l #DISPLAY_PLANE,d0
        dbra d1,.wrap_planes
        move.l view_origin_x+PCREL(pc),last_camera
        rts

; Restore the copper list and the native display globals saved by
; display_acquire.
display_release:
        lea DISPLAY_BASE,a5
        lea DISPLAY_SLOTS,a6
        move.l saved_cursor_offsets-DISPLAY_SLOTS(a6),native_cursor_offsets-DISPLAY_BASE(a5)
.busy:
        btst #6,amiga_dmacon_read
        bne.s .busy
        lea saved_copper,a0
        lea editor_copper_list,a1
        move.w #$c00/4-1,d0
.restore_copper:
        move.l (a0)+,(a1)+
        dbra d0,.restore_copper
        move.l saved_draw-DISPLAY_SLOTS(a6),display_draw_buffer-DISPLAY_BASE(a5)
        move.l saved_visible-DISPLAY_SLOTS(a6),display_visible_buffer-DISPLAY_BASE(a5)
        move.l saved_camera-DISPLAY_SLOTS(a6),CAMERA_X-DISPLAY_BASE(a5)
        move.l saved_camera+4-DISPLAY_SLOTS(a6),CAMERA_Y-DISPLAY_BASE(a5)
        move.l saved_ring-DISPLAY_SLOTS(a6),RING_X-DISPLAY_BASE(a5)
        move.l saved_ring+4-DISPLAY_SLOTS(a6),RING_Y-DISPLAY_BASE(a5)
        move.l saved_text-DISPLAY_SLOTS(a6),native_text_x_width-DISPLAY_BASE(a5)
        move.l saved_text+4-DISPLAY_SLOTS(a6),native_text_y_height-DISPLAY_BASE(a5)
        move.w saved_sidebar_mode-DISPLAY_SLOTS(a6),native_cursor_active-DISPLAY_BASE(a5)
        move.w saved_mask_mode-DISPLAY_SLOTS(a6),native_mask_mode-DISPLAY_BASE(a5)
        ; No authoring view regenerates masks while it is live, so the bank still
        ; matches the incoming table unless another one was installed meanwhile.
        movea.l saved_table-DISPLAY_SLOTS(a6),a0
        cmpa.l native_descriptor_table-DISPLAY_BASE(a5),a0
        beq.s .masks_current
        movea.l a0,a5
        jsr native_font_masks
        lea DISPLAY_BASE,a5
        lea DISPLAY_SLOTS,a6
.masks_current:
        move.w saved_mask_guard-DISPLAY_SLOTS(a6),native_mask_discarded_guard
        move.w saved_fifth-DISPLAY_SLOTS(a6),native_fifth_plane-DISPLAY_BASE(a5)
        move.w saved_space-DISPLAY_SLOTS(a6),native_text_space_substitute-DISPLAY_BASE(a5)
        move.w saved_alternate-DISPLAY_SLOTS(a6),native_text_alternate-DISPLAY_BASE(a5)
        movem.l saved_palette-DISPLAY_SLOTS(a6),d0-d7
        movem.l d0-d7,editor_native_palette-DISPLAY_BASE(a5)
        movem.l saved_fade-DISPLAY_SLOTS(a6),d0-d3
        movem.l d0-d3,editor_fade_state-DISPLAY_BASE(a5)
        move.w saved_active-DISPLAY_SLOTS(a6),native_gameplay_active-DISPLAY_BASE(a5)
        rts

        even
copper_template:
        dc.w $f001,$fffe
        dc.w $0102,0,$0108,0,$010a,0
        dc.w $00e0,BAR_BITMAP>>16,$00e2,BAR_BITMAP&$ffff
        dc.w $00e4,(BAR_BITMAP+BAR_PLANE)>>16,$00e6,(BAR_BITMAP+BAR_PLANE)&$ffff
        dc.w $00e8,(BAR_BITMAP+BAR_PLANE*2)>>16,$00ea,(BAR_BITMAP+BAR_PLANE*2)&$ffff
        dc.w $00ec,(BAR_BITMAP+BAR_PLANE*3)>>16,$00ee,(BAR_BITMAP+BAR_PLANE*3)&$ffff
        ; Bar rows 0..31: the fixed UI palette of the buttons.
        dc.w $0180,$000,$0182,$223,$0184,$345,$0186,$468
        dc.w $0188,$9ab,$018a,$012,$018c,$dde,$018e,$889
        dc.w $0190,$fc3,$0192,$36a,$0194,$e55,$0196,$5c6
        dc.w $0198,$eb4,$019a,$000,$019c,$000,$019e,$fff
        ; Bar row 31 (line 271) is blank; rows 32..47 use the terrain palette.
        dc.w $ffdf,$fffe
        dc.w $0f01,$fffe
toolbar_palette:
        dc.w $0180,0,$0182,0,$0184,0,$0186,0
        dc.w $0188,0,$018a,0,$018c,0,$018e,0
        dc.w $0190,0,$0192,0,$0194,0,$0196,0
        dc.w $0198,0,$019a,0,$019c,0,$019e,0
        dc.w $ffff,$fffe
copper_end:
; The hill's colors for the attached pointer sprite: a yellow arrow with a
; dark outline, visible over every terrain.
pointer_palette:
        dc.w $0243,$0dcd,$0aa9,$0776,$0554,$0332,$0540,$0e80
        dc.w $0705,$0b40,$0a07,$0504,$0ec0,$0970,$0660,$0111
        even
        ifgt copper_end-copper_template-(EMPTY_SPRITE-BAR_COPPER)
        fail "Tool bar copper overlaps the empty sprite"
        endif
