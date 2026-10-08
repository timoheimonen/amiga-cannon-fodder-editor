; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; TILE-only transient state. Persistent state remains in the AUR1 record.
; View state remains within the existing READBACK0..7137 envelope.
page_top               equ preview_state
page_hover             equ preview_state+2
page_choice            equ preview_state+4
page_error             equ preview_state+6
page_repeat            equ preview_state+8
page_direction         equ preview_state+10
; Nonzero once the pointer has been outside the scroll zones.
page_armed             equ preview_state+12
page_state_end         equ preview_state+14
; The tool bar of the page, drawn by the Slave's text service: texts, the
; colour roles of the terrain band, button states and what is on screen.
TILE_TEXT              equ EDITOR_UI_BASE
TILE_READOUT           equ EDITOR_UI_BASE+64
TILE_ROLES             equ EDITOR_UI_BASE+96
TILE_STATES            equ EDITOR_UI_BASE+112
TILE_DRAWN_STATES      equ EDITOR_UI_BASE+118
TILE_DRAWN_TOP         equ EDITOR_UI_BASE+124
TILE_DRAWN_TILE        equ EDITOR_UI_BASE+126
TILE_INK               equ EDITOR_UI_BASE+128
page_ui_end            equ EDITOR_UI_BASE+130
TILE_BUTTONS           equ 3
TILE_BUTTON_BYTES      equ 18
TILE_BAR_Y             equ 192
PAGE_COLS              equ 19
PAGE_ROWS              equ 21
PAGE_VISIBLE_ROWS      equ 12
PAGE_LAST_TOP          equ 9
PAGE_TILE_COUNT        equ 399
PAGE_CANCEL            equ 14
PAGE_RENDER_ERROR      equ -41
CAMERA_X               equ camera_world_x
CAMERA_Y               equ camera_world_y
RING_X                 equ display_ring_x
RING_Y                 equ display_ring_y
DISPLAY_PLANE          equ $2828
RING_BYTES             equ $2800
ROW_BYTES              equ 40
        ifgt page_state_end-parts
        fail "Page state overlaps later retained view owners"
        endif
        ifgt page_ui_end-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Page text exceeds UI owner"
        endif
        ifne PAGE_ROWS*PAGE_COLS-PAGE_TILE_COUNT
        fail "Page must offer exactly399 file-backed tiles"
        endif
