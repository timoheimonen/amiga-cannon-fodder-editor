; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; D0.w type; A0 writable 32-byte part output; A1 trusted 232-entry sprite table.
; Return D0.l part count (0 for an invisible anchor), or -1 for unsupported type.
; Each output record is descriptor.l, dx.w, dy.w. Preserve all other registers.
; Selection/admission, descriptor ownership and SPT bundle validation are callers.
        ifnd OBJECT_PARTS_DATA_ONLY
op_parts:
        movem.l d1-d4/a0-a3,-(sp)
        cmpi.w #$18,d0
        bne.s .ordinary
        move.l #OBJECT_ANCHOR_DESC,(a0)
        clr.l 4(a0)
        moveq #1,d0
        bra.s .done
.ordinary:
        cmp.w #110,d0
        bhi.s .reject
        add.w d0,d0
        lea op_part_index(pc),a2
        move.w 0(a2,d0.w),d1
        beq.s .reject
        adda.w d1,a2
        moveq #0,d0
        move.w (a2)+,d0
        beq.s .done
        move.w d0,d4
        subq.w #1,d4
.part:
        moveq #0,d1
        move.b (a2)+,d1
        lsl.w #2,d1
        movea.l 0(a1,d1.w),a3
        moveq #0,d1
        move.b (a2)+,d1
        lsl.w #4,d1
        adda.w d1,a3
        move.l a3,(a0)+
        move.b (a2)+,d2
        ext.w d2
        move.w d2,(a0)+
        move.b (a2)+,d3
        ext.w d3
        move.w d3,(a0)+
        addq.l #2,a2
        dbra d4,.part
        bra.s .done
.reject:
        moveq #-1,d0
.done:
        movem.l (sp)+,d1-d4/a0-a3
        rts
        endif
op_part_index:
        dc.w op_recipe_0-op_part_index
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w op_recipe_1-op_part_index
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w op_recipe_2-op_part_index
        dc.w op_recipe_3-op_part_index
        dc.w op_recipe_4-op_part_index
        dc.w op_recipe_5-op_part_index
        dc.w op_recipe_6-op_part_index
        dc.w op_recipe_7-op_part_index
        dc.w 0
        dc.w op_recipe_8-op_part_index
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w op_recipe_9-op_part_index
        dc.w op_recipe_10-op_part_index
        dc.w 0
        dc.w op_recipe_11-op_part_index
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w op_recipe_12-op_part_index
        dc.w op_recipe_13-op_part_index
        dc.w op_recipe_14-op_part_index
        dc.w 0
        dc.w op_recipe_15-op_part_index
        dc.w 0
        dc.w op_recipe_15-op_part_index
        dc.w op_recipe_15-op_part_index
        dc.w op_recipe_15-op_part_index
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w op_recipe_16-op_part_index
        dc.w op_recipe_16-op_part_index
        dc.w op_recipe_16-op_part_index
        dc.w op_recipe_16-op_part_index
        dc.w 0
        dc.w op_recipe_17-op_part_index
        dc.w op_recipe_18-op_part_index
        dc.w op_recipe_19-op_part_index
        dc.w 0
        dc.w 0
        dc.w 0
        dc.w op_recipe_20-op_part_index
        dc.w op_recipe_21-op_part_index
        dc.w op_recipe_21-op_part_index
        dc.w op_recipe_22-op_part_index
        dc.w op_recipe_22-op_part_index
        dc.w op_recipe_23-op_part_index
        dc.w op_recipe_24-op_part_index
        dc.w op_recipe_25-op_part_index
        dc.w op_recipe_26-op_part_index
        dc.w op_recipe_27-op_part_index
        dc.w op_recipe_21-op_part_index
        dc.w 0
        dc.w op_recipe_28-op_part_index
        dc.w op_recipe_29-op_part_index
        dc.w op_recipe_10-op_part_index
        dc.w op_recipe_10-op_part_index
        dc.w op_recipe_10-op_part_index
        dc.w 0
        dc.w op_recipe_30-op_part_index
        dc.w op_recipe_30-op_part_index
        dc.w op_recipe_31-op_part_index
        dc.w op_recipe_31-op_part_index
        dc.w op_recipe_31-op_part_index
        dc.w op_recipe_21-op_part_index
        dc.w op_recipe_32-op_part_index
        dc.w op_recipe_32-op_part_index
        dc.w 0
        dc.w 0
        dc.w op_recipe_33-op_part_index
        dc.w 0
        dc.w op_recipe_10-op_part_index
        dc.w op_recipe_26-op_part_index
        dc.w op_recipe_34-op_part_index
        dc.w op_recipe_35-op_part_index
        dc.w op_recipe_36-op_part_index
        dc.w op_recipe_37-op_part_index
        dc.w op_recipe_38-op_part_index
        dc.w 0
        dc.w op_recipe_39-op_part_index
        dc.w op_recipe_40-op_part_index
        dc.w op_recipe_33-op_part_index
        dc.w 0
        dc.w op_recipe_16-op_part_index
        dc.w op_recipe_16-op_part_index
        dc.w op_recipe_16-op_part_index
        dc.w op_recipe_32-op_part_index
        dc.w op_recipe_41-op_part_index
        dc.w op_recipe_15-op_part_index
        dc.w op_recipe_42-op_part_index
        dc.w op_recipe_42-op_part_index
        dc.w op_recipe_42-op_part_index
op_recipe_0:
        dc.w 1
        dc.b 3,0,0,0,0,0
op_recipe_1:
        dc.w 1
        dc.b 69,0,0,0,0,0
op_recipe_2:
        dc.w 1
        dc.b 143,0,0,0,0,0
op_recipe_3:
        dc.w 1
        dc.b 144,0,0,0,0,0
op_recipe_4:
        dc.w 1
        dc.b 145,0,0,0,0,0
op_recipe_5:
        dc.w 1
        dc.b 146,0,0,0,0,0
op_recipe_6:
        dc.w 1
        dc.b 147,0,0,0,0,0
op_recipe_7:
        dc.w 1
        dc.b 148,0,0,0,0,-1
op_recipe_8:
        dc.w 1
        dc.b 153,0,0,0,0,-1
op_recipe_9:
        ifd OBJECT_ANCHOR_ENABLED
        dc.w 1
        dc.b 0,0,0,0,0,0
        else
        dc.w 0
        endif
op_recipe_10:
        dc.w 1
        dc.b 155,0,0,0,0,-1
op_recipe_11:
        dc.w 1
        dc.b 158,0,0,0,0,0
op_recipe_12:
        dc.w 1
        dc.b 171,2,0,0,0,0
op_recipe_13:
        dc.w 1
        dc.b 194,0,0,0,0,0
op_recipe_14:
        dc.w 1
        dc.b 195,0,0,0,0,0
op_recipe_15:
        dc.w 4
        dc.b 141,0,9,-1,-1,-1
        dc.b 139,0,0,0,0,0
        dc.b 140,0,0,-13,1,0
        dc.b 196,0,14,-16,8,0
op_recipe_16:
        dc.w 3
        dc.b 141,0,9,-1,-1,-1
        dc.b 139,0,0,0,0,0
        dc.b 140,0,0,-13,1,0
op_recipe_17:
        dc.w 1
        dc.b 199,0,0,0,0,-1
op_recipe_18:
        dc.w 1
        dc.b 200,0,0,0,0,-1
op_recipe_19:
        dc.w 1
        dc.b 201,0,0,0,0,0
op_recipe_20:
        dc.w 2
        dc.b 205,0,0,0,0,0
        dc.b 206,0,0,-16,0,0
op_recipe_21:
        dc.w 1
        dc.b 208,0,0,0,0,0
op_recipe_22:
        dc.w 2
        dc.b 141,0,9,-1,-1,0
        dc.b 165,0,0,0,0,0
op_recipe_23:
        dc.w 2
        dc.b 209,0,0,0,0,0
        dc.b 210,0,10,-8,1,0
op_recipe_24:
        dc.w 1
        dc.b 211,0,0,0,0,1
op_recipe_25:
        dc.w 1
        dc.b 212,0,0,0,0,1
op_recipe_26:
        dc.w 1
        dc.b 213,0,0,0,0,0
op_recipe_27:
        dc.w 3
        dc.b 209,0,0,0,0,0
        dc.b 210,0,10,-8,1,0
        dc.b 196,0,15,-22,2,0
op_recipe_28:
        dc.w 1
        dc.b 217,0,0,0,0,0
op_recipe_29:
        dc.w 1
        dc.b 221,0,0,0,0,0
op_recipe_30:
        dc.w 1
        dc.b 210,0,0,0,0,0
op_recipe_31:
        dc.w 3
        dc.b 141,0,9,-1,-1,0
        dc.b 165,0,0,0,0,0
        dc.b 196,0,13,-19,5,0
op_recipe_32:
        dc.w 2
        dc.b 210,0,0,0,0,0
        dc.b 196,0,5,-15,9,0
op_recipe_33:
        dc.w 1
        dc.b 224,0,0,0,0,-1
op_recipe_34:
        dc.w 1
        dc.b 226,0,0,0,0,0
op_recipe_35:
        dc.w 1
        dc.b 149,15,0,0,0,0
op_recipe_36:
        dc.w 1
        dc.b 228,0,0,0,0,0
op_recipe_37:
        dc.w 1
        dc.b 227,0,0,0,0,0
op_recipe_38:
        dc.w 1
        dc.b 229,0,0,0,0,0
op_recipe_39:
        dc.w 1
        dc.b 230,0,0,0,0,0
op_recipe_40:
        dc.w 1
        dc.b 231,0,0,0,0,-1
op_recipe_41:
        dc.w 2
        dc.b 216,0,0,0,0,0
        dc.b 196,0,6,-11,13,0
op_recipe_42:
        dc.w 1
        dc.b 147,0,0,-1,0,0
