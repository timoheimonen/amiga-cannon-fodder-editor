; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Labels of the recruitment hill's EDITOR and CUSTOM disks (backend operation
; HILL_OPERATION, see ui.i). The hill has just drawn both disks into its draw
; buffer; the rows below them are cleared and the labels written in the
; small font, in the hill's label colour 6 over the shadow colour 8, like the
; LOAD and SAVE labels. D0=0; other registers preserved.
hill_service:
        movem.l d1/a0-a1,-(sp)
        bsr dialog_blitter_idle
        lea hill_target(pc),a1
        move.l display_draw_buffer,(a1)
        move.l #$2828,4(a1)
        lea hill_roles(pc),a0
        move.l a0,8(a1)
        lea hill_labels(pc),a0
        moveq #0,d1
        bsr ui_service
        movem.l (sp)+,d1/a0-a1
        moveq #0,d0
        rts

hill_target:        dc.l 0,0,0
; UI_BG black, UI_INK the label colour, UI_DIM its shadow.
hill_roles:         dc.b 0,0,0,0,0,0,6,8,6,6,6,6,6,6,6,6
HILL_EDITOR_LABEL   equ HILL_EDITOR_X+8-HILL_LABEL_WIDTH/2
HILL_CUSTOM_LABEL   equ HILL_CUSTOM_X+8-HILL_LABEL_WIDTH/2
hill_labels:
        dc.w UI_RECT,HILL_EDITOR_LABEL-4,15,HILL_LABEL_WIDTH+8,10,UI_BG
        dc.w UI_RECT,HILL_CUSTOM_LABEL-4,15,HILL_LABEL_WIDTH+8,10,UI_BG
        dc.w UI_TEXT,HILL_EDITOR_LABEL+1,17,HILL_LABEL_WIDTH,UI_DIM,UI_CENTER
        dc.b "EDITOR",0
        even
        dc.w UI_TEXT,HILL_EDITOR_LABEL,16,HILL_LABEL_WIDTH,UI_INK,UI_CENTER
        dc.b "EDITOR",0
        even
        dc.w UI_TEXT,HILL_CUSTOM_LABEL+1,17,HILL_LABEL_WIDTH,UI_DIM,UI_CENTER
        dc.b "CUSTOM",0
        even
        dc.w UI_TEXT,HILL_CUSTOM_LABEL,16,HILL_LABEL_WIDTH,UI_INK,UI_CENTER
        dc.b "CUSTOM",0
        even
        dc.w UI_END
