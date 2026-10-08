; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Text and widget service of the WHDLoad Slave (backend operation 6).
; D0.w=UI_OPERATION, A0=command list, A1=target, D1.w=number of commands to
; draw (0 = up to UI_END). D0=0 drawn, 10 refused; all other registers are
; preserved. The 5x7 font uses 6x8 cells.
UI_OPERATION        equ 6
UI_CELL_WIDTH       equ 6
UI_LINE_HEIGHT      equ 8
UI_GLYPH_ROWS       equ 7

; Target: plane 0 address, bytes from one plane to the next, and a 16-byte
; table mapping the roles below to colour indices 0-15. Rows are 40 bytes and
; there are four planes.
UI_TARGET_PLANE     equ 0
UI_TARGET_STRIDE    equ 4
UI_TARGET_ROLES     equ 8
UI_TARGET_BYTES     equ 12
UI_ROW_BYTES        equ 40

; Commands: one opcode word followed by word arguments. Inline strings end
; with a zero byte and are padded to an even address.
UI_END              equ 0
UI_RECT             equ 1   ; x,y,w,h,role
UI_FRAME            equ 2   ; x,y,w,h,role
UI_TEXT             equ 3   ; x,y,w,role,align, inline string
UI_TEXT_AT          equ 4   ; x,y,w,role,align, string address (long)
UI_BUTTON           equ 5   ; x,y,w,h,state, inline label
UI_BUTTON_AT        equ 6   ; x,y,w,h,state, label address (long)
UI_BUTTON_REF       equ 7   ; x,y,w,h, state word address (long), label address (long)
UI_ROW_AT           equ 8   ; x,y,w,h,state, label address (long): flat list row
UI_LAST_COMMAND     equ 8

; Text alignment within the field [x,x+w).
UI_LEFT             equ 0
UI_CENTER           equ 1
UI_RIGHT            equ 2

; Button states.
UI_NORMAL           equ 0
UI_HOVER            equ 1
UI_ACTIVE           equ 2
UI_DISABLED         equ 3
UI_DEFAULT          equ 4
UI_DEFAULT_HOVER    equ 5

; Colour roles.
UI_BG               equ 0
UI_PANEL            equ 1
UI_FACE             equ 2
UI_FACE_HOVER       equ 3
UI_LIGHT            equ 4
UI_SHADOW           equ 5
UI_INK              equ 6
UI_DIM              equ 7
UI_ACCENT           equ 8
UI_SELECT           equ 9
UI_ERROR            equ 10
UI_OK               equ 11
UI_WARN             equ 12

; Fixed UI palette for full screens and dialog bands, colour index = role.
UI_PALETTE_RGB      macro
        dc.w $000,$223,$345,$468,$9ab,$012,$dde,$889
        dc.w $fc3,$36a,$e55,$5c6,$eb4,$000,$000,$fff
        endm

; Pointer scrolling down. The game keeps the pointer within Y 4..227, and
; every button of the 48-line bars lies above Y UI_SCROLL_DOWN_Y. The map,
; tile and object views scroll down while the pointer rests at the bottom of
; its range (bar rows 32..35), so it never scrolls on the way to a button.
UI_SCROLL_DOWN_Y    equ 224

; The recruitment hill's EDITOR and CUSTOM disks: the hill draws its LOAD
; disk (item HILL_DISK) at both X positions, then backend operation
; HILL_OPERATION writes their labels in this font below them, in the colours
; of the LOAD and SAVE labels, into the draw buffer. A disk and its label
; take HILL_LABEL_WIDTH pixels centred on the disk, rows 0..24.
HILL_OPERATION      equ 8
; The game's keyboard path calls the Slave's key service: the keyboard
; interrupt with KEY_STORE_OPERATION and D1.b = the raw code it stored (0 on a
; release), the per-field translation with KEY_EVENT_OPERATION, or with
; KEY_HOLD_OPERATION while an editor module runs outside gameplay, and
; D1.w = the held key's event, A0 = the game's key table. Both may change
; D0/D1 only, the translation also A0, like the game's own code.
KEY_STORE_OPERATION equ 9
KEY_EVENT_OPERATION equ 10
KEY_HOLD_OPERATION  equ 11
HILL_DISK           equ $16
HILL_EDITOR_X       equ 58
HILL_CUSTOM_X       equ 188
HILL_LABEL_WIDTH    equ 36
