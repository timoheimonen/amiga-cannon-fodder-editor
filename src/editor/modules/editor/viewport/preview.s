; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Drag preview: an object, or a logical item made of several sprite parts
; (for example a building with its companions), follows the pointer over the
; static editor viewport. Each part is drawn with the native four-plane
; masked blitter:
;
; - the opacity mask of a source word is the OR of its four planes (colour 0
;   is transparent, as when the game generates its masks) and is built once
;   per part in caller-owned Chip scratch (pv_mask_row);
; - with pv_native_masks set, fully visible parts reuse the installed native
;   mask bank, which the caller must keep owned until the preview is restored;
; - masks are clipped per word against the clip rectangle and rows against
;   its top and bottom;
; - everything under the preview is saved before the first part is drawn and
;   restored before anything else is drawn into the buffer.
;
; The display buffer is the game's scrolling ring: four planes of DISPLAY_PLANE
; bytes, each a linear ring of RING_BYTES (256 rows of 40 bytes) followed by a
; guard row. Logical viewport pixel (x, y) is ring pixel ring_x + x of ring row
; ring_y + y; because the ring is linear, crossing column 320 continues on the
; next row and crossing RING_BYTES wraps to offset 0. A blit that crosses the
; end of the ring is split there.
;
; Frame order expected from the caller (the editor's frame hook):
;
;   1. If anything under the preview will be drawn this frame (scrolling edge
;      tiles, painted tiles, placed or removed objects), call preview_restore
;      first.
;   2. Do that drawing.
;   3. Call preview_update with the item's world anchor. It redraws only when
;      the anchor or the camera changed, or after a restore.
;
; The preview is drawn into one display buffer. A double-buffered view needs
; one save area per buffer.
;
; A4 is the editor module state (PV_STATE_SIZE bytes, see below). All routines
; preserve every register they do not return.

; Reference game graphics state; the caller includes fodders.i.
CAMERA_X        equ camera_world_x ; 16.16, integer in the high word
CAMERA_Y        equ camera_world_y
RING_X          equ display_ring_x ; 16.16 physical ring X, wraps at 320
RING_Y          equ display_ring_y ; 16.16 physical ring Y, wraps at 256
DRAW_BUFFER     equ display_draw_buffer ; long: plane 0 of the draw buffer

; Display ring geometry.
DISPLAY_PLANE   equ $2828       ; bytes per display plane (ring + guard row)
RING_BYTES      equ $2800       ; 256 rows of 40 bytes
ROW_BYTES       equ 40

; Editor viewport, logical pixels. The canvas leaves a hidden right margin.
; Byte-granular clipping may touch up to seven
; pixels beyond either side of the viewport; on the linear ring these are the
; hidden pixels VIEW_W..319 of a neighbouring row, so VIEW_W may not exceed 312.
VIEW_W          equ 304
VIEW_ROWS       equ 192
        if VIEW_W>312
        fail "VIEW_W leaves no hidden margin for byte clipping"
        endif
        if VIEW_ROWS>256
        fail "VIEW_ROWS exceeds the ring"
        endif

; Sprite descriptor (16 bytes per frame).
DESC_SOURCE     equ $00         ; long: top-left source byte in plane 0
DESC_MASK       equ $04         ; packed native opacity mask, when installed
DESC_WORDS      equ $08         ; width in words, including one guard word
DESC_ROWS       equ $0a         ; height in rows
DESC_PLANE      equ $0c         ; source plane stride
DESC_ANCHOR_X   equ $0e         ; signed byte
DESC_ANCHOR_Y   equ $0f         ; signed byte

; Preview limits. SAVE_BYTES must hold the worst case of the largest item
; offered by the object page (checked by preview_set_item).
PV_MAX_PARTS    equ 8
SAVE_BYTES      equ 3072

; One part of the previewed item.
                rsreset
part_desc       rs.l 1          ; sprite descriptor
part_dx         rs.w 1          ; world offset from the item's anchor
part_dy         rs.w 1
PART_SIZE       rs.b 0

; Preview state inside the module state at A4.
                rsreset
pv_parts        rs.b PART_SIZE*PV_MAX_PARTS
pv_count        rs.w 1          ; parts of the current item, 0 = no preview
pv_drawn        rs.b 1          ; the save area holds what is under the preview
pv_pad          rs.b 1          ; nonzero stamps permanent placed sprites
pv_last_x       rs.w 1          ; anchor and camera of the drawn preview
pv_last_y       rs.w 1
pv_last_cx      rs.w 1
pv_last_cy      rs.w 1
pv_view_base    rs.w 1          ; ring byte of logical pixel (0, 0)
pv_sub          rs.w 1          ; bit position of that pixel in its byte
pv_vc_last      rs.w 1          ; last viewport byte column
pv_buffer       rs.l 1          ; display buffer the save area belongs to
pv_save_end     rs.l 1          ; end of the used save area
pv_mask_row     rs.l 1          ; caller-owned Chip RAM, SAVE_BYTES/2
pv_native_masks rs.w 1          ; caller guarantees the gameplay mask bank
pv_blit_mask    rs.l 1
pv_blit_src     rs.l 1
pv_blit_stride  rs.w 1
pv_blit_words   rs.w 1
pv_blit_left    rs.w 1
pv_blit_top     rs.w 1
pv_blit_rows    rs.w 1
pv_blit_shift   rs.w 1
pv_blit_dest    rs.w 1
pv_fast_rows    rs.w 1
pv_fast_dest    rs.w 1
pv_fast_source  rs.l 1
pv_fast_mask    rs.l 1
pv_fast_left    rs.w 1
pv_fast_chunk   rs.w 1
pv_fast_guard   rs.w 1
pv_clip_left    rs.w 1          ; permanent stamp rectangle; preview resets full
pv_clip_top     rs.w 1
pv_clip_right   rs.w 1
pv_clip_bottom  rs.w 1
pv_save         rs.b SAVE_BYTES
PV_STATE_SIZE   rs.b 0

; Set the previewed item. A0: PART_SIZE records, D0.w: their number.
; Removes the old preview from the screen. Returns D0.l = 0, or -1 when the
; item has no parts, too many parts, an empty frame or does not fit the save
; area in the worst case; the editor then shows no preview (for example only
; the pointer and an outline).
preview_set_item:
        movem.l d1-d4/a0-a2,-(sp)
        bsr preview_restore             ; the old item leaves the screen
        clr.w pv_count(a4)
        tst.w d0
        beq.s .reject
        cmp.w #PV_MAX_PARTS,d0
        bhi.s .reject
        moveq #0,d3                     ; worst-case save bytes
        lea pv_parts(a4),a2
        move.w d0,d4
        subq.w #1,d4
.part:  movea.l part_desc(a0),a1
        move.w DESC_ROWS(a1),d2
        beq.s .reject
        move.w DESC_WORDS(a1),d1
        subq.w #1,d1                    ; without the guard word
        ble.s .reject
        add.w d1,d1                     ; source bytes per row
        addq.w #1,d1                    ; destination bytes after shifting
        lsl.w #2,d1                     ; four planes
        addq.w #4,d1                    ; record header
        mulu d2,d1                      ; per part
        add.l d1,d3
        move.l (a0)+,(a2)+              ; descriptor
        move.l (a0)+,(a2)+              ; dx, dy
        dbra d4,.part
        cmp.l #SAVE_BYTES,d3
        bhi.s .reject
        move.w d0,pv_count(a4)
        moveq #0,d0
        bra.s .done
.reject:
        clr.w pv_count(a4)
        moveq #-1,d0
.done:  movem.l (sp)+,d1-d4/a0-a2
        rts

; Per frame. D0.w/D1.w: world anchor of the item (pointer minus the grab
; offset while dragging). Draws only when something visible changed.
preview_update:
        movem.l d2,-(sp)
        tst.b pv_pad(a4)
        bne.s .clip_ready
        clr.l pv_clip_left(a4)
        move.l #$013000c0,pv_clip_right(a4)
.clip_ready:
        tst.w pv_count(a4)
        beq.s .done
        tst.b pv_drawn(a4)
        beq.s .redraw                   ; restored this frame, or never drawn
        cmp.w pv_last_x(a4),d0
        bne.s .redraw
        cmp.w pv_last_y(a4),d1
        bne.s .redraw
        move.w (CAMERA_X).l,d2
        cmp.w pv_last_cx(a4),d2
        bne.s .redraw
        move.w (CAMERA_Y).l,d2
        cmp.w pv_last_cy(a4),d2
        beq.s .done                     ; nothing moved: no work, no flicker
.redraw:
        bsr.s preview_restore
        bsr preview_draw
.done:  movem.l (sp)+,d2
        rts

; Put back everything the preview covered. Safe to call when nothing is drawn.
preview_restore:
        movem.l d0-d1/a0-a3,-(sp)
        tst.b pv_drawn(a4)
        beq.s .done
        clr.b pv_drawn(a4)
        movea.l pv_buffer(a4),a0
        lea pv_save(a4),a1
        movea.l pv_save_end(a4),a2
.record:
        cmpa.l a2,a1
        bhs.s .done
        move.w (a1)+,d0                 ; ring byte offset
        move.w (a1)+,d1                 ; bytes - 1
        addq.w #1,d1
.copy:  lea 0(a0,d0.w),a3
        btst #0,d0
        bne.s .byte
        ifd AUR_OBJECT_VIEW
        cmp.w #4,d1
        blo.s .word
        cmp.w #RING_BYTES-4,d0
        bhi.s .word
        move.l (a1)+,(a3)
        move.l (a1)+,DISPLAY_PLANE(a3)
        move.l (a1)+,DISPLAY_PLANE*2(a3)
        move.l (a1)+,DISPLAY_PLANE*3(a3)
        addq.w #4,d0
        subq.w #4,d1
        bra.s .next
.word:
        endif
        cmp.w #2,d1
        blo.s .byte
        move.w (a1)+,(a3)
        move.w (a1)+,DISPLAY_PLANE(a3)
        move.w (a1)+,DISPLAY_PLANE*2(a3)
        move.w (a1)+,DISPLAY_PLANE*3(a3)
        addq.w #2,d0
        subq.w #2,d1
        bra.s .next
.byte:
        move.b (a1)+,(a3)
        move.b (a1)+,DISPLAY_PLANE(a3)
        move.b (a1)+,DISPLAY_PLANE*2(a3)
        move.b (a1)+,DISPLAY_PLANE*3(a3)
        addq.w #1,d0
        subq.w #1,d1
.next:
        cmp.w #RING_BYTES,d0
        bne.s .same_ring
        moveq #0,d0                     ; wrapped to the start of the ring
.same_ring:
        tst.w d1
        bne.s .copy
        bra.s .record
.done:  movem.l (sp)+,d0-d1/a0-a3
        rts

; Save under all parts, then draw all parts. Saving everything first means
; every saved byte is original screen content, even where parts overlap, so
; the restore order does not matter.
preview_draw:
        movem.l d2-d7/a1-a2,-(sp)
        move.w d0,pv_last_x(a4)
        move.w d1,pv_last_y(a4)
        move.w (CAMERA_X).l,pv_last_cx(a4)
        move.w (CAMERA_Y).l,pv_last_cy(a4)
        move.w (RING_Y).l,d2            ; viewport geometry of this frame
        mulu #ROW_BYTES,d2
        move.w (RING_X).l,d3
        moveq #7,d4
        and.w d3,d4
        lsr.w #3,d3
        add.w d3,d2
        move.w d2,pv_view_base(a4)
        move.w d4,pv_sub(a4)
        add.w #VIEW_W-1,d4
        lsr.w #3,d4
        move.w d4,pv_vc_last(a4)
        move.l (DRAW_BUFFER).l,pv_buffer(a4)
        tst.b pv_pad(a4)
        bne.s .composite
        lea pv_save(a4),a1
        lea pv_parts(a4),a2
        move.w pv_count(a4),d7
        subq.w #1,d7
.save:  bsr save_part
        addq.l #PART_SIZE,a2
        dbra d7,.save
        move.l a1,pv_save_end(a4)
        st pv_drawn(a4)
.composite:
        lea pv_parts(a4),a2
        move.w pv_count(a4),d7
        subq.w #1,d7
.draw:  bsr blit_part
        addq.l #PART_SIZE,a2
        dbra d7,.draw
        movem.l (sp)+,d2-d7/a1-a2
        rts

; A2: part, D0.w/D1.w: item anchor. Return A3 = descriptor, D2.w = logical
; left X and D3.w = logical top row of the part in the viewport, placed like
; the engine's world-object path with no height above ground. Uses D4.
part_origin:
        movea.l part_desc(a2),a3
        move.w d0,d2
        add.w part_dx(a2),d2
        move.b DESC_ANCHOR_X(a3),d4
        ext.w d4
        add.w d4,d2
        sub.w pv_last_cx(a4),d2
        move.w d1,d3
        add.w part_dy(a2),d3
        move.b DESC_ANCHOR_Y(a3),d4
        ext.w d4
        add.w d4,d3
        sub.w DESC_ROWS(a3),d3
        sub.w pv_last_cy(a4),d3
        rts

; Save the clipped destination bytes of one part. A2: part, D0/D1: anchor,
; A1: save area, advanced. Each visible row stores its ring offset, its byte
; count - 1 and four plane bytes per destination byte.
save_part:
        movem.l d0-d7/a0/a2-a3,-(sp)
        bsr.s part_origin
        add.w pv_sub(a4),d2
        asr.w #3,d2                     ; first destination column (floor)
        move.w DESC_WORDS(a3),d5
        subq.w #1,d5
        add.w d5,d5
        add.w d2,d5                     ; last destination column
        tst.w d2
        bpl.s .left_in
        moveq #0,d2
.left_in:
        cmp.w pv_vc_last(a4),d5
        ble.s .right_in
        move.w pv_vc_last(a4),d5
.right_in:
        sub.w d2,d5                     ; bytes - 1
        bmi .done                      ; outside the viewport columns
        movea.l pv_buffer(a4),a0
        move.w DESC_ROWS(a3),d6
        ifd AUR_OBJECT_VIEW
        ; Clip once. D4 advances with each copy; D2 skips the untouched
        ; remainder of the physical40-byte row after its visible segment.
        tst.w d3
        bpl.s .top_in
        add.w d3,d6
        moveq #0,d3
.top_in:
        cmp.w #VIEW_ROWS,d3
        bge .done
        move.w #VIEW_ROWS,d4
        sub.w d3,d4
        cmp.w d4,d6
        ble.s .bottom_in
        move.w d4,d6
.bottom_in:
        tst.w d6
        ble .done
        subq.w #1,d6
        move.w d3,d4
        mulu #ROW_BYTES,d4
        add.w pv_view_base(a4),d4
        add.w d2,d4
        cmp.w #RING_BYTES,d4
        blo.s .first_ring
        sub.w #RING_BYTES,d4
.first_ring:
        moveq #ROW_BYTES-1,d2
        sub.w d5,d2
.row:
        else
        subq.w #1,d6
.row:   cmp.w #VIEW_ROWS,d3
        bhs.s .next_row                 ; unsigned: rows above the view too
        move.w d3,d4
        mulu #ROW_BYTES,d4
        add.w pv_view_base(a4),d4
        add.w d2,d4
        cmp.w #RING_BYTES,d4
        blo.s .in_ring
        sub.w #RING_BYTES,d4
.in_ring:
        endif
        move.w d4,(a1)+
        move.w d5,(a1)+
        move.w d5,d7
        addq.w #1,d7
.copy:  lea 0(a0,d4.w),a2
        btst #0,d4
        bne.s .byte
        ifd AUR_OBJECT_VIEW
        cmp.w #4,d7
        blo.s .word
        cmp.w #RING_BYTES-4,d4
        bhi.s .word
        move.l (a2),(a1)+
        move.l DISPLAY_PLANE(a2),(a1)+
        move.l DISPLAY_PLANE*2(a2),(a1)+
        move.l DISPLAY_PLANE*3(a2),(a1)+
        addq.w #4,d4
        subq.w #4,d7
        bra.s .next
.word:
        endif
        cmp.w #2,d7
        blo.s .byte
        move.w (a2),(a1)+
        move.w DISPLAY_PLANE(a2),(a1)+
        move.w DISPLAY_PLANE*2(a2),(a1)+
        move.w DISPLAY_PLANE*3(a2),(a1)+
        addq.w #2,d4
        subq.w #2,d7
        bra.s .next
.byte:
        move.b (a2),(a1)+
        move.b DISPLAY_PLANE(a2),(a1)+
        move.b DISPLAY_PLANE*2(a2),(a1)+
        move.b DISPLAY_PLANE*3(a2),(a1)+
        addq.w #1,d4
        subq.w #1,d7
.next:
        cmp.w #RING_BYTES,d4
        bne.s .same_ring
        moveq #0,d4
.same_ring:
        tst.w d7
        bne.s .copy
.next_row:
        ifd AUR_OBJECT_VIEW
        add.w d2,d4
        cmp.w #RING_BYTES,d4
        blo.s .row_ready
        sub.w #RING_BYTES,d4
.row_ready:
        else
        addq.w #1,d3
        endif
        dbra d6,.row
.done:  movem.l (sp)+,d0-d7/a0/a2-a3
        rts

; Draw one part. A2: part, D0/D1: anchor. Clipped blits build masks without
; the shared native mask bank. The caller must select the native four-plane
; mode ($81E08=0) while this view is active.
blit_part:
        movem.l d0-d7/a0-a6,-(sp)
        bsr part_origin
        move.w d2,pv_blit_left(a4)
        move.w d3,pv_blit_top(a4)
        move.l DESC_SOURCE(a3),pv_blit_src(a4)
        move.l DESC_MASK(a3),pv_blit_mask(a4)
        move.w DESC_PLANE(a3),pv_blit_stride(a4)
        move.w DESC_WORDS(a3),pv_blit_words(a4)
        move.w DESC_ROWS(a3),pv_blit_rows(a4)
        cmp.w pv_clip_right(a4),d2
        bge.s .done
        move.w pv_blit_words(a4),d4
        subq.w #1,d4
        lsl.w #4,d4
        add.w d2,d4
        cmp.w pv_clip_left(a4),d4
        ble.s .done
        bsr.s try_block_blit
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Clip vertically, build packed masks once, and split tall blits at the ring
; boundary. Preserve each plane's guard row when a final shifted word wraps.
try_block_blit:
        move.w pv_blit_top(a4),d3
        move.w pv_blit_rows(a4),d4
        movea.l pv_blit_src(a4),a5
        movea.l pv_blit_mask(a4),a3
        move.w pv_clip_top(a4),d0
        sub.w d3,d0
        ble.s .top
        sub.w d0,d4
        move.w d0,d3
        mulu pv_blit_words(a4),d0
        add.l d0,d0
        adda.l d0,a3
        mulu #ROW_BYTES,d3
        adda.l d3,a5
        move.w pv_clip_top(a4),d3
.top:
        cmp.w pv_clip_bottom(a4),d3
        bge .empty
        move.w pv_clip_bottom(a4),d0
        sub.w d3,d0
        cmp.w d0,d4
        ble.s .bottom
        move.w d0,d4
.bottom:
        tst.w d4
        ble .empty
        move.w d4,pv_fast_rows(a4)
        move.w RING_Y,d0
        add.w d3,d0
        mulu #ROW_BYTES,d0
        move.w RING_X,d1
        add.w pv_blit_left(a4),d1
        move.w d1,d2
        and.w #15,d2
        move.w d2,pv_blit_shift(a4)
        asr.w #4,d1
        add.w d1,d1
        add.w d1,d0
        bpl.s .positive
        add.w #RING_BYTES,d0
.positive:
        cmp.w #RING_BYTES,d0
        blo.s .dest
        sub.w #RING_BYTES,d0
.dest:
        move.w d0,pv_fast_dest(a4)
        tst.w pv_native_masks(a4)
        beq.s .generate
        ifd OBJECT_ANCHOR_ENABLED
        ; The editor-only anchor has owned glyph pixels and no native mask.
        tst.l pv_blit_mask(a4)
        beq.s .generate
        endif
        move.w pv_blit_left(a4),d0
        cmp.w pv_clip_left(a4),d0
        blt.s .generate
        move.w pv_blit_words(a4),d1
        subq.w #1,d1
        lsl.w #4,d1
        add.w d0,d1
        cmp.w pv_clip_right(a4),d1
        bhi.s .generate
        move.l a3,pv_fast_mask(a4)
        bra .prepared
.generate:
        ifd AUR_OBJECT_VIEW
        tst.w pv_native_masks(a4)
        beq.s .source_generate
        tst.l pv_blit_mask(a4)
        beq.s .source_generate
        ; One clipping word row precedes the generated packed masks. Each
        ; accepted part has mask_rows*4 <= SAVE_BYTES, so one extra row fits
        ; the existing SAVE_BYTES/2 scratch even for a one-row descriptor.
        movea.l pv_mask_row(a4),a1
        move.w pv_blit_left(a4),d2
        move.w pv_blit_words(a4),d7
        subq.w #2,d7
.clip_word:
        moveq #-1,d0
        move.w d2,d4
        add.w #16,d4
        cmp.w pv_clip_left(a4),d4
        ble.s .clip_empty
        cmp.w pv_clip_right(a4),d2
        bge.s .clip_empty
        move.w pv_clip_left(a4),d4
        sub.w d2,d4
        ble.s .clip_left_done
        lsr.w d4,d0
.clip_left_done:
        move.w pv_clip_right(a4),d4
        sub.w d2,d4
        cmp.w #16,d4
        bge.s .clip_done
        moveq #-1,d1
        moveq #16,d5
        sub.w d4,d5
        lsl.w d5,d1
        and.w d1,d0
        bra.s .clip_done
.clip_empty:
        moveq #0,d0
.clip_done:
        move.w d0,(a1)+
        add.w #16,d2
        dbra d7,.clip_word
        clr.w (a1)+                    ; guard remains zero, even for native masks
        move.l a1,pv_fast_mask(a4)
        move.w pv_fast_rows(a4),d3
        subq.w #1,d3
.native_row:
        movea.l pv_mask_row(a4),a0
        move.w pv_blit_words(a4),d7
        subq.w #1,d7
.native_word:
        move.w (a3)+,d0
        and.w (a0)+,d0
        move.w d0,(a1)+
        dbra d7,.native_word
        dbra d3,.native_row
        bra .prepared
.source_generate:
        endif
        movea.l a5,a0
        movea.l pv_mask_row(a4),a1
        moveq #0,d6
        move.w pv_blit_stride(a4),d6
        move.w pv_fast_rows(a4),d3
        subq.w #1,d3
.row:
        move.w pv_blit_left(a4),d2
        move.w pv_blit_words(a4),d7
        subq.w #2,d7
.word:
        movea.l a0,a2
        move.w (a2),d0
        adda.l d6,a2
        or.w (a2),d0
        adda.l d6,a2
        or.w (a2),d0
        adda.l d6,a2
        or.w (a2),d0
        move.w d2,d4
        add.w #16,d4
        cmp.w pv_clip_left(a4),d4
        ble.s .mask_empty
        cmp.w pv_clip_right(a4),d2
        bge.s .mask_empty
        moveq #-1,d1
        move.w pv_clip_left(a4),d4
        sub.w d2,d4
        ble.s .clip_right
        lsr.w d4,d1
        and.w d1,d0
.clip_right:
        move.w pv_clip_right(a4),d4
        sub.w d2,d4
        cmp.w #16,d4
        bge.s .mask_done
        moveq #-1,d1
        moveq #16,d5
        sub.w d4,d5
        lsl.w d5,d1
        and.w d1,d0
        bra.s .mask_done
.mask_empty:
        moveq #0,d0
.mask_done:
        move.w d0,(a1)+
        addq.l #2,a0
        add.w #16,d2
        dbra d7,.word
        clr.w (a1)+
        moveq #ROW_BYTES+2,d0
        sub.w pv_blit_words(a4),d0
        sub.w pv_blit_words(a4),d0
        adda.w d0,a0
        dbra d3,.row
        move.l pv_mask_row(a4),pv_fast_mask(a4)
.prepared:
        move.l a5,pv_fast_source(a4)
        move.w pv_fast_rows(a4),pv_fast_left(a4)
.chunk:
        moveq #0,d0
        move.w #RING_BYTES-1,d0
        sub.w pv_fast_dest(a4),d0
        divu #ROW_BYTES,d0
        addq.w #1,d0
        cmp.w pv_fast_left(a4),d0
        bls.s .chunk_size
        move.w pv_fast_left(a4),d0
.chunk_size:
        move.w d0,pv_fast_chunk(a4)
        subq.w #1,d0
        mulu #ROW_BYTES,d0
        add.w pv_fast_dest(a4),d0
        add.w pv_blit_words(a4),d0
        add.w pv_blit_words(a4),d0
        clr.w pv_fast_guard(a4)
        cmp.w #RING_BYTES,d0
        bls.s .ready
        st pv_fast_guard(a4)
        lea -ROW_BYTES*4(sp),sp
        movea.l sp,a1
        movea.l pv_buffer(a4),a0
        moveq #3,d0
.seed_plane:
        movea.l a0,a2
        lea RING_BYTES(a0),a3
        moveq #ROW_BYTES-1,d1
.seed_byte:
        move.b (a3),(a1)+
        move.b (a2)+,(a3)+
        dbra d1,.seed_byte
        lea DISPLAY_PLANE(a0),a0
        dbra d0,.seed_plane
.ready:
        movea.l pv_fast_mask(a4),a0
        movea.l pv_fast_source(a4),a1
        movea.l pv_buffer(a4),a2
        adda.w pv_fast_dest(a4),a2
        movea.w pv_blit_stride(a4),a3
        move.w pv_fast_chunk(a4),d2
        lsl.w #6,d2
        or.w pv_blit_words(a4),d2
        moveq #ROW_BYTES,d3
        sub.w pv_blit_words(a4),d3
        sub.w pv_blit_words(a4),d3
        moveq #0,d6
        moveq #0,d7
        move.w pv_blit_shift(a4),d7
        jsr blit_masked_sprite_planes
        tst.w pv_fast_guard(a4)
        beq.s .advance
        movea.l sp,a1
        movea.l pv_buffer(a4),a0
        moveq #3,d0
.wrap_plane:
        movea.l a0,a2
        lea RING_BYTES(a0),a3
        moveq #ROW_BYTES-1,d1
.wrap_byte:
        move.b (a3),(a2)+
        move.b (a1)+,(a3)+
        dbra d1,.wrap_byte
        lea DISPLAY_PLANE(a0),a0
        dbra d0,.wrap_plane
        lea ROW_BYTES*4(sp),sp
.advance:
        move.w pv_fast_chunk(a4),d0
        sub.w d0,pv_fast_left(a4)
        beq.s .empty
        move.w d0,d1
        mulu pv_blit_words(a4),d1
        add.l d1,d1
        add.l d1,pv_fast_mask(a4)
        mulu #ROW_BYTES,d0
        add.l d0,pv_fast_source(a4)
        add.w d0,pv_fast_dest(a4)
        sub.w #RING_BYTES,pv_fast_dest(a4)
        bra .chunk
.empty:
        moveq #0,d0
        rts
