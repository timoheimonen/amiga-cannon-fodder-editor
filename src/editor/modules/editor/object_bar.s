; Cannon Fodder In-Game Level Editor V1.2.6
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Object view uses the shared toolbar compositor and stopped display owners.
; UI0..79 is toolbar scratch; object input additionally owns UI80..87.
        xdef terrain_input,terrain_end,terrain_start,terrain_finish
terrain_start:
terrain_input:
        bra object_input
terrain_end:
        moveq #0,d0
        rts
terrain_objects:
        bra op_draw_placed

BAR_OBJECT_MODE equ 1
        include "bar.s"

; Object bar texts: the cell readout, the selected type with its ID, the
; phase and unsaved state, or the SAVED notice. While the pointer is on the
; bar, the phase's object counts replace the type. Delete needs a selection.
; Preserves all registers.
bar_compose:
        movem.l d0-d2/a0-a1,-(sp)
        bsr bar_compose_xy
        tst.w AUR_BASE+AUR_UNDO_COUNT
        bne.s .undo
        moveq #BAR_UNDO,d0
        moveq #UI_DISABLED,d1
        bsr bar_set_state
.undo:
        cmpi.w #-1,AUR_BASE+AUR_OBJECT_INDEX
        bne.s .selected
        moveq #BAR_SECOND,d0
        moveq #UI_DISABLED,d1
        bsr bar_set_state
.selected:
        lea BAR_INFO_TEXT,a0
        tst.w TERRAIN_BLOCK_NOTICE
        beq.s .saved_check
        lea object_move_refused_text(pc),a1
        bsr bar_append
        bra .done
.saved_check:
        cmpi.w #-1,TERRAIN_CURSOR_X
        bne.s .name
        lea bar_saved_text(pc),a1
        bsr bar_append
        bra .done
.name:
        btst #0,TERRAIN_ON_BAR
        beq.s .type
        bsr object_counts
        move.w d2,-(sp)
        move.w d1,-(sp)
        lea object_parts_text(pc),a1
        bsr bar_append
        bsr bar_number
        lea object_units_text(pc),a1
        bsr bar_append
        move.w (sp)+,d0
        bsr bar_number
        lea object_squad_text(pc),a1
        bsr bar_append
        move.w (sp)+,d0
        bsr bar_number
        lea object_squad_limit(pc),a1
        bsr bar_append
        bsr bar_append_unsaved
        bra.s .done
.type:
        move.w AUR_BASE+AUR_OBJECT_TYPE,d0
        add.w d0,d0
        lea object_name_offsets(pc),a1
        adda.w 0(a1,d0.w),a1
.copy:
        move.b (a1)+,d0
        bmi.s .named
        move.b d0,(a0)+
        bra.s .copy
.named:
        lea object_id_text(pc),a1
        bsr bar_append
        move.w AUR_BASE+AUR_OBJECT_TYPE,d0
        lea object_hex_digits(pc),a1
        move.w d0,d1
        lsr.w #4,d1
        andi.w #15,d1
        move.b 0(a1,d1.w),(a0)+
        andi.w #15,d0
        move.b 0(a1,d0.w),(a0)+
        move.b #')',(a0)+
        tst.w AUR_BASE+AUR_OBJECT_INDEX
        bmi.s .append_phase
        bsr.s object_ordinal
        tst.w d0
        beq.s .append_phase
        move.w d1,-(sp)
        move.b #' ',(a0)+
        bsr bar_number
        move.b #'/',(a0)+
        move.w (sp)+,d0
        bsr bar_number
.append_phase:
        bsr bar_append_phase
.done:
        clr.b (a0)
        movem.l (sp)+,d0-d2/a0-a1
        rts

; 1-based ordinal D0.w of AUR_OBJECT_INDEX among the D1.w selectable roots
; in EDITOR_SPT_BASE (D0=0 if not found). Preserves A0/A1/D2-D7.
object_ordinal:
        movem.l d2-d6/a2-a3,-(sp)
        moveq #0,d6
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d6
        divu #10,d6
        move.w AUR_BASE+AUR_OBJECT_INDEX,d5
        moveq #0,d0
        moveq #0,d1
        moveq #0,d2
        lea EDITOR_SPT_BASE,a2
.scan:
        cmp.w d6,d2
        bhs.s .end
        move.w 8(a2),d3
        move.w d3,d4
        add.w d4,d4
        lea op_part_index(pc),a3
        tst.w 0(a3,d4.w)
        beq.s .next
        cmpi.w #$7FEF,4(a2)
        bhi.s .next
        tst.w 6(a2)
        bmi.s .next
        addq.w #1,d1
        cmp.w d5,d2
        bne.s .next
        move.w d1,d0
.next:
        lsl.w #2,d3
        lea ot_shared_recipes(pc),a3
        move.b 0(a3,d3.w),d3
        andi.w #3,d3
        addq.w #1,d3
        add.w d3,d2
        mulu #10,d3
        adda.w d3,a2
        bra.s .scan
.end:
        movem.l (sp)+,d2-d6/a2-a3
        rts

; What the phase's objects use of its three limits. D0.w = parts (of 43),
; D1.w = the parts up to the last person or vehicle (of 30), D2.w = the
; squad's soldiers (of 8). Preserves other registers.
object_counts:
        movem.l d3-d5/a0-a1,-(sp)
        lea EDITOR_SPT_BASE,a0
        moveq #0,d0
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d0
        divu #10,d0
        moveq #0,d1
        moveq #0,d2
        moveq #0,d3
.object:
        cmp.w d0,d3
        bhs.s .counted
        move.w 8(a0),d4
        bne.s .typed
        cmpi.w #-16,4(a0)
        blt.s .typed
        addq.w #1,d2
.typed:
        ; One object is its own part and up to three companion parts.
        lsl.w #2,d4
        lea ot_shared_recipes(pc),a1
        move.b 0(a1,d4.w),d5
        moveq #3,d4
        and.w d5,d4
        addq.w #1,d4
        add.w d4,d3
        mulu #10,d4
        adda.w d4,a0
        tst.b d5
        bpl.s .object
        move.w d3,d1
        bra.s .object
.counted:
        movem.l (sp)+,d3-d5/a0-a1
        rts

bar_band_extra:
        rts

object_parts_text: dc.b "Parts ",0
object_units_text: dc.b "/43  Units ",0
object_squad_text: dc.b "/30  Squad ",0
object_squad_limit: dc.b "/8",0
object_move_refused_text: dc.b "Move refused: part would leave the map.",0
object_id_text: dc.b " (ID ",0
object_hex_digits: dc.b "0123456789ABCDEF"
        even
        include "object_names.i"
terrain_finish:
