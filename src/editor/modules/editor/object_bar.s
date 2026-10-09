; Cannon Fodder In-Game Level Editor V1.1
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
; phase and unsaved state, or the SAVED notice. Delete needs a selection.
; Preserves all registers.
bar_compose:
        movem.l d0-d1/a0-a1,-(sp)
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
        cmpi.w #-1,TERRAIN_CURSOR_X
        bne.s .name
        lea bar_saved_text(pc),a1
        bsr bar_append
        bra.s .done
.name:
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
        bsr bar_append_phase
.done:
        clr.b (a0)
        movem.l (sp)+,d0-d1/a0-a1
        rts

bar_band_extra:
        rts

object_id_text: dc.b " (ID ",0
object_hex_digits: dc.b "0123456789ABCDEF"
        even
        include "object_names.i"
terrain_finish:
