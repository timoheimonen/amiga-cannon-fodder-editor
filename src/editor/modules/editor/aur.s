; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; AUR1 validation and receipt helpers. No dispatch, disk I/O, native gameplay or UI.
; Public entries preserve D1-D7/A0-A6/SP and SR control; D0.w is status.
; Initializer requires the trusted post-CTRL BRW1 handoff and completed New
; initialization or Open staging. Custom directory (CFDI) qualification remains
; the caller's responsibility. Only these fixed addressable buffers are accepted.
        xdef aur_validate,aur_helpers_start,aur_helpers_end
        ifnd AUR_VALIDATE_ONLY
        xdef aur_initialize,aur_prepare_save,aur_receive_save
        xdef aur_initialize_commit,aur_prepare_commit,aur_receive_commit
        endif

aur_helpers_start:
        ifnd AUR_VALIDATE_ONLY
aur_initialize:
        movem.l d1-d7/a0-a6,-(sp)
        lea AUR_BASE+PCREL(pc),a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        bsr aur_owner
        bne aur_return
        moveq #AUR_ERROR_STATE,d0
        cmpi.l #BROWSER_STATE_TAG,(a5)
        bne aur_return
        cmpi.w #1,4(a5)
        bne aur_return
        cmpi.w #REQ_PURPOSE_EDITOR,6(a5)
        bne aur_return
        tst.w AUR_ASSET_STATE(a5)
        bne aur_return
        move.w AUR_ORIGIN(a5),d6
        subq.w #1,d6
        cmpi.w #1,d6
        bhi aur_return
        addq.w #1,d6
        bsr aur_disk_record
        bne aur_return
        bsr aur_metadata_bounds
        bne aur_return
        cmpi.w #1,d6
        beq.s .new
        moveq #AUR_ERROR_SOURCE,d0
        cmpi.l #1,STORAGE_READY
        bne aur_return
        tst.w STORAGE_STATUS
        bne aur_return
        lea CFMD_MANIFEST_NAME(a6),a0
        lea BROWSER_SELECTED_NAME+PCREL(pc),a1
        moveq #3,d1
.selected:
        cmpm.l (a0)+,(a1)+
        bne aur_return
        dbf d1,.selected
        bsr aur_metadata_source
        bne aur_return
        bra.s .payload
.new:
        moveq #AUR_ERROR_SOURCE,d0
        tst.l STORAGE_READY
        bne aur_return
        cmpi.b #1,CFMD_PHASE_COUNT(a6)
        bne aur_return
        tst.b CFMD_PHASE_INDEX(a6)
        bne aur_return
        tst.l CFMD_GENERATION(a6)
        bne aur_return
        tst.w CFMD_REVISION(a6)
        bne aur_return
        tst.w CFMD_MANIFEST_BYTES(a6)
        bne aur_return
        tst.l CFMD_MANIFEST_CRC(a6)
        bne aur_return
        lea CFMD_MANIFEST_NAME(a6),a0
        moveq #3,d1
.no_name:
        tst.l (a0)+
        bne aur_return
        dbf d1,.no_name
.payload:
        bsr aur_payload
        bne aur_return
        ; No fallible operation follows the first persistent write.
aur_initialize_commit:
        ifd AUR_VALIDATION_PAGE
        clr.l E7_CONTEXT
        endif
        move.w sr,-(sp)
        ori.w #$0700,sr
        clr.l (a5)
        move.w #AUR_VERSION,4(a5)
        clr.w AUR_FLAGS(a5)
        clr.l AUR_CAMERA_X(a5)
        clr.w AUR_TOOL(a5)
        lea AUR_SOURCE_BYTES(a5),a0
        moveq #14,d1
.clear_tail:
        clr.l (a0)+
        dbf d1,.clear_tail
        move.w #-1,AUR_OBJECT_INDEX(a5)
        move.l #-1,AUR_PHASE_MAP(a5)
        move.w #-1,AUR_PHASE_MAP+4(a5)
        move.b CFMD_PHASE_COUNT(a6),AUR_PHASE_COUNT(a5)
        move.b CFMD_PHASE_INDEX(a6),AUR_SELECTED(a5)
        cmpi.w #1,d6
        bne.s .source
        move.w #AUR_DIRTY,AUR_FLAGS(a5)
        bra.s .publish
.source:
        bsr aur_install_source
        bsr aur_identity_mapping
        move.w #AUR_HAS_SOURCE,AUR_FLAGS(a5)
.publish:
        move.l #AUR_MAGIC,(a5)
        move.w (sp)+,sr
        moveq #0,d0
        bra aur_return

        endif
aur_validate:
        movem.l d1-d7/a0-a6,-(sp)
        lea AUR_BASE+PCREL(pc),a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        bsr aur_validate_inner
        bra aur_return

        ifnd AUR_VALIDATE_ONLY
; D0.w=0 Save, 1 Save as. Produces SVR1 but NEVER requests its module.
; Caller must close every edit operation and release display ownership first.
aur_prepare_save:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d6
        lea AUR_BASE+PCREL(pc),a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        bsr aur_validate_inner
        bne aur_return
        moveq #AUR_ERROR_REQUEST,d0
        tst.w AUR_TRANSPORT_STATUS(a5)
        bne aur_return
        cmpi.w #1,d6
        bhi aur_return
        move.w AUR_FLAGS(a5),d1
        andi.w #AUR_SAVE_PENDING|AUR_PAGE_PENDING,d1
        bne aur_return
aur_prepare_commit:
        lea SAVE_CONTEXT+PCREL(pc),a0
        moveq #31,d1
.clear:
        clr.l (a0)+
        dbf d1,.clear
        lea SAVE_CONTEXT+PCREL(pc),a0
        move.l #SAVE_MAGIC,(a0)
        move.l #$00010080,4(a0)
        move.w AUR_DRIVE(a5),SAVE_DRIVE(a0)
        lea AUR_PHASE_MAP(a5),a1
        lea SAVE_SOURCE_PHASES(a0),a2
        moveq #3,d1
.map:
        move.w (a1)+,(a2)+
        dbf d1,.map
        lea AUR_DISK_ID(a5),a1
        lea SAVE_DISK_ID(a0),a2
        moveq #3,d1
.id:
        move.l (a1)+,(a2)+
        dbf d1,.id
        move.l CFMD_ID(a6),SAVE_TARGET_ID(a0)
        btst #0,AUR_FLAGS+1(a5)
        beq.s .ready
        move.w #SAVE_HAS_SOURCE,SAVE_FLAGS(a0)
        lea AUR_SOURCE_NAME(a5),a1
        lea SAVE_SOURCE_NAME(a0),a2
        moveq #3,d1
.name:
        move.l (a1)+,(a2)+
        dbf d1,.name
        move.l AUR_SOURCE_ID(a5),SAVE_SOURCE_ID(a0)
        move.l AUR_SOURCE_BYTES(a5),SAVE_SOURCE_BYTES(a0)
        move.l AUR_SOURCE_CRC(a5),SAVE_SOURCE_BODY_CRC(a0)
        tst.w d6
        bne.s .save_as
        move.l AUR_SOURCE_ID(a5),SAVE_TARGET_ID(a0)
        move.w AUR_SOURCE_REVISION(a5),d1
        addq.w #1,d1
        move.w d1,SAVE_REVISION(a0)
        ; A Save continues after its own generation, so the mission keeps
        ; its place in the lists; without a hint the save starts a new block.
        move.l a0,-(sp)
        lea AUR_SOURCE_NAME(a5),a0
        bsr aur_manifest_name
        movea.l (sp)+,a0
        bne.s .ready
        addq.l #1,d1
        move.l d1,SAVE_GENERATION(a0)
        bra.s .ready
.save_as:
        move.w #SAVE_KNOWN_FLAGS,SAVE_FLAGS(a0)
.ready:
        move.w #AUR_STATUS_UNENTERED,SAVE_STATUS(a0)
        clr.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        clr.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        ori.w #AUR_SAVE_PENDING,AUR_FLAGS(a5)
        moveq #0,d0
        bra aur_return

; Consume only a matching entered SAVE result. SAVE, not this receiver, has
; already published CFMD at READY1. A rejected/inconsistent result writes no
; persistent state, leaving pending and dirty authority for explicit recovery.
aur_receive_save:
        movem.l d1-d7/a0-a6,-(sp)
        lea AUR_BASE+PCREL(pc),a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        bsr aur_validate_inner
        bne aur_return
        moveq #AUR_ERROR_RESULT,d0
        btst #2,AUR_FLAGS+1(a5)
        beq aur_return
        cmpi.l #SAVE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne aur_return
        bsr aur_match_request
        bne aur_return
        moveq #AUR_ERROR_RESULT,d0
        move.w SAVE_CONTEXT+SAVE_STATUS+PCREL(pc),d7
        cmp.w EDITOR_SESSION_BASE+REQ_LAST_RESULT+PCREL(pc),d7
        bne aur_return
        cmpi.w #AUR_STATUS_UNENTERED,d7
        beq aur_return
        tst.w d7
        beq.s .success
        tst.l SAVE_CONTEXT+SAVE_READY
        bne aur_return
        ; A failed entered call cannot clear dirty or alter source/undo.
        andi.w #$FFFF-AUR_SAVE_PENDING,AUR_FLAGS(a5)
        clr.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        move.w d7,d0
        bra aur_return
.success:
        cmpi.l #1,SAVE_CONTEXT+SAVE_READY
        bne aur_return
        cmpi.w #SAVE_STAGE_CLEANUP,SAVE_CONTEXT+SAVE_STAGE
        bne aur_return
        moveq #0,d1
        move.b AUR_PHASE_COUNT(a5),d1
        add.w d1,d1
        addq.w #1,d1
        cmp.w SAVE_CONTEXT+SAVE_PROCESSED+PCREL(pc),d1
        bne aur_return
        bsr aur_metadata_source
        bne aur_return
        moveq #AUR_ERROR_RESULT,d0
        move.l SAVE_CONTEXT+SAVE_TARGET_ID+PCREL(pc),d1
        cmp.l CFMD_ID(a6),d1
        bne aur_return
        move.l SAVE_CONTEXT+SAVE_GENERATION+PCREL(pc),d1
        cmp.l CFMD_GENERATION(a6),d1
        bne.s aur_return
        btst #0,AUR_FLAGS+1(a5)
        beq.s .new_generation
        lea AUR_SOURCE_NAME(a5),a0
        bsr aur_manifest_name
        bne.s aur_return
        moveq #AUR_ERROR_RESULT,d0
        cmp.l SAVE_CONTEXT+SAVE_GENERATION+PCREL(pc),d1
        beq.s aur_return
        cmpi.w #SAVE_KNOWN_FLAGS,SAVE_CONTEXT+SAVE_FLAGS
        bne.s .new_generation
        move.l AUR_SOURCE_ID(a5),d1
        cmp.l CFMD_ID(a6),d1
        beq.s aur_return
.new_generation:
        move.w SAVE_CONTEXT+SAVE_REVISION+PCREL(pc),d1
        cmp.w CFMD_REVISION(a6),d1
        bne.s aur_return
        moveq #0,d1
        move.w CFMD_MANIFEST_BYTES(a6),d1
        cmpi.l #SAVE_OUTPUT_CAPACITY,d1
        bhi.s aur_return
        cmp.l SAVE_CONTEXT+SAVE_RESULT_BYTES+PCREL(pc),d1
        bne.s aur_return
        move.l CFMD_MANIFEST_CRC(a6),d1
        cmp.l SAVE_CONTEXT+SAVE_RESULT_BODY_CRC+PCREL(pc),d1
        bne.s aur_return
        bsr aur_payload
        bne.s aur_return
aur_receive_commit:
        move.w sr,-(sp)
        ori.w #$0700,sr
        bsr aur_install_source
        bsr aur_identity_mapping
        move.w #AUR_HAS_SOURCE,AUR_FLAGS(a5)
        clr.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        move.w (sp)+,sr
        moveq #0,d0
        endif
aur_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

aur_owner:
        moveq #AUR_ERROR_OWNER,d0
        cmpi.w #2,session_custom_mode
        bne.s .return
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne.s .return
        cmpi.w #SESSION_EVENT_HILL,session_event
        bne.s .return
        cmpi.w #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne.s .return
        tst.w native_gameplay_active
        bne.s .return
        tst.w native_fifth_plane
        bne.s .return
        move.w sr,d1
        andi.w #$0700,d1
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

aur_validate_inner:
        bsr.s aur_owner
        bne .return
        moveq #AUR_ERROR_STATE,d0
        cmpi.l #AUR_MAGIC,(a5)
        bne .return
        cmpi.w #AUR_VERSION,4(a5)
        bne .return
        cmpi.w #AUR_KNOWN_FLAGS,AUR_FLAGS(a5)
        bhi .return
        move.w AUR_FLAGS(a5),d1
        andi.w #AUR_SAVE_PENDING|AUR_PAGE_PENDING,d1
        cmpi.w #AUR_SAVE_PENDING|AUR_PAGE_PENDING,d1
        beq .return
        move.w AUR_TRANSPORT_STATUS(a5),d1
        beq.s .no_transport_error
        cmpi.w #-10,d1
        bne .return
        tst.l AUR_TRANSPORT_ID(a5)
        beq .return
        bra.s .transport_checked
.no_transport_error:
        tst.l AUR_TRANSPORT_ID(a5)
        bne .return
.transport_checked:
        ifd AUR_PHASE_CONTINUATIONS
        cmpi.w #MENU_PHASE_SETTINGS,AUR_EXIT_REQUEST(a5)
        beq .return
        ifd AUR_TEST_PAGE
        cmpi.w #AUR_CONTINUE_TEST,AUR_EXIT_REQUEST(a5)
        else
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_EXIT_REQUEST(a5)
        endif
        else
        cmpi.w #AUR_CONTINUE_OPEN,AUR_EXIT_REQUEST(a5)
        endif
        bhi .return
        btst #3,AUR_FLAGS+1(a5)
        bne.s .page_pending
        tst.l AUR_PAGE_KIND(a5)
        bne .return
        bra.s .page_checked
.page_pending:
        tst.w AUR_EXIT_REQUEST(a5)
        bne .return
        move.w AUR_PAGE_KIND(a5),d1
        move.w AUR_PAGE_CANDIDATE(a5),d2
        bsr aur_page_bounds
        bne .return
        moveq #AUR_ERROR_STATE,d0
.page_checked:
        ifd AUR_INCOMPLETE_RECOVERY
        cmpi.w #AUR_ASSETS_INCOMPLETE,AUR_ASSET_STATE(a5)
        bhi .return
        else
        tst.w AUR_ASSET_STATE(a5)
        bne .return
        endif
        move.w AUR_ORIGIN(a5),d1
        subq.w #1,d1
        cmpi.w #1,d1
        bhi .return
        bsr aur_disk_record
        bne .return
        bsr aur_metadata_bounds
        bne .return
        moveq #AUR_ERROR_STATE,d0
        move.b AUR_PHASE_COUNT(a5),d1
        cmp.b CFMD_PHASE_COUNT(a6),d1
        bne .return
        move.b AUR_SELECTED(a5),d1
        cmp.b CFMD_PHASE_INDEX(a6),d1
        bne .return
        move.w AUR_CAMERA_X(a5),d1
        cmp.w map_file_buffer+84,d1
        bhs .return
        move.w AUR_CAMERA_Y(a5),d1
        cmp.w map_file_buffer+86,d1
        bhs .return
        cmpi.w #4,AUR_TOOL(a5)
        bhi .return
        cmpi.w #398,AUR_TILE(a5)
        bhi .return
        cmpi.w #$6E,AUR_OBJECT_TYPE(a5)
        bhi .return
        cmpi.w #255,AUR_UNDO_NEXT(a5)
        bhi .return
        cmpi.w #256,AUR_UNDO_COUNT(a5)
        bhi .return
        move.w AUR_OBJECT_INDEX(a5),d1
        cmpi.w #-1,d1
        beq.s .source
        moveq #0,d2
        move.w CFMD_SPT_BYTES(a6),d2
        divu.w #10,d2
        cmp.w d2,d1
        bhs.s .return
.source:
        btst #0,AUR_FLAGS+1(a5)
        beq.s .no_source
        moveq #AUR_ERROR_SOURCE,d0
        cmpi.l #17,AUR_SOURCE_BYTES(a5)
        blo.s .return
        cmpi.l #4096,AUR_SOURCE_BYTES(a5)
        bhi.s .return
        lea AUR_SOURCE_NAME(a5),a0
        bsr aur_manifest_name
        bne.s .return
        bra.s .mapping
.no_source:
        moveq #AUR_ERROR_SOURCE,d0
        lea AUR_SOURCE_BYTES(a5),a0
        moveq #14,d1
.empty:
        tst.w (a0)+
        bne.s .return
        dbf d1,.empty
        cmpi.b #1,AUR_PHASE_COUNT(a5)
        bne.s .return
        tst.b AUR_SELECTED(a5)
        bne.s .return
        cmpi.b #-1,AUR_PHASE_MAP(a5)
        bne.s .return
.mapping:
        moveq #0,d2
        lea AUR_PHASE_MAP(a5),a0
        moveq #AUR_ERROR_STATE,d0
.phase:
        moveq #0,d1
        move.b (a0)+,d1
        cmp.b AUR_PHASE_COUNT(a5),d2
        bhs.s .unused
        cmpi.w #6,d1
        blo.s .next
        cmp.b AUR_SELECTED(a5),d2
        bne.s .return
.unused:
        cmpi.w #255,d1
        bne.s .return
.next:
        addq.w #1,d2
        cmpi.w #6,d2
        blo.s .phase
        moveq #0,d0
.return:
        tst.w d0
        rts

aur_disk_record:
        moveq #AUR_ERROR_STATE,d0
        tst.w AUR_DRIVE(a5)
        bne.s .return
        move.l AUR_DISK_ID(a5),d1
        or.l AUR_DISK_ID+4(a5),d1
        or.l AUR_DISK_ID+8(a5),d1
        or.l AUR_DISK_ID+12(a5),d1
        beq.s .return
        lea AUR_DISK_NAME(a5),a0
        tst.b (a0)
        beq.s .return
        moveq #31,d2
.text:
        move.b (a0)+,d1
        beq.s .zero
        cmpi.b #' ',d1
        blo.s .return
        cmpi.b #'~',d1
        bhi.s .return
        dbf d2,.text
        bra.s .return
.zero:
        dbf d2,.padding
        bra.s .ok
.padding:
        tst.b (a0)+
        bne.s .return
        dbf d2,.padding
.ok:
        moveq #0,d0
.return:
        tst.w d0
        rts

; No payload CRC check here: authored edits legitimately make saved CRCs stale.
aur_metadata_bounds:
        moveq #AUR_ERROR_STATE,d0
        cmpi.l #CFMD_MAGIC,(a6)
        bne.s .return
        cmpi.l #$00010100,4(a6)
        bne.s .return
        moveq #0,d1
        move.b CFMD_PHASE_COUNT(a6),d1
        beq.s .return
        cmpi.w #6,d1
        bhi.s .return
        cmp.b CFMD_PHASE_INDEX(a6),d1
        bls.s .return
        cmpi.l #$63666564,map_file_buffer+80
        bne.s .return
        moveq #0,d1
        move.w map_file_buffer+84,d1
        beq.s .return
        moveq #0,d2
        move.w map_file_buffer+86,d2
        beq.s .return
        mulu.w d2,d1
        cmpi.l #7500,d1
        bhi.s .return
        add.l d1,d1
        addi.l #96,d1
        cmp.w CFMD_MAP_BYTES(a6),d1
        bne.s .return
        moveq #0,d1
        move.w CFMD_SPT_BYTES(a6),d1
        cmpi.w #10,d1
        blo.s .return
        cmpi.w #430,d1
        bhi.s .return
        divu.w #10,d1
        swap d1
        tst.w d1
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

        ifnd AUR_VALIDATE_ONLY
aur_metadata_source:
        moveq #AUR_ERROR_SOURCE,d0
        cmpi.w #17,CFMD_MANIFEST_BYTES(a6)
        blo.s .return
        cmpi.w #4096,CFMD_MANIFEST_BYTES(a6)
        bhi.s .return
        lea CFMD_MANIFEST_NAME(a6),a0
        bsr.s aur_manifest_name
        bne.s .return
        cmp.l CFMD_GENERATION(a6),d1
        bne.s .bad
        rts
.bad:
        moveq #AUR_ERROR_SOURCE,d0
.return:
        tst.w d0
        rts

        endif
; Canonical lowercase 8hex.cmi plus four zero bytes. D1=parsed generation.
aur_manifest_name:
        moveq #AUR_ERROR_SOURCE,d0
        cmpi.l #$2E636D69,8(a0)
        bne.s .return
        tst.l 12(a0)
        bne.s .return
        moveq #0,d1
        moveq #7,d3
.hex:
        moveq #0,d2
        move.b (a0)+,d2
        subi.w #'0',d2
        cmpi.w #9,d2
        bls.s .digit
        subi.w #'a'-'0',d2
        cmpi.w #5,d2
        bhi.s .return
        addi.w #10,d2
.digit:
        lsl.l #4,d1
        or.l d2,d1
        dbf d3,.hex
        moveq #0,d0
.return:
        tst.w d0
        rts

        ifnd AUR_VALIDATE_ONLY
aur_install_source:
        moveq #0,d1
        move.w CFMD_MANIFEST_BYTES(a6),d1
        move.l d1,AUR_SOURCE_BYTES(a5)
        move.l CFMD_MANIFEST_CRC(a6),AUR_SOURCE_CRC(a5)
        move.l CFMD_ID(a6),AUR_SOURCE_ID(a5)
        move.w CFMD_REVISION(a6),AUR_SOURCE_REVISION(a5)
        lea CFMD_MANIFEST_NAME(a6),a0
        lea AUR_SOURCE_NAME(a5),a1
        moveq #3,d1
.copy:
        move.l (a0)+,(a1)+
        dbf d1,.copy
        rts

aur_identity_mapping:
        lea AUR_PHASE_MAP(a5),a0
        moveq #0,d1
.phase:
        moveq #-1,d2
        cmp.b AUR_PHASE_COUNT(a5),d1
        bhs.s .store
        move.w d1,d2
.store:
        move.b d2,(a0)+
        addq.w #1,d1
        cmpi.w #6,d1
        blo.s .phase
        rts

aur_match_request:
        moveq #AUR_ERROR_REQUEST,d0
        lea SAVE_CONTEXT+PCREL(pc),a0
        cmpi.l #SAVE_MAGIC,(a0)
        bne .return
        cmpi.l #$00010080,4(a0)
        bne .return
        move.w AUR_DRIVE(a5),d1
        cmp.w SAVE_DRIVE(a0),d1
        bne .return
        lea AUR_DISK_ID(a5),a1
        lea SAVE_DISK_ID(a0),a2
        moveq #3,d1
.id:
        cmpm.l (a1)+,(a2)+
        bne .return
        dbf d1,.id
        lea AUR_PHASE_MAP(a5),a1
        lea SAVE_SOURCE_PHASES(a0),a2
        moveq #3,d1
.map:
        cmpm.w (a1)+,(a2)+
        bne .return
        dbf d1,.map
        move.w SAVE_FLAGS(a0),d3
        btst #0,AUR_FLAGS+1(a5)
        bne.s .source
        tst.w d3
        bne.s .return
        lea SAVE_SOURCE_NAME(a0),a1
        moveq #6,d1
.empty:
        tst.l (a1)+
        bne.s .return
        dbf d1,.empty
        tst.w SAVE_REVISION(a0)
        bne.s .return
        bra.s .ok
.source:
        cmpi.w #SAVE_HAS_SOURCE,d3
        beq.s .source_fields
        cmpi.w #SAVE_KNOWN_FLAGS,d3
        bne.s .return
.source_fields:
        lea AUR_SOURCE_NAME(a5),a1
        lea SAVE_SOURCE_NAME(a0),a2
        moveq #3,d1
.name:
        cmpm.l (a1)+,(a2)+
        bne.s .return
        dbf d1,.name
        move.l AUR_SOURCE_ID(a5),d1
        cmp.l SAVE_SOURCE_ID(a0),d1
        bne.s .return
        move.l AUR_SOURCE_BYTES(a5),d1
        cmp.l SAVE_SOURCE_BYTES(a0),d1
        bne.s .return
        move.l AUR_SOURCE_CRC(a5),d1
        cmp.l SAVE_SOURCE_BODY_CRC(a0),d1
        bne.s .return
        moveq #0,d1
        cmpi.w #SAVE_HAS_SOURCE,d3
        bne.s .revision
        move.l AUR_SOURCE_ID(a5),d1
        cmp.l SAVE_TARGET_ID(a0),d1
        bne.s .return
        move.w AUR_SOURCE_REVISION(a5),d1
        addq.w #1,d1
.revision:
        cmp.w SAVE_REVISION(a0),d1
        bne.s .return
.ok:
        moveq #0,d0
.return:
        tst.w d0
        rts

aur_payload:
        lea map_file_buffer,a0
        lea EDITOR_SPT_BASE+PCREL(pc),a1
        movea.l a6,a2
        lea AUR_VALIDATION+PCREL(pc),a3
        lea AUR_VALIDATION_WORK+PCREL(pc),a4
        moveq #0,d0
        move.w CFMD_MAP_BYTES(a6),d0
        moveq #0,d1
        move.w CFMD_SPT_BYTES(a6),d1
        bsr cf_payload_validate
        tst.w d0
        beq.s .return
        moveq #AUR_ERROR_PAYLOAD,d0
.return:
        tst.w d0
        rts
        endif
aur_helpers_end:
