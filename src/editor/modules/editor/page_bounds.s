; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
; Shared AUR page-kind/candidate bounds; metadata admission
; separately enforces nonzero geometry and the 7500-cell bound.
        xdef aur_page_bounds
aur_page_bounds:
        moveq #AUR_ERROR_STATE,d0
        ifd AUR_INCOMPLETE_RECOVERY
        ; A5 is the qualified author record. Incomplete assets admit MENU only.
        tst.w AUR_ASSET_STATE(a5)
        beq.s .assets_ready
        ifd AUR_TEST_PAGE
        cmpi.w #AUR_PAGE_TEST,d1
        beq edtr_test_return_bounds
        endif
        cmpi.w #AUR_PAGE_MENU,d1
        bne .return
        bra .no_candidate
.assets_ready:
        cmpi.w #AUR_PAGE_MESSAGE,d1
        beq .ok
        cmpi.w #AUR_PAGE_LARGE,d1
        beq .cell_candidate
        endif
        ifd AUR_TEST_PAGE
        cmpi.w #AUR_PAGE_TEST,d1
        beq.s .no_candidate
        endif
        ifd AUR_VALIDATION_PAGE
        cmpi.w #AUR_PAGE_VALIDATION,d1
        beq aur_validation_bounds
        endif
        ifd AUR_PHASE_PAGES
        cmpi.w #AUR_PAGE_PHASE,d1
        beq aur_phase_bounds
        endif
        ifd AUR_OBJECT_PAGES
        cmpi.w #AUR_PAGE_OBJECT_PALETTE,d1
        bne.s .not_palette
        cmpi.w #AUR_PAGE_NONE,d2
        beq.s .ok
        cmpi.w #110,d2
        bhi.s .return
        add.w d2,d2
        move.l a0,-(sp)
        lea op_part_index(pc),a0
        move.w 0(a0,d2.w),d3
        movea.l (sp)+,a0
        bne.s .ok
        bra.s .return
.not_palette:
        cmpi.w #AUR_PAGE_OBJECT_VIEW,d1
        beq.s .no_candidate
        endif
        cmpi.w #AUR_PAGE_TILES,d1
        bne.s .fill
        addq.w #1,d2
        cmpi.w #399,d2
        bhi.s .return
        bra.s .ok
.fill:
        cmpi.w #AUR_PAGE_MENU,d1
        bne.s .resize
        ; D2 is scratch: accept NONE or the contiguous NEW..OPEN intents.
        addq.w #1,d2
        beq.s .ok
        subq.w #AUR_CONTINUE_NEW+1,d2
        ifd AUR_PHASE_CONTINUATIONS
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE-AUR_CONTINUE_NEW,d2
        else
        cmpi.w #AUR_CONTINUE_OPEN-AUR_CONTINUE_NEW,d2
        endif
        bls.s .ok
        bra.s .return
.resize:
        cmpi.w #AUR_PAGE_RESIZE,d1
        beq.s .no_candidate
        cmpi.w #AUR_PAGE_TEMPLATE,d1
        ifd AUR_PHASE_ADDITIONS
        beq.s .template
        endif
        blo.s .fill_seed
        cmpi.w #AUR_PAGE_FILES,d1
        bhi.s .return
        ifd AUR_PHASE_ADDITIONS
        bra.s .no_candidate
.template:
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,d2
        beq.s .ok
        endif
.no_candidate:
        cmpi.w #AUR_PAGE_NONE,d2
        beq.s .ok
        bra.s .return
.fill_seed:
        cmpi.w #AUR_PAGE_FILL,d1
        bne.s .return
.cell_candidate:
        moveq #0,d3
        move.w map_file_buffer+84,d3
        mulu map_file_buffer+86,d3
        cmp.w d3,d2
        bhs.s .return
.ok:
        moveq #0,d0
.return:
        tst.w d0
        rts

        ifd AUR_PHASE_PAGES
aur_phase_bounds:
        ifd AUR_PHASE_ADDITIONS
        cmpi.w #AUR_CONTINUE_PHASE_BLANK,d2
        beq.s .ok
        endif
        cmpi.w #AUR_PAGE_NONE,d2
        beq.s .ok
        subi.w #AUR_CONTINUE_PHASE_SELECT,d2
        cmpi.w #AUR_CONTINUE_PHASE_DELETE-AUR_CONTINUE_PHASE_SELECT,d2
        bhi.s .return
.ok:
        moveq #0,d0
.return:
        tst.w d0
        rts
        endif

        ifd AUR_VALIDATION_PAGE
aur_validation_bounds:
        addq.w #1,d2
        cmpi.w #1,d2
        bhi.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
        endif
