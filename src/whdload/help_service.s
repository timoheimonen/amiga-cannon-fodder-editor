; Cannon Fodder In-Game Level Editor V1.2.5
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Help pages of the dialog service (function DIALOG_HELP, see dialog.i). The
; pages are dialogs that the Slave holds itself, so their text takes no room
; in an editor module. Every page has the same band, so one page replaces
; another in place. A page's buttons return 0 to close and
; DIALOG_HELP_PAGE+n to show page n.
HELP_PAGES          equ 2
HELP_TOP            equ 8
HELP_HEIGHT         equ 216
HELP_BUTTONS        equ 2
; The first text row and the distance of the rows.
HELP_FIRST          equ 28
HELP_PITCH          equ 9
HELP_BUTTON_Y       equ 204

; D2.w=page. Opens it as DIALOG_OPEN opens a descriptor. D0.l=0 open, 10
; refused, also for a page that does not exist.
dialog_help:
        moveq #10,d0
        cmpi.w #HELP_PAGES,d2
        bhs.s .out
        ; The Slave has no relocations: a page keeps its addresses as
        ; offsets from its own start, made absolute in a copy.
        add.w d2,d2
        lea help_pages(pc),a1
        adda.w 0(a1,d2.w),a1
        move.l a1,d3
        lea help_descriptor(pc),a0
        movea.l a0,a2
        move.l (a1)+,(a2)+
        move.w (a1)+,(a2)+
        bsr.s .address
        bsr.s .address
        move.l (a1)+,(a2)+
        move.w (a1)+,(a2)+
        moveq #HELP_BUTTONS-1,d1
.button:
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        bsr.s .address
        dbra d1,.button
        moveq #0,d2
        bra dialog_open
.address:
        move.l (a1)+,d0
        add.l d3,d0
        move.l d0,(a2)+
.out:
        rts

; A key or a tool name in the left column, and a line of text beside it.
; \1 = row, \2 = text. The display shows 304 columns: a line beside a key
; has room for 35 characters and a line across both columns for 47.
HELP_KEY macro
        dc.w UI_TEXT,16,HELP_FIRST+(\1)*HELP_PITCH,66,UI_ACCENT,UI_LEFT
        dc.b \2,0
        even
        endm
HELP_LINE macro
        dc.w UI_TEXT,88,HELP_FIRST+(\1)*HELP_PITCH,224,UI_INK,UI_LEFT
        dc.b \2,0
        even
        endm
; A line across both columns.
HELP_WIDE macro
        dc.w UI_TEXT,16,HELP_FIRST+(\1)*HELP_PITCH,296,UI_INK,UI_LEFT
        dc.b \2,0
        even
        endm

help_pages:
        dc.w help_tools-help_pages,help_keys-help_pages

help_tools:
        dc.w HELP_TOP,HELP_HEIGHT,UI_SELECT
        dc.l help_tools_title-help_tools,help_tools_body-help_tools
        dc.w 1,0,HELP_BUTTONS
        dc.w 108,HELP_BUTTON_Y,94,14,DIALOG_HELP_PAGE+1,UI_NORMAL
        dc.l help_keys_label-help_tools
        dc.w 206,HELP_BUTTON_Y,94,14,0,UI_NORMAL
        dc.l help_close_label-help_tools
help_tools_body:
        HELP_KEY 0,"F1 Paint"
        HELP_LINE 0,"Left: paint; drag for a stroke"
        HELP_LINE 1,"Right: pick up the tile"
        HELP_LINE 2,"Shift + left drag: a rectangle"
        HELP_LINE 3,"Shift + right drag: copy an area;"
        HELP_LINE 4,"a left press then stamps the copy"
        HELP_LINE 5,"V: stamp the last copy again"
        HELP_KEY 7,"F2 Fill"
        HELP_LINE 7,"Left: fill an area of one tile"
        HELP_LINE 8,"Right: pick up the tile"
        HELP_KEY 10,"F3 Object"
        HELP_LINE 10,"Left: place, select or drag"
        HELP_LINE 11,"Right: pick up the type"
        HELP_LINE 12,"Del: delete the selected object"
        HELP_LINE 13,"Tab: select the next object"
        HELP_KEY 15,"F4 Marker"
        HELP_LINE 15,"Left: next class, 0 to 4"
        HELP_LINE 16,"Right: clear the marker"
        HELP_KEY 18,"F5 Inspect"
        HELP_LINE 18,"The terrain data of the cell"
        dc.w UI_END

help_keys:
        dc.w HELP_TOP,HELP_HEIGHT,UI_SELECT
        dc.l help_keys_title-help_keys,help_keys_body-help_keys
        dc.w 1,0,HELP_BUTTONS
        dc.w 108,HELP_BUTTON_Y,94,14,DIALOG_HELP_PAGE,UI_NORMAL
        dc.l help_tools_label-help_keys
        dc.w 206,HELP_BUTTON_Y,94,14,0,UI_NORMAL
        dc.l help_close_label-help_keys
help_keys_body:
        HELP_KEY 0,"T"
        HELP_LINE 0,"Tile page"
        HELP_KEY 1,"O"
        HELP_LINE 1,"Object page"
        HELP_KEY 2,"U"
        HELP_LINE 2,"Undo"
        HELP_KEY 3,"C"
        HELP_LINE 3,"Check the mission"
        HELP_KEY 4,"G"
        HELP_LINE 4,"Test the phase"
        HELP_KEY 5,"S"
        HELP_LINE 5,"Save"
        HELP_KEY 6,"Esc"
        HELP_LINE 6,"Menu; closes a page or a dialog"
        HELP_KEY 7,"Help"
        HELP_LINE 7,"These pages"
        HELP_KEY 8,"Arrow keys"
        HELP_LINE 8,"Scroll the map one cell"
        HELP_KEY 9,"F10"
        HELP_LINE 9,"Quit the game"
        HELP_WIDE 11,"The map also scrolls with the pointer at a"
        HELP_WIDE 12,"screen edge; hold Shift for a screen at a time."
        HELP_WIDE 14,"With the pointer on the tool bar, the Marker"
        HELP_WIDE 15,"and Object tools show how much of the phase's"
        HELP_WIDE 16,"limits is in use."
        dc.w UI_END

help_tools_title:   dc.b "Help 1/2: tools",0
help_keys_title:    dc.b "Help 2/2: keys",0
help_keys_label:    dc.b "_Keys",0
help_tools_label:   dc.b "_Tools",0
help_close_label:   dc.b "Close",0
        even
help_descriptor:    dcb.b DIALOG_BUTTONS+HELP_BUTTONS*DIALOG_BUTTON_BYTES,0
