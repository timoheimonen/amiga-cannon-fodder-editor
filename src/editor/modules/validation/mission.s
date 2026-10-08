; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; D0.l logical phase. Scan only immutable canonical current payload or a pinned
; staged source. Private CFMD reflects the logical map and pending mission fields.
; Structural refusals become one located-global error; transport failures abort.
vdm_scan_phase:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d7
        bsr vdm_check
        bne .return
        moveq #VDM_ERROR_SOURCE,d0
        moveq #0,d1
        move.b VDM_OWNER+AUR_PHASE_COUNT,d1
        cmp.l d1,d7
        bhs .return
        move.w #VDM_PAGE_ROWS,VD_CAPACITY
        clr.w VD_RESERVED
        clr.l VD_ERRORS
        clr.l VD_REVIEWS
        clr.w VD_WRITTEN
        lea VD_OUTPUT,a0
        moveq #7,d0
.clear_result:
        clr.l (a0)+
        dbf d0,.clear_result
        cmp.b VDM_OWNER+AUR_SELECTED,d7
        bne.s .disk
        bsr vald_current
        bra.s .scanned
.disk:
        lea VDM_OWNER+AUR_PHASE_MAP,a0
        moveq #0,d0
        move.b (a0,d7.w),d0
        cmpi.w #6,d0
        bhs .source_error
        bsr vdm_stage
        bne .return
        move.w VDM_ORIGINAL+CFMD_RECRUITS,VD_METADATA+CFMD_RECRUITS
        move.b VDM_OWNER+AUR_PHASE_COUNT,VD_METADATA+CFMD_PHASE_COUNT
        move.b d7,VD_METADATA+CFMD_PHASE_INDEX
        lea VDM_ORIGINAL+CFMD_TITLE,a0
        lea VD_METADATA+CFMD_TITLE,a1
        moveq #64,d0
        bsr vdm_copy
        lea EDITOR_READBACK_BASE,a0
        lea VD_STAGE_SPT,a1
        lea VD_METADATA,a2
        moveq #0,d0
        move.w VD_METADATA+CFMD_MAP_BYTES,d0
        moveq #0,d1
        move.w VD_METADATA+CFMD_SPT_BYTES,d1
        bsr vald_scan
.scanned:
        tst.w d0
        beq.s .complete
        move.w d0,VD_STATUS
        move.l VD_BASE,d1
        move.l d1,VD_TOTAL
        addq.l #1,VD_TOTAL
        move.l #1,VD_ERRORS
        clr.l VD_REVIEWS
        clr.w VD_WRITTEN
        cmp.l VD_SKIP,d1
        blo.s .complete
        lea VD_ROWS,a0
        move.l d1,(a0)
        clr.b 4(a0)
        neg.w d0
        addi.w #31,d0
        move.b d0,5(a0)
        move.b d7,6(a0)
        clr.b 7(a0)
        move.l #-1,8(a0)
        move.w #-1,12(a0)
        clr.w 14(a0)
        move.w #1,VD_WRITTEN
.complete:
        moveq #0,d0
        bra.s .return
.source_error:
        moveq #VDM_ERROR_SOURCE,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Full bounded count pass. Summaries describe every logical phase, including
; duplicate source mappings. No rows are retained from this counting pass.
vdm_scan_mission:
        movem.l d1-d7/a0-a6,-(sp)
        bsr vdm_check
        bne .return
        clr.l VDM_TOTAL
        clr.l VDM_ERRORS
        clr.l VDM_REVIEWS
        clr.l VDM_SKIP
        clr.l VDM_DIRECTORY
        clr.w VDM_DIRECTORY_VALID
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        cmpi.b #1,VDM_OWNER+AUR_PHASE_COUNT
        beq.s .current_only
        bsr vdm_inspect
        bne .return
.current_only:
        moveq #0,d7
        lea VD_SUMMARIES,a5
.phase:
        move.l VDM_TOTAL,VD_BASE
        move.l #-1,VD_SKIP
        move.l d7,d0
        bsr vdm_scan_phase
        bne.s .return
        move.w VD_STATUS,VDS_STATUS(a5)
        clr.w 2(a5)
        move.l VD_BASE,VDS_BASE(a5)
        move.l VD_TOTAL,VDS_TOTAL(a5)
        move.l VD_TOTAL,VDM_TOTAL
        move.l VD_ERRORS,d0
        move.l d0,VDS_ERRORS(a5)
        add.l d0,VDM_ERRORS
        move.l VD_REVIEWS,d0
        move.l d0,VDS_REVIEWS(a5)
        add.l d0,VDM_REVIEWS
        move.l VD_OUTPUT+CFVR_ERRORS,VDS_ERROR_BITS(a5)
        move.l VD_OUTPUT+CFVR_REVIEWS,VDS_REVIEW_BITS(a5)
        move.l VD_OUTPUT+CFVR_WIDTH,VDS_SIZE(a5)
        clr.l 32(a5)
        clr.l 36(a5)
        adda.w #VDM_SUMMARY_BYTES,a5
        addq.w #1,d7
        cmp.b VDM_OWNER+AUR_PHASE_COUNT,d7
        blo .phase
        bsr vdm_check
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; At most three phases can contribute to three displayed rows. Retire the modal
; before entry. Each contributing phase is reread, then its full counts/bitsets
; are compared with the initial summary before a row is accepted.
vdm_read_page:
        movem.l d1-d7/a0-a6,-(sp)
        bsr vdm_check
        bne .return
        clr.w VDM_PAGE_COUNT
        clr.w VDM_FOCUS
        lea VDM_PAGE,a0
        moveq #VDM_PAGE_ROWS*VD_ROW_BYTES/4-1,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        moveq #0,d7
        lea VD_SUMMARIES,a5
.phase:
        move.l VDS_TOTAL(a5),d0
        cmp.l VDM_SKIP,d0
        bls .next
        move.l VDS_BASE(a5),VD_BASE
        move.l VDM_SKIP,VD_SKIP
        move.l d7,d0
        bsr vdm_scan_phase
        bne .return
        moveq #VDM_ERROR_STALE,d0
        move.w VD_STATUS,d1
        cmp.w VDS_STATUS(a5),d1
        bne .return
        move.l VD_TOTAL,d1
        cmp.l VDS_TOTAL(a5),d1
        bne .return
        move.l VD_ERRORS,d1
        cmp.l VDS_ERRORS(a5),d1
        bne.s .return
        move.l VD_REVIEWS,d1
        cmp.l VDS_REVIEWS(a5),d1
        bne.s .return
        move.l VD_OUTPUT+CFVR_ERRORS,d1
        cmp.l VDS_ERROR_BITS(a5),d1
        bne.s .return
        move.l VD_OUTPUT+CFVR_REVIEWS,d1
        cmp.l VDS_REVIEW_BITS(a5),d1
        bne.s .return
        moveq #0,d2
        move.w VD_WRITTEN,d2
        beq.s .next
        lea VD_ROWS,a0
        lea VDM_PAGE,a1
        move.w VDM_PAGE_COUNT,d1
        lsl.w #4,d1
        adda.w d1,a1
.copy:
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        addq.w #1,VDM_PAGE_COUNT
        cmpi.w #VDM_PAGE_ROWS,VDM_PAGE_COUNT
        beq.s .done
        subq.w #1,d2
        bne.s .copy
.next:
        adda.w #VDM_SUMMARY_BYTES,a5
        addq.w #1,d7
        cmp.b VDM_OWNER+AUR_PHASE_COUNT,d7
        blo .phase
.done:
        bsr vdm_check
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Retired UI publishes only a by-value location. The receiver must validate
; the typed receipt, guard cross-phase replacement, then apply the focus once.
; Object X is native serialized X: add16 before converting/clamping to cells.
vdm_jump:
        movem.l d1-d7/a0-a6,-(sp)
        bsr vdm_check
        bne .return
        moveq #VDM_ERROR_STATE,d0
        move.w VDM_FOCUS,d1
        cmp.w VDM_PAGE_COUNT,d1
        bhs .return
        lsl.w #4,d1
        lea VDM_PAGE,a0
        adda.w d1,a0
        moveq #0,d4
        move.b 6(a0),d4
        cmp.b VDM_OWNER+AUR_PHASE_COUNT,d4
        bhs .return
        moveq #0,d5
        move.b 7(a0),d5
        subq.w #1,d5
        cmpi.w #1,d5
        bhi .return
        move.w 10(a0),d1
        move.w 12(a0),d2
        tst.w d5
        beq.s .cells
        addi.w #16,d1
        asr.w #4,d1
        asr.w #4,d2
.cells:
        tst.w d1
        bpl.s .x_positive
        clr.w d1
.x_positive:
        tst.w d2
        bpl.s .y_positive
        clr.w d2
.y_positive:
        move.w d4,d3
        mulu #VDM_SUMMARY_BYTES,d3
        lea VD_SUMMARIES,a1
        adda.w d3,a1
        move.w VDS_SIZE(a1),d3
        beq.s .return
        subq.w #1,d3
        cmp.w d3,d1
        bls.s .x_bounded
        move.w d3,d1
.x_bounded:
        move.w VDS_SIZE+2(a1),d3
        beq.s .return
        subq.w #1,d3
        cmp.w d3,d2
        bls.s .y_bounded
        move.w d3,d2
.y_bounded:
        bsr vdm_test_mask
        move.b d0,d6
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.b d6,E7_TESTED
        move.b d4,E7_PHASE
        addq.w #1,d5
        move.b d5,E7_LOCATION
        move.w d1,E7_X
        move.w d2,E7_Y
        move.w 8(a0),E7_INDEX
        clr.w E7_RESERVED
        move.b #E7_JUMP_PENDING,E7_STAGE
        move.l #E7_TAG,E7_CONTEXT
        move.w (sp)+,sr
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Retired normal-page Jump or candidate0 resume. No pointer crosses the page.
; The native editor shows19x12 cells. Center, then clamp to those viewportbounds.
vdm_apply_focus:
        movem.l d1-d7/a0-a6,-(sp)
        bsr vdm_check
        bne .return
        moveq #VDM_ERROR_STATE,d0
        cmpi.l #E7_TAG,E7_CONTEXT
        bne .return
        cmpi.b #E7_JUMP_PENDING,E7_STAGE
        bne .return
        move.b E7_PHASE,d1
        cmp.b VDM_OWNER+AUR_SELECTED,d1
        bne .return
        move.b E7_LOCATION,d1
        subq.b #1,d1
        cmpi.b #1,d1
        bhi .return
        tst.w E7_RESERVED
        bne .return
        cmpi.b #$3F,E7_TESTED
        bhi .return
        moveq #0,d3
        move.w E7_INDEX,d3
        moveq #0,d4
        tst.b d1
        bne.s .object_index
        move.w map_file_buffer+84,d4
        mulu map_file_buffer+86,d4
        bra.s .index_bound
.object_index:
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d4
        divu #10,d4
.index_bound:
        cmp.w d4,d3
        bhs.s .return
        move.w E7_X,d1
        move.w E7_Y,d2
        cmp.w map_file_buffer+84,d1
        bhs.s .return
        cmp.w map_file_buffer+86,d2
        bhs.s .return
        subi.w #9,d1
        bpl.s .xmin
        clr.w d1
.xmin:
        subi.w #6,d2
        bpl.s .ymin
        clr.w d2
.ymin:
        move.w map_file_buffer+84,d3
        subi.w #19,d3
        bpl.s .xlimit
        clr.w d3
.xlimit:
        cmp.w d3,d1
        bls.s .xmax
        move.w d3,d1
.xmax:
        move.w map_file_buffer+86,d3
        subi.w #12,d3
        bpl.s .ylimit
        clr.w d3
.ylimit:
        cmp.w d3,d2
        bls.s .ymax
        move.w d3,d2
.ymax:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w d1,AUR_BASE+AUR_CAMERA_X
        move.w d2,AUR_BASE+AUR_CAMERA_Y
        move.w d1,E7_X
        move.w d2,E7_Y
        move.b #E7_FOCUS_APPLIED,E7_STAGE
        move.w (sp)+,sr
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
