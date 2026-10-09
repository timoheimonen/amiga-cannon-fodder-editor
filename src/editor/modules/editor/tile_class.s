; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Terrain class names of the tiles, shared by the tool bar and the tile page.
; D0.w tile -> A1 its terrain class name. Preserves D0-D7/A0.
bar_class_name:
        move.l d0,-(sp)
        lea bar_class_unknown(pc),a1
        cmpi.w #400,d0
        bhs.s .return
        add.w d0,d0
        lea editor_hit_table,a1
        move.w 0(a1,d0.w),d0
        lea bar_class_mixed(pc),a1
        tst.w d0
        bmi.s .return
        andi.w #15,d0
        add.w d0,d0
        lea bar_class_offsets(pc),a1
        move.w 0(a1,d0.w),d0
        lea bar_class_names(pc),a1
        adda.w d0,a1
.return:
        move.l (sp)+,d0
        rts

bar_class_unknown: dc.b "?",0
bar_class_mixed: dc.b "Mixed",0
        even
bar_class_offsets:
        dc.w bar_class_0-bar_class_names,bar_class_1-bar_class_names,bar_class_2-bar_class_names
        dc.w bar_class_3-bar_class_names,bar_class_4-bar_class_names,bar_class_5-bar_class_names
        dc.w bar_class_6-bar_class_names,bar_class_7-bar_class_names,bar_class_8-bar_class_names
        dc.w bar_class_9-bar_class_names,bar_class_10-bar_class_names,bar_class_11-bar_class_names
        dc.w bar_class_12-bar_class_names,bar_class_13-bar_class_names,bar_class_14-bar_class_names
        dc.w bar_class_15-bar_class_names
bar_class_names:
bar_class_0: dc.b "Ground",0
bar_class_1: dc.b "Low rocks",0
bar_class_2: dc.b "High rocks",0
bar_class_3: dc.b "Blocked",0
bar_class_4: dc.b "Quicksand",0
bar_class_5: dc.b "Shallows",0
bar_class_6: dc.b "Water",0
bar_class_7: dc.b "Rough",0
bar_class_8: dc.b "Slippery",0
bar_class_9: dc.b "Drop",0
bar_class_10: dc.b "Pit",0
bar_class_11: dc.b "Sinking",0
bar_class_12: dc.b "Class 12",0
bar_class_13: dc.b "Slope",0
bar_class_14: dc.b "Ramp",0
bar_class_15: dc.b "Class 15",0
        even
