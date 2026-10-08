; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Dialog service of the WHDLoad Slave (backend operation 7). A dialog is a
; full-width panel band over the darkened authoring map, or over black when
; the canvas no longer holds the map that the view last published.
; D0.w=DIALOG_OPERATION, D1.w=function. D0.l returns 0 (or a choice), 10
; refused; all other registers are preserved.
DIALOG_OPERATION    equ 7

; A0=sixteen terrain colours, D2.w=byte offset of the view's first row in the
; ring. Records the canvas checksum; called after the view is retired.
DIALOG_STAMP        equ 0
; A0=descriptor, D2.l=mask of disabled buttons (bit n = button n). Takes the
; display, draws the panel and its buttons. While a dialog is open, a
; descriptor with the same top and height replaces it in place; the display
; is not released in between.
DIALOG_OPEN         equ 1
; One frame of input. D0.l=-1 while no choice was made, otherwise the code
; of the chosen button or the descriptor's cancel code.
DIALOG_POLL         equ 2
; Restores the display exactly as DIALOG_OPEN found it.
DIALOG_CLOSE        equ 3
; A0=UI command list drawn into the open panel (screen coordinates).
DIALOG_DRAW         equ 4
; D2.w=button index, D3.w=new state (UI_NORMAL, UI_ACTIVE or UI_DISABLED),
; A0=new label or 0 to keep it. Redraws the button.
DIALOG_SET          equ 5

; Descriptor, word aligned; addresses are absolute.
DIALOG_TOP          equ 0   ; first screen row of the band, at least 8
DIALOG_HEIGHT       equ 2   ; rows, at least 24; TOP+HEIGHT<=DIALOG_PANEL_ROWS
DIALOG_TITLE_ROLE   equ 4   ; title strip colour role
DIALOG_TITLE        equ 6   ; title string (long)
DIALOG_BODY         equ 10  ; UI command list drawn below the title (long, 0 none)
DIALOG_DEFAULT      equ 14  ; button index chosen by Return, -1 none
DIALOG_CANCEL       equ 16  ; code returned by Esc and right click, -1 none
DIALOG_COUNT        equ 18  ; buttons, 0..DIALOG_MAX_BUTTONS
DIALOG_BUTTONS      equ 20
DIALOG_MAX_BUTTONS  equ 32

; Button: x,y,w,h, code, state, label address. A button is chosen by a left
; press inside its rectangle; disabled buttons are ignored. DIALOG_REPEAT in
; the state word makes a held button repeat its code, first after
; DIALOG_REPEAT_DELAY frames and then every DIALOG_REPEAT_RATE frames.
DIALOG_REPEAT       equ $100
DIALOG_REPEAT_DELAY equ 12
DIALOG_REPEAT_RATE  equ 4
; DIALOG_ROW draws the button as a flat list row with a left-aligned label;
; the selected row has state UI_ACTIVE.
DIALOG_ROW_BIT      equ 9
DIALOG_ROW          equ 1<<DIALOG_ROW_BIT
DIALOG_BUTTON_X     equ 0
DIALOG_BUTTON_Y     equ 2
DIALOG_BUTTON_W     equ 4
DIALOG_BUTTON_H     equ 6
DIALOG_BUTTON_CODE  equ 8
DIALOG_BUTTON_STATE equ 10
DIALOG_BUTTON_LABEL equ 12
DIALOG_BUTTON_BYTES equ 16

; Chip memory borrowed from the second native display buffer while a dialog
; is open: the band rows of the panel planes, the copper list and an empty
; sprite. The Slave keeps their contents and the native copper list in its
; WHDLoad expansion memory and restores them on close.
DIALOG_PANEL        equ $75F60
DIALOG_PANEL_ROWS   equ 224
DIALOG_PANEL_STRIDE equ DIALOG_PANEL_ROWS*40
DIALOG_COPPER       equ DIALOG_PANEL+4*DIALOG_PANEL_STRIDE
DIALOG_COPPER_BYTES equ 512
DIALOG_SPRITE       equ DIALOG_COPPER+DIALOG_COPPER_BYTES
DIALOG_CHIP_END     equ DIALOG_SPRITE+8
        ifgt DIALOG_CHIP_END-$80000
        fail "Dialog chip memory exceeds the second display buffer"
        endif

; The authoring view's ring: 256 rows of 40 bytes per plane, planes $2828
; bytes apart, 192 visible map rows.
DIALOG_CANVAS       equ $6BEC0
DIALOG_CANVAS_PLANE equ $2828
DIALOG_RING_BYTES   equ 256*40
DIALOG_MAP_ROWS     equ 192
