; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Exact typed page admission is distinct from the private eight-byte map helper.
phl_owner:
        bsr aur_validate
        bne.s .return
        moveq #PHL_ERROR_STATE,d0
        cmpi.w #AUR_PAGE_PHASE,AUR_BASE+AUR_PAGE_KIND
        bne.s .return
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        tst.w AUR_BASE+AUR_ASSET_STATE
        bne.s .return
        tst.w AUR_BASE+AUR_EXIT_REQUEST
        bne.s .return
        tst.w AUR_BASE+AUR_TRANSPORT_STATUS
        bne.s .return
        tst.l AUR_BASE+AUR_TRANSPORT_ID
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

phl_begin:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s phl_owner
        bne phl_return
        lea EDITOR_UI_BASE,a0
        moveq #63,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        lea EDITOR_METADATA_BASE,a0
        lea PHL_ORIGINAL,a1
        move.w #384,d0
        bsr phl_copy
        lea AUR_BASE,a0
        lea PHL_OWNER,a1
        move.w #128,d0
        bsr phl_copy
        lea PHL_OWNER+AUR_PHASE_MAP,a0
        lea PHL_MAP,a1
        moveq #8,d0
        bsr phl_copy
        move.b PHL_MAP+7,PHL_FOCUS+1
        move.l map_file_buffer+84,PHL_CURRENT_SIZE
        move.w AUR_BASE+AUR_PAGE_CANDIDATE,PHL_INTENT
        bsr phl_test_begin
        move.l #PHL_TAG,PHL_MAGIC
        moveq #0,d0
        bra phl_return

; Admission plus complete unchanged canonical metadata384/AUR128.
phl_check:
        bsr phl_owner
        bne.s .return
        moveq #PHL_ERROR_STATE,d0
        cmpi.l #PHL_TAG,PHL_MAGIC
        bne.s .return
        moveq #PHL_ERROR_STALE,d0
        bsr phl_test_check
        bne.s .return
        lea PHL_ORIGINAL,a0
        lea EDITOR_METADATA_BASE,a1
        moveq #95,d1
.metadata:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.metadata
        lea PHL_OWNER,a0
        lea AUR_BASE,a1
        moveq #31,d1
.owner:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.owner
        moveq #0,d0
.return:
        tst.w d0
        rts

; Fresh inspector touches WORK, never UI/tail snapshots or authored owners.
phl_inspect:
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr phl_epoch
        bne.s .return
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        tst.w d0
        bne.s .return
        bsr phl_epoch
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        cmpi.l #STORAGE_INSPECT_MAGIC,STORAGE_CONTEXT
        bne.s .return
        lea STORAGE_CONTEXT+8,a0
        lea PHL_OWNER+AUR_DISK_ID,a1
        moveq #3,d1
.id:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.id
        moveq #0,d0
.return:
        tst.w d0
        rts

; Candidate remains legal relative to the freshly qualified source manifest.
phl_valid_map:
        lea PHL_MAP,a0
        bsr plm_valid
        bne.s .return
        moveq #PHL_ERROR_SOURCE,d0
        moveq #0,d1
.loop:
        cmp.b PHL_MAP+6,d1
        bhs.s .ok
        move.b (a0,d1.w),d2
        cmpi.b #$FF,d2
        beq.s .next
        cmp.b PHL_SOURCE_COUNT,d2
        bhs.s .return
.next:
        addq.w #1,d1
        bra.s .loop
.ok:
        moveq #0,d0
.return:
        tst.w d0
        rts
phl_changed:
        moveq #1,d0
        move.l PHL_MAP,d1
        cmp.l PHL_OWNER+AUR_PHASE_MAP,d1
        bne.s .return
        move.l PHL_MAP+4,d1
        cmp.l PHL_OWNER+AUR_PHASE_MAP+4,d1
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

; Only after modal retirement. The wrapper requalifies the directory before this call.
phl_commit_map:
        movem.l d1-d7/a0-a6,-(sp)
        bsr phl_check
        bne phl_return
        cmpi.w #1,PHL_READY
        bne phl_bad_private
        bsr.s phl_valid_map
        bne phl_return
        bsr.s phl_changed
        beq.s .consume
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.l PHL_MAP,AUR_BASE+AUR_PHASE_MAP
        move.l PHL_MAP+4,AUR_BASE+AUR_PHASE_MAP+4
        move.w PHL_MAP+6,EDITOR_METADATA_BASE+CFMD_PHASE_COUNT
        ori.w #AUR_DIRTY,AUR_BASE+AUR_FLAGS
        move.w (sp)+,sr
.consume:
        move.b PHL_TESTED,E7_TESTED
        clr.l PHL_MAGIC
        bra phl_return

; Decode the guarded by-value intent into a private map and source phase.
; D0.l intent5..17. D0.l source index on success, negative on rejection.
; Requires an unchanged private map. No source/canonical publication.
phl_intent_prepare:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d7
        bsr phl_check
        bne phl_return
        bsr phl_changed
        bne phl_bad_private
        moveq #PHL_ERROR_SOURCE,d0
        btst #0,PHL_OWNER+AUR_FLAGS+1
        beq phl_return
        cmpi.l #AUR_CONTINUE_PHASE_SELECT,d7
        blo phl_return
        cmpi.l #AUR_CONTINUE_PHASE_DELETE,d7
        bhi phl_return
        cmp.w PHL_INTENT,d7
        bne phl_return
        lea PHL_MAP,a0
        moveq #0,d5
        move.b 6(a0),d5
        moveq #0,d4
        move.b 7(a0),d4
        cmpi.w #AUR_CONTINUE_PHASE_DELETE,d7
        beq.s .delete
        move.l d7,d1
        subi.w #AUR_CONTINUE_PHASE_SELECT,d1
        cmpi.w #6,d1
        blo.s .select
        subq.w #6,d1
        cmp.w d5,d1
        bhs phl_return
        cmpi.w #6,d5
        bhs phl_return
        moveq #0,d6
        move.b (a0,d1.w),d6
        cmpi.w #6,d6
        bhs phl_return
        ; Append reference, then select the newly staged independent copy.
        move.b d6,(a0,d5.w)
        move.b d5,7(a0)
        bclr d5,PHL_TESTED
        addq.b #1,6(a0)
        bra.s .ready
.select:
        cmp.w d5,d1
        bhs phl_return
        moveq #0,d6
        move.b (a0,d1.w),d6
        cmpi.w #6,d6
        bhs phl_return
        move.b d1,7(a0)
        bra.s .ready
.delete:
        cmpi.w #1,d5
        beq phl_return
        move.l d4,d1
        addq.w #1,d1
        cmp.w d5,d1
        blo.s .neighbor
        subq.w #2,d1
.neighbor:
        moveq #0,d6
        move.b (a0,d1.w),d6
        cmpi.w #6,d6
        bhs phl_return
        move.b d1,7(a0)
        move.l d4,d1
        moveq #1,d0
        bsr phl_map_apply
        tst.w d0
        bmi phl_return
.ready:
        move.w #2,PHL_READY
        move.l d6,d0
        bra phl_return

; No fallible operation follows the first authored write. The stopped editor
; has no concurrent canonical writer; source/manifest and display tails stay.
phl_commit_replacement:
        movem.l d1-d7/a0-a6,-(sp)
        bsr phl_check
        bne phl_return
        cmpi.w #2,PHL_READY
        bne phl_bad_private
        bsr phl_valid_map
        bne phl_return
        bsr phl_epoch
        bne phl_return
        lea EDITOR_READBACK_BASE,a0
        lea map_file_buffer,a1
        moveq #0,d0
        move.w PHL_STAGE_METADATA+CFMD_MAP_BYTES,d0
        bsr phl_copy
        lea PHL_STAGE_SPT,a0
        lea EDITOR_SPT_BASE,a1
        move.w #EDITOR_SPT_BYTES,d0
        bsr phl_copy
        lea PHL_STAGE_METADATA,a0
        lea EDITOR_METADATA_BASE,a1
        move.w #256,d0
        bsr phl_copy
        ; Mission edits survive Discard of current-phase edits.
        move.w PHL_ORIGINAL+CFMD_RECRUITS,EDITOR_METADATA_BASE+CFMD_RECRUITS
        lea PHL_ORIGINAL+CFMD_TITLE,a0
        lea EDITOR_METADATA_BASE+CFMD_TITLE,a1
        moveq #64,d0
        bsr phl_copy
        move.w PHL_MAP+6,EDITOR_METADATA_BASE+CFMD_PHASE_COUNT
        lea EDITOR_UNDO_BASE,a0
        move.w #EDITOR_UNDO_BYTES/4-1,d0
.undo:
        clr.l (a0)+
        dbf d0,.undo
        clr.l AUR_BASE+AUR_UNDO_NEXT
        clr.l AUR_BASE+AUR_CAMERA_X
        clr.w AUR_BASE+AUR_TOOL
        clr.w AUR_BASE+AUR_TILE
        move.w #-1,AUR_BASE+AUR_OBJECT_INDEX
        move.l PHL_MAP,AUR_BASE+AUR_PHASE_MAP
        move.l PHL_MAP+4,AUR_BASE+AUR_PHASE_MAP+4
        cmpi.w #AUR_CONTINUE_PHASE_ADD,PHL_INTENT
        blo.s .published
        ori.w #AUR_DIRTY,AUR_BASE+AUR_FLAGS
.published:
        move.b PHL_TESTED,E7_TESTED
        clr.l PHL_MAGIC
        moveq #PHL_RESULT_REPLACED,d0
        bra.s phl_return
phl_bad_private:
        moveq #PHL_ERROR_PRIVATE,d0
phl_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
