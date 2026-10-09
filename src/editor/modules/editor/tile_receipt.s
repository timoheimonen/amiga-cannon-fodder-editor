; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; By-value TILE/FILL/Resize request publication and once-only receipt consumption.
        xdef aur_prepare_page,edtr_request_tile,edtr_receive_tile
        xdef tile_receipt_start,tile_receipt_end,tile_prepare_commit
        xdef tile_receive_commit,tile_request_record
        xdef edtr_request_fill,fill_request_record,aur_page_bounds
        xdef edtr_request_resize,resize_request_record
tile_receipt_start:

; Complete view/operation release precedes every pending publication.
edtr_request_tile:
        move.l #$0001FFFF,-(sp)
        bra.s edtr_request_page
; D0.high is the bounded seed returned by terrain_input; no pointer survives.
edtr_request_fill:
        swap d0
        move.w d0,-(sp)
        move.w #AUR_PAGE_FILL,-(sp)
edtr_request_page:
        cmpi.w #1,edtr_view_live
        bne edtr_recovery_blocked
        bsr edtr_release_view
edtr_page_released:
        move.l (sp)+,d1
        move.l d1,d0
        swap d0
        bsr aur_prepare_page
        bne edtr_recovery_blocked
        ; aur_prepare_page already proved the complete page range. Preserve
        ; the original record mapping for every admitted page, including the
        ; currently unused TEMPLATE/OPEN/FILES through this particular entry.
        move.w AUR_BASE+AUR_PAGE_KIND+PCREL(pc),d0
        subq.w #1,d0
        lea page_request_offsets(pc),a0
        move.b 0(a0,d0.w),d0
        adda.w d0,a0
        bra edtr_service_dispatch
; The menu has already ended the authored view and restored its modal.
edtr_request_resize:
        move.l #$0003FFFF,-(sp)
        bra.s edtr_page_released

page_request_offsets:
        dc.b tile_request_record-page_request_offsets
        dc.b fill_request_record-page_request_offsets
        dc.b resize_request_record-page_request_offsets
        dc.b menu_request_record-page_request_offsets
        dc.b tile_request_record-page_request_offsets
        dc.b tile_request_record-page_request_offsets
        dc.b tile_request_record-page_request_offsets
        dc.b menu_request_record-page_request_offsets
        dc.b menu_request_record-page_request_offsets
        dc.b object_request_record-page_request_offsets
        dc.b palette_request_record-page_request_offsets
        dc.b phase_request_record-page_request_offsets
        dc.b validation_request_record-page_request_offsets
        dc.b test_request_record-page_request_offsets
        even
page_request_offsets_end:
        ifne page_request_offsets_end-page_request_offsets-AUR_PAGE_TEST
        fail "Page request table is incomplete"
        endif
tile_request_record:
        dc.b "cf_tiles.mod",0,0,0,0
        dc.l TILE_MODULE_ID
fill_request_record:
        dc.b "cf_fill.mod",0,0,0,0,0
        dc.l FILL_MODULE_ID
resize_request_record:
        dc.b "cf_resize.mod",0,0,0
        dc.l RESIZE_MODULE_ID
menu_request_record:
        dc.b "cf_menu.mod",0,0,0,0,0
        dc.l MENU_MODULE_ID
object_request_record:
        dc.b "cf_object.mod",0,0,0
        dc.l OBJECT_VIEW_MODULE_ID
palette_request_record:
        dc.b "cf_opal.mod",0,0,0,0,0
        dc.l OBJECT_PALETTE_MODULE_ID
phase_request_record:
        dc.b "cf_phase.mod",0,0,0,0
        dc.l PHASE_MODULE_ID
validation_request_record:
        dc.b "cf_valid.mod",0,0,0,0
        dc.l VALIDATION_MODULE_ID
test_request_record:
        dc.b "cf_test.mod",0,0,0,0,0
        dc.l TEST_MODULE_ID
        ifgt test_request_record-page_request_offsets-255
        fail "Page request byte offset exceeds255"
        endif

; D0.kind/D1.candidate; status D0, other registers preserved. No I/O or UI.
aur_prepare_page:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d6
        move.w d1,d7
        lea AUR_BASE+PCREL(pc),a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        bsr aur_validate_inner
        bne aur_return
        moveq #AUR_ERROR_REQUEST,d0
        tst.w AUR_TRANSPORT_STATUS(a5)
        bne aur_return
        tst.w AUR_EXIT_REQUEST(a5)
        bne aur_return
        move.w AUR_FLAGS(a5),d1
        andi.w #AUR_SAVE_PENDING|AUR_PAGE_PENDING,d1
        bne aur_return
        move.w d6,d1
        move.w d7,d2
        bsr.s aur_page_bounds
        bne aur_return
        cmpi.w #AUR_PAGE_VALIDATION,d6
        beq.s tile_prepare_commit
        cmpi.w #AUR_PAGE_OBJECT_PALETTE,d6
        bhs.s .require_none
        cmpi.w #AUR_PAGE_TILES,d6
        bne.s tile_prepare_commit
.require_none:
        cmpi.w #AUR_PAGE_NONE,d7
        bne.s aur_page_bad_request
tile_prepare_commit:
        clr.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        clr.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.w d6,AUR_PAGE_KIND(a5)
        move.w d7,AUR_PAGE_CANDIDATE(a5)
        ori.w #AUR_PAGE_PENDING,AUR_FLAGS(a5)
        moveq #0,d0
        bra aur_return
aur_page_bad_request:
        moveq #AUR_ERROR_REQUEST,d0
        bra aur_return

; Full metadata validation bounds the product to1..7500. This helper is
; read-only and also refuses a seed outside the current physical geometry.
        include "page_bounds.s"

; Internal tail of edtr_receive after full AUR validation. D5 remains the
; entered-SAVE proof; D6 remains failure until the shared consumption tail.
; Exact entered results:0/select,14/cancel,-41/restored renderer failure.
page_module_ids:
        dc.l TILE_MODULE_ID,FILL_MODULE_ID,RESIZE_MODULE_ID
        dc.l MENU_MODULE_ID,TEMPLATE_MODULE_ID,OPEN_MODULE_ID,FILES_MODULE_ID
        dc.l MENU_MODULE_ID,MENU_MODULE_ID,OBJECT_VIEW_MODULE_ID
        dc.l OBJECT_PALETTE_MODULE_ID,PHASE_MODULE_ID,VALIDATION_MODULE_ID,TEST_MODULE_ID
page_module_ids_end:
        ifne page_module_ids_end-page_module_ids-4*AUR_PAGE_TEST
        fail "Page receipt table is incomplete"
        endif
edtr_receive_tile:
        lea AUR_BASE+PCREL(pc),a5
        moveq #0,d2
        move.w AUR_PAGE_CANDIDATE(a5),d1
        move.w AUR_PAGE_KIND(a5),d3
        subq.w #1,d3
        lsl.w #2,d3
        move.l page_module_ids(pc,d3.w),d3
.identity:
        cmp.l EDITOR_SESSION_BASE+REQ_RESULT_ID+PCREL(pc),d3
        beq.s .entered
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne edtr_receive_return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne edtr_receive_return
        cmp.l AUR_TRANSPORT_ID(a5),d3
        bne edtr_receive_return
        ; Validation already requires -10 for every nonzero transport ID.
        bra .cancel
.entered:
        tst.l AUR_TRANSPORT_ID(a5)
        beq.s .result
        cmpi.l #EDTR_MODULE_ID,AUR_TRANSPORT_ID(a5)
        bne edtr_receive_return
.result:
        move.w EDITOR_SESSION_BASE+REQ_LAST_RESULT+PCREL(pc),d2
        cmpi.w #AUR_PAGE_TEST,AUR_PAGE_KIND(a5)
        beq edtr_test_receipt
        cmpi.w #AUR_PAGE_VALIDATION,AUR_PAGE_KIND(a5)
        beq edtr_validation_receipt
        cmpi.w #AUR_PAGE_PHASE,AUR_PAGE_KIND(a5)
        beq .phase_result
        cmpi.w #AUR_PAGE_OBJECT_VIEW,AUR_PAGE_KIND(a5)
        beq .object_result
        bhi .ordinary_result
        cmpi.w #AUR_PAGE_MESSAGE,AUR_PAGE_KIND(a5)
        bhs .dialog_result
        cmpi.w #AUR_PAGE_FILES,AUR_PAGE_KIND(a5)
        beq .menu_cancel
        cmpi.w #AUR_PAGE_TEMPLATE,AUR_PAGE_KIND(a5)
        bhs.s .menu_other
        cmpi.w #AUR_PAGE_MENU,AUR_PAGE_KIND(a5)
        bne .ordinary_result
        cmpi.w #4,d2
        bne.s .menu_exit
        tst.w AUR_ASSET_STATE(a5)
        beq edtr_receive_return
        bra.s .assets_required
.menu_exit:
        cmpi.w #2,d2
        bne.s .menu_other
        moveq #2,d5
        bra .quiet
.menu_other:
        cmpi.w #AUR_PAGE_TEMPLATE,AUR_PAGE_KIND(a5)
        bne.s .ordinary_replacement
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,d1
        bne.s .ordinary_replacement
        cmpi.w #3,d2
        bne.s .menu_cancel
        cmpi.w #AUR_HAS_SOURCE|AUR_DIRTY|AUR_PAGE_PENDING,AUR_FLAGS(a5)
        bne edtr_receive_return
        bra.s .assets_required
.ordinary_replacement:
        cmpi.w #3,d2
        bne.s .menu_cancel
        moveq #AUR_DIRTY|AUR_PAGE_PENDING,d3
        moveq #EDTR_NEW,d4
        cmpi.w #AUR_PAGE_OPEN,AUR_PAGE_KIND(a5)
        bne.s .replacement
        moveq #AUR_HAS_SOURCE|AUR_PAGE_PENDING,d3
        moveq #EDTR_OPEN,d4
.replacement:
        cmp.w AUR_FLAGS(a5),d3
        bne edtr_receive_return
        cmp.w AUR_ORIGIN(a5),d4
        bne edtr_receive_return
        clr.l E7_CONTEXT
.assets_required:
        moveq #3,d5
        bra .quiet
.menu_cancel:
        tst.w d2
        beq .selected
        cmpi.w #EDTR_VISUAL_ERROR,d2
        beq .cancel
        bra edtr_receive_return
.phase_result:
        cmpi.w #PHL_RESULT_REPLACED,d2
        bne.s .phase_map
        cmpi.w #AUR_PAGE_NONE,d1
        beq edtr_receive_return
        btst #0,AUR_FLAGS+1(a5)
        beq edtr_receive_return
        cmpi.w #AUR_CONTINUE_PHASE_ADD,d1
        blo.s .assets_required
        btst #1,AUR_FLAGS+1(a5)
        beq edtr_receive_return
        bra.s .assets_required
.phase_map:
        cmpi.w #PHL_RESULT_MAP,d2
        bne.s .menu_cancel
        cmpi.w #AUR_PAGE_NONE,d1
        bne edtr_receive_return
        bra .dirty_result
.object_result:
        ; Exact entered results. Actions 1..5 require the Object tool; 6
        ; returns a terrain tool after a switch; 0 completes one object Undo.
        cmpi.w #EDTR_VISUAL_ERROR,d2
        beq.s .object_notice
        cmpi.w #OBJECT_EDIT_REFUSED,d2
        beq.s .object_notice
        cmpi.w #OBJECT_LAST_ITEM,d2
        beq.s .object_notice
        cmpi.w #OBJECT_NO_ROOM,d2
        beq.s .object_notice
        tst.w d2
        beq.s .object_terrain
        cmpi.w #6,d2
        bne.s .object_action
.object_terrain:
        cmpi.w #2,AUR_TOOL(a5)
        beq edtr_receive_return
        bra.s .object_notice
.object_action:
        move.w d2,d3
        subq.w #1,d3
        cmpi.w #7,d3
        bhi edtr_receive_return
        cmpi.w #2,AUR_TOOL(a5)
        bne edtr_receive_return
.object_notice:
        moveq #5,d5
        bra tile_receive_commit
.object_cancel:
        moveq #0,d2
        bra.s .object_notice
.dialog_result:
        tst.w d2
        beq.s .dialog_quiet
        cmpi.w #EDTR_VISUAL_ERROR,d2
        beq.s .dialog_quiet
        cmpi.w #AUR_PAGE_LARGE,AUR_PAGE_KIND(a5)
        bne edtr_receive_return
        cmpi.w #1,d2
        bne edtr_receive_return
        move.w d1,d4
        moveq #4,d5
.dialog_quiet:
        moveq #0,d2
        bra tile_receive_commit
.ordinary_result:
        tst.w d2
        beq .selected
        cmpi.w #1,d2
        bne.s .other
        move.w AUR_PAGE_KIND(a5),d3
        subq.w #AUR_PAGE_FILL,d3
        cmpi.w #1,d3
        bhi edtr_receive_return
.dirty_result:
        btst #1,AUR_FLAGS+1(a5)
        beq edtr_receive_return
        bra.s .quiet
.other:
        cmpi.w #EDTR_VISUAL_ERROR,d2
        beq.s .cancel
        cmpi.w #14,d2
        bne edtr_receive_return
.quiet:
        moveq #0,d2
.cancel:
        cmpi.w #AUR_PAGE_TEST,AUR_PAGE_KIND(a5)
        beq edtr_test_cancel
        cmpi.w #AUR_PAGE_TEMPLATE,AUR_PAGE_KIND(a5)
        beq tile_receive_commit
        cmpi.w #AUR_PAGE_VALIDATION,AUR_PAGE_KIND(a5)
        beq edtr_validation_cancel
        cmpi.w #AUR_PAGE_PHASE,AUR_PAGE_KIND(a5)
        beq.s tile_receive_commit
        cmpi.w #AUR_PAGE_OBJECT_VIEW,AUR_PAGE_KIND(a5)
        beq .object_cancel
        bhi.s .require_cancel_none
        cmpi.w #AUR_PAGE_MESSAGE,AUR_PAGE_KIND(a5)
        bhs.s .dialog_quiet
        cmpi.w #AUR_PAGE_MENU,AUR_PAGE_KIND(a5)
        beq.s tile_receive_commit
        cmpi.w #AUR_PAGE_FILL,AUR_PAGE_KIND(a5)
        beq.s tile_receive_commit
.require_cancel_none:
        cmpi.w #AUR_PAGE_NONE,d1
        bne edtr_receive_return
        bra.s tile_receive_commit
.selected:
        cmpi.w #AUR_PAGE_OBJECT_PALETTE,AUR_PAGE_KIND(a5)
        bne.s .tile_selected
        ; Full AUR validation has admitted exactly the supported roots or NONE.
        tst.w d1
        bmi edtr_receive_return
        move.w d1,AUR_OBJECT_TYPE(a5)
        move.w #2,AUR_TOOL(a5)
        move.w #-1,AUR_OBJECT_INDEX(a5)
        bra.s tile_receive_commit
.tile_selected:
        cmpi.w #AUR_PAGE_TILES,AUR_PAGE_KIND(a5)
        bne.s tile_receive_commit
        cmpi.w #398,d1
        bhi edtr_receive_return
        move.w d1,AUR_TILE(a5)
        cmpi.w #2,AUR_TOOL(a5)
        bne.s tile_receive_commit
        clr.w AUR_TOOL(a5)
tile_receive_commit:
        clr.l AUR_PAGE_KIND(a5)
        andi.w #$FFFF-AUR_PAGE_PENDING,AUR_FLAGS(a5)
        clr.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        clr.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.w d2,d0
        ext.l d0
        bra edtr_consume_notice

tile_receipt_end:
