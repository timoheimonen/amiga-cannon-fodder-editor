; Cannon Fodder In-Game Level Editor V1.2.6
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

edtr_request_test:
        bsr edtr_release_view
edtr_test_released:
        ; A clean saved mission with identity phase mapping enters Test
        ; directly without a redundant Save; cf_test.mod still verifies the
        ; on-disk copy against the live draft before gameplay starts.
        cmpi.w #AUR_HAS_SOURCE,AUR_BASE+AUR_FLAGS
        bne.s .precheck
        tst.l AUR_BASE+AUR_SOURCE_BYTES
        beq.s .precheck
        lea AUR_BASE+AUR_PHASE_MAP,a0
        moveq #0,d0
        move.b AUR_BASE+AUR_PHASE_COUNT,d0
        moveq #0,d1
.id_check:
        moveq #-1,d2
        cmp.w d0,d1
        bhs.s .id_cmp
        move.w d1,d2
.id_cmp:
        cmp.b (a0)+,d2
        bne.s .precheck
        addq.w #1,d1
        cmpi.w #6,d1
        blo.s .id_check
        bra.s edtr_test_saved
.precheck:
        ; Dirty or unsaved drafts check the current phase for gameplay errors
        ; in RAM before spending time on Save.
        move.b #E7_TEST_PRECHECK,E7_STAGE
        move.l #$000EFFFF,-(sp)
        bra edtr_page_released
edtr_test_save_now:
        move.w #AUR_CONTINUE_TEST,AUR_BASE+AUR_EXIT_REQUEST
        bra edtr_save_released
; Reached for a clean saved mission or after exact entered SAVE proof.
edtr_test_saved:
        move.b #E7_TEST_READY,E7_STAGE
        move.l #$000EFFFF,-(sp)
        bra edtr_page_released

edtr_test_receipt:
        cmpi.w #2,d2
        bne.s .returned
        moveq #7,d5
        bra.s edtr_test_cancel
.returned:
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
