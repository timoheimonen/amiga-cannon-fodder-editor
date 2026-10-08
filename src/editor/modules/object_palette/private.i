; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Object palette identity and private scratch layout.
OPAL_MODULE_ID          equ $4f50414c
OPAL_PAGE_KIND          equ 11
PAGE_CANCEL             equ 14
PAGE_RENDER_ERROR       equ -41
PAL_ROOT_COUNT          equ 70
PAL_VISIBLE_ROWS        equ 13
OBJECT_ANCHOR_DESC      equ parts+48
pal_category            equ edtr_state_end
pal_first               equ pal_category+2
pal_count               equ pal_category+4
page_top                equ pal_category+6
page_hover              equ pal_category+8
page_choice             equ pal_category+10
page_error              equ pal_category+12
page_repeat             equ pal_category+14
page_direction          equ pal_category+16
; Nonzero once the pointer has been outside the scroll zone.
page_armed              equ pal_category+18
pal_state_end           equ pal_category+20
OBJECT_CANDIDATE         equ pal_category
; Page and bar texts, colour roles, button states and what is on screen.
PAL_TEXT                equ EDITOR_UI_BASE
PAL_READOUT             equ EDITOR_UI_BASE+64
PAL_ROLES               equ EDITOR_UI_BASE+96
PAL_TAB_STATES          equ EDITOR_UI_BASE+112
PAL_TAB_DRAWN           equ EDITOR_UI_BASE+122
PAL_BAR_STATES          equ EDITOR_UI_BASE+132
PAL_BAR_DRAWN           equ EDITOR_UI_BASE+140
PAL_DRAWN_TOP           equ EDITOR_UI_BASE+148
PAL_DRAWN_ROW           equ EDITOR_UI_BASE+150
PAL_COMMAND             equ EDITOR_UI_BASE+152
PAL_UI_END              equ EDITOR_UI_BASE+172
PAL_TABS                equ 5
PAL_BAR_BUTTONS         equ 4
PAL_BUTTON_BYTES        equ 18
PAL_LIST_Y              equ 20
PAL_ROW_PITCH           equ 12
PAL_LIST_WIDTH          equ 204
PAL_BAR_Y               equ 192
        ifgt pal_state_end-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "OPAL readback ownership exceeds the existing allocation"
        endif
        ifgt BAR_FONT_STRIP+1040-(WRAP_COPPER-BAR_BITMAP)
        fail "OPAL font strip overlaps copper scratch"
        endif
        ifgt PAL_UI_END-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "OPAL page state exceeds UI storage"
        endif
