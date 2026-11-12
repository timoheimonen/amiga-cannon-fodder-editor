; Cannon Fodder In-Game Level Editor V1.2.5
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Authoring state and display scratch bindings. Persistent fields contain no pointers.
EDTR_MODULE_ID          equ $45445452
EDTR_OPERATION          equ BROWSER_STATE+124
EDTR_RESERVED           equ BROWSER_STATE+126
EDTR_NEW                equ 1
EDTR_OPEN               equ 2
EDTR_STATE_ERROR        equ -40
EDTR_VISUAL_ERROR       equ -41
EDTR_ASSET_UNPROVED     equ -42
EDTR_MARKER_LIMIT       equ -44
OBJECT_EDIT_REFUSED      equ -45
OBJECT_LAST_ITEM         equ -46
; Save refusals named on the message page: Custom has 150 files / no quota.
EDTR_SAVE_FILES          equ -47
EDTR_SAVE_QUOTA          equ -48
; An object placement refused because the phase has no room for it.
OBJECT_NO_ROOM           equ -49
; The Help key: a message whose dialog is the Slave's Help pages.
EDTR_HELP                equ -50
; edtr_notice value after a verified Save: the bar shows SAVED in place of
; the cell readout (cursor $FFFF) until the pointer next moves over the map.
EDTR_NOTICE_SAVED        equ $5356
EDTR_DIALOG_MENU       equ 0
EDTR_DIALOG_UNSAVED    equ 1
EDTR_DIALOG_MESSAGE    equ 2
EDTR_DIALOG_LARGE      equ 3
EDTR_CHOICE_CANCEL     equ 0
EDTR_CHOICE_SAVE       equ 1
EDTR_CHOICE_DISCARD    equ 2
; Zero disables overlay requests and retained-asset resumption until qualified.
EDTR_RETAINED_ASSETS_PROVED equ 1

CANVAS                  equ $6BEC0
BAR_BITMAP              equ $75F60
BAR_PLANE               equ $2828
BAR_COPPER              equ $77360
WRAP_COPPER             equ BAR_COPPER-36
EMPTY_SPRITE            equ $77460
PREVIEW_MASK            equ $77480
; The H anchor glyph cache lies below the 48-line tool bar.
BAR_FONT_STRIP          equ 48*40

; The view state lies in READBACK, which no file read touches while a view
; is open. The map view module sets its own base, above its code.
        ifnd VIEW_STATE_BASE
VIEW_STATE_BASE         equ EDITOR_READBACK_BASE
        endif
saved_copper            equ VIEW_STATE_BASE
font_table              equ saved_copper+3072
font_frames             equ font_table+56
preview_state           equ VIEW_STATE_BASE+3728
parts                   equ preview_state+3216
edtr_state              equ parts+64
saved_active            equ edtr_state
saved_sidebar_mode      equ edtr_state+2
saved_draw              equ edtr_state+4
saved_visible           equ edtr_state+8
saved_camera            equ edtr_state+12
saved_ring              equ edtr_state+20
saved_mask_guard        equ edtr_state+28
saved_text              equ edtr_state+30
last_camera             equ edtr_state+38
ring_base               equ edtr_state+42
changed_col             equ edtr_state+44
font_widths             equ edtr_state+46
saved_table             equ edtr_state+50
saved_mask_mode         equ edtr_state+54
saved_fifth             equ edtr_state+56
saved_space             equ edtr_state+58
saved_alternate         equ edtr_state+60
saved_fade              equ edtr_state+62
saved_palette           equ edtr_state+78
edtr_view_live          equ edtr_state+110
edtr_troop_x            equ edtr_state+112
edtr_troop_y            equ edtr_state+114
view_origin_x           equ edtr_state+116
view_origin_y           equ edtr_state+118
terrain_font_ink         equ edtr_state+122
saved_cursor_offsets    equ edtr_state+124
edtr_state_end          equ edtr_state+128
edtr_validation         equ EDITOR_SERIAL_WORK_BASE+864
edtr_validation_scratch equ EDITOR_SERIAL_WORK_BASE+896
edtr_validation_end     equ edtr_validation_scratch+128

; Transient Paint owner only. Closed before exit_view/modal/paging.
TERRAIN_OP              equ EDITOR_UI_BASE
TERRAIN_CURSOR_X        equ EDITOR_UI_BASE+4
TERRAIN_CURSOR_Y        equ EDITOR_UI_BASE+6
TERRAIN_BAR_DIRTY       equ EDITOR_UI_BASE+8 ; bit0=dirty,bit1=full bar
TERRAIN_STROKE_BLOCK    equ EDITOR_UI_BASE+10
TERRAIN_SCROLL_DIR      equ EDITOR_UI_BASE+12
TERRAIN_SCROLL_REPEAT   equ EDITOR_UI_BASE+14
; Nonzero once the pointer has been outside the scroll zones.
TERRAIN_SCROLL_ARMED    equ EDITOR_UI_BASE+16
; Nonzero after the Marker tool was chosen: the bar says what markers do.
; Each change of the cursor cell counts it down; the first one may only bring
; the cursor to the pointer.
TERRAIN_MARKER_HINT     equ EDITOR_UI_BASE+18
; Bit 0 is set while the pointer is on the tool bar: the information line
; then shows the phase's counts.
TERRAIN_ON_BAR          equ EDITOR_UI_BASE+21
; The map view's result for the view that opens next. It lies here and not
; in the view state because the map view hands it to the Object view, whose
; view state has another base.
edtr_notice             equ EDITOR_UI_BASE+22
; Paint's brush is a block of this many cells when the width is not zero.
TERRAIN_BLOCK_W         equ EDITOR_UI_BASE+24
TERRAIN_BLOCK_H         equ EDITOR_UI_BASE+26
; The cell where the selection of an area began, and nonzero while a
; button holds the selection open: 1 the right button, to copy the area,
; 2 the left button, to paint it.
TERRAIN_SELECT_X        equ EDITOR_UI_BASE+28
TERRAIN_SELECT_Y        equ EDITOR_UI_BASE+30
TERRAIN_SELECT          equ EDITOR_UI_BASE+32
; Nonzero when the information line says why a copy or a recall did nothing.
TERRAIN_BLOCK_NOTICE    equ EDITOR_UI_BASE+34
TERRAIN_UI_END          equ EDITOR_UI_BASE+80

; The terrain stamp, in the resident's spare bytes: after a complete asset
; load, the game's two terrain cache names and a checksum of the graphics and
; attributes they stand for. An editor-internal reload keeps the caches while
; both still match, so the game skips loading the same terrain again.
TERRAIN_STAMP           equ EDITOR_SPARE_BASE
TERRAIN_STAMP_TAG       equ $5445524E
TERRAIN_STAMP_NAMES     equ TERRAIN_STAMP+4
TERRAIN_STAMP_SUM       equ TERRAIN_STAMP+36
TERRAIN_STAMP_BYTES     equ 40
; After the stamp: the size of a rectangle that asks before it is painted.
; It must outlive the question, which another module shows; the page request
; carries the area's top left cell.
AREA_PENDING            equ TERRAIN_STAMP+TERRAIN_STAMP_BYTES
AREA_TAG                equ $4152
AREA_WIDTH              equ AREA_PENDING+2
AREA_HEIGHT             equ AREA_PENDING+4
        ifgt TERRAIN_STAMP_BYTES+6-EDITOR_SPARE_BYTES
        fail "Terrain stamp exceeds the spare bytes"
        endif
; Base and sub BLK graphics, the base palette and the base and sub SWP, BHT
; and HIT tables: what the game skips when its caches match.
TERRAIN_BLK             equ $3FBEA
TERRAIN_BLK_LONGS       equ (240+159)*128/4
TERRAIN_PALETTE         equ editor_base_palette
TERRAIN_ATTRIBUTES      equ editor_swp_table
TERRAIN_ATTRIBUTE_WORDS equ (editor_hit_table+400*2-editor_swp_table)/2
