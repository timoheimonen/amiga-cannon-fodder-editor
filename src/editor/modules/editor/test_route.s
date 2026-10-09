; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

edtr_request_test:
        bsr edtr_release_view
edtr_test_released:
        move.w #AUR_CONTINUE_TEST,AUR_BASE+AUR_EXIT_REQUEST
        bra edtr_save_released
; This branch is reachable only after exact entered SAVE proof was consumed.
edtr_test_saved:
        move.b #E7_TEST_READY,E7_STAGE
        move.l #$000EFFFF,-(sp)
        bra edtr_page_released

edtr_test_receipt:
        cmpi.w #1,d2
        bne.s .error
        cmpi.w #AUR_ASSETS_INCOMPLETE,AUR_ASSET_STATE(a5)
        bne edtr_receive_return
        ; The phase was played: reload all of the terrain.
        clr.l TERRAIN_STAMP
        moveq #3,d5
        bra.s edtr_test_cancel
.error:
        cmpi.w #TEST_ERROR_GAMEPLAY,d2
        bne.s .message
        moveq #6,d5
        bra.s edtr_test_cancel
.message:
        cmpi.w #-125,d2
        blo edtr_receive_return
        cmpi.w #TEST_ERROR_GAMEPLAY,d2
        bhi edtr_receive_return
        clr.b E7_STAGE
        bra tile_receive_commit
edtr_test_cancel:
        clr.b E7_STAGE
        moveq #0,d2
        bra tile_receive_commit

; Called only for incomplete-assets page14. A5 is the qualified AUR. Every
; other incomplete page retains the existing MENU-only recovery restriction.
edtr_test_return_bounds:
        cmpi.w #AUR_PAGE_NONE,d2
        bne.s .return
        cmpi.l #E7_TAG,(E7_CONTEXT-AUR_BASE)(a5)
        bne.s .return
        cmpi.b #E7_TEST_RETURNED,(E7_STAGE-AUR_BASE)(a5)
        bne.s .return
        cmpi.l #TEST_MODULE_ID,(EDITOR_SESSION_BASE+REQ_RESULT_ID-AUR_BASE)(a5)
        bne.s .return
        cmpi.w #1,(EDITOR_SESSION_BASE+REQ_LAST_RESULT-AUR_BASE)(a5)
        bne.s .return
        move.b E7_PHASE+PCREL(pc),d3
        cmp.b AUR_SELECTED(a5),d3
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
