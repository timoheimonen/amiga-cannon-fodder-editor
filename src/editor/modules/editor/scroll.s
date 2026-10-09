; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Bounded viewport scrolling from translated input events.
        xdef terrain_scroll,terrain_scroll_end
; D2.w = the scroll zones under the pointer (bit 0 left, 1 right, 2 up,
; 3 down). Clobbers D0/D1.
scroll_zones:
        moveq #0,d2
        ; Screen X reaches 317, past the map's 304 pixels, so the right zone
        ; runs to the screen edge.
        move.w native_mouse_x,d0
        addi.w #16,d0
        move.w native_mouse_y,d1
        cmpi.w #UI_SCROLL_DOWN_Y,d1
        bhs.s .bottom
        cmpi.w #192,d1
        bhs.s .done
        cmpi.w #8,d0
        bhs.s .right
        bset #0,d2
.right:
        cmpi.w #296,d0
        blo.s .up
        bset #1,d2
.up:
        cmpi.w #8,d1
        bhs.s .down
        bset #2,d2
.down:
        ; While painting or dragging, the map's bottom rows scroll down too.
        tst.w native_left_down
        beq.s .done
        cmpi.w #184,d1
        bhs.s .scroll_down
        rts
.bottom:
        ; Not over the selected-tile image, which is clickable only here,
        ; nor within one tile right of it. The Object view has no image.
        ifnd AUR_OBJECT_VIEW
        cmpi.w #32,d0
        blo.s .done
        endif
.scroll_down:
        bset #3,d2
.done:
        rts

; Before a view takes input. The pointer scrolls only once it has been
; outside every zone, so a view opened with the pointer in one (a tile, row
; or button chosen at a screen edge) waits until it leaves. Preserves all.
terrain_scroll_enter:
        movem.l d0-d2,-(sp)
        clr.l TERRAIN_SCROLL_DIR
        bsr.s scroll_zones
        moveq #0,d0
        tst.w d2
        bne.s .zone
        moveq #1,d0
.zone:
        move.w d0,TERRAIN_SCROLL_ARMED
        movem.l (sp)+,d0-d2
        rts

; D0=0/-1. Preserve D1-D7/A0-A6; do not close or alter a paint group.
terrain_scroll:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #0,d2
        move.w native_raw_key,d0
        subi.w #$4C,d0
        cmpi.w #3,d0
        bhi.s .pointer
        lea .keys(pc),a0
        move.b 0(a0,d0.w),d2
        bra.s .direction
.pointer:
        bsr scroll_zones
        tst.w d2
        bne.s .zone
        move.w #1,TERRAIN_SCROLL_ARMED
.zone:
        tst.w TERRAIN_SCROLL_ARMED
        bne.s .direction
        moveq #0,d2
.direction:
        tst.w d2
        beq .clear
        cmp.w TERRAIN_SCROLL_DIR+PCREL(pc),d2
        bne.s .step
        subq.w #1,TERRAIN_SCROLL_REPEAT
        bpl .idle
.step:
        move.w d2,TERRAIN_SCROLL_DIR
        move.w #7,TERRAIN_SCROLL_REPEAT
        move.w view_origin_x+PCREL(pc),d0
        move.w view_origin_y+PCREL(pc),d1
        btst #0,d2
        beq.s .xplus
        subq.w #1,d0
.xplus:
        btst #1,d2
        beq.s .yminus
        addq.w #1,d0
.yminus:
        btst #2,d2
        beq.s .yplus
        subq.w #1,d1
.yplus:
        btst #3,d2
        beq.s .bounds
        addq.w #1,d1
.bounds:
        move.w editor_map_width,d6
        subi.w #19,d6
        bpl.s .width
        moveq #0,d6
.width:
        move.w editor_map_height,d7
        subi.w #12,d7
        bpl.s .height
        moveq #0,d7
.height:
        tst.w d0
        bpl.s .xmax
        moveq #0,d0
.xmax:
        cmp.w d6,d0
        bls.s .ymin
        move.w d6,d0
.ymin:
        tst.w d1
        bpl.s .ymax
        moveq #0,d1
.ymax:
        cmp.w d7,d1
        bls.s .changed
        move.w d7,d1
.changed:
        cmp.w view_origin_x+PCREL(pc),d0
        bne.s .publish
        cmp.w view_origin_y+PCREL(pc),d1
        beq.s .idle
.publish:
        bsr set_camera
        bne.s .return
        bsr scroll_view
        bsr terrain_objects
        ifd AUR_OBJECT_VIEW
        ori.w #4,TERRAIN_BAR_DIRTY
        else
        ori.w #1,TERRAIN_BAR_DIRTY
        endif
        bra.s .idle
.clear:
        clr.l TERRAIN_SCROLL_DIR
.idle:
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.keys:
        dc.b 4,8,2,1
        even
terrain_scroll_end:
