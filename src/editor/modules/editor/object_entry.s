; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Live object view. EDTR supplies complete retained assets and a typed page request.
; This overlay never initializes a draft or directly restores the campaign.
; Tool 2 enters the live view; a terrain tool requests one object Undo only.
        xdef object_view_entry,object_view_idle,object_view_publish,object_owner
object_view_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne object_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne object_bad_entry
        bsr object_owner
        bne object_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr object_epoch
        bne object_return
        ; The transport has just checked the Custom marker while loading this
        ; view; it reads no storage, so it does not list Custom again.
        bsr object_owner
        bne object_return
        ; Ownership has bounded MAP/SPT extents. The reader has finished;
        ; its private candidate is now free for a metadata validation copy.
        ; Saved CRCs remain authoritative for clean drafts. Dirty edits keep
        ; stale saved CRCs until Save, so refresh only this private copy.
        lea EDITOR_METADATA_BASE,a2
        btst #1,AUR_BASE+AUR_FLAGS+1
        beq.s .payload
        movea.l a2,a0
        lea EDITOR_SERIAL_WORK_BASE+STORAGE_READ_CANDIDATE_OFFSET,a1
        movea.l a1,a2
        moveq #CFMD_RECORD_BYTES/4-1,d0
.metadata_copy:
        move.l (a0)+,(a1)+
        dbra d0,.metadata_copy
        lea map_file_buffer,a0
        moveq #0,d1
        move.w CFMD_MAP_BYTES(a2),d1
        bsr read_crc32
        move.l d0,CFMD_MAP_CRC(a2)
        lea EDITOR_SPT_BASE,a0
        moveq #0,d1
        move.w CFMD_SPT_BYTES(a2),d1
        bsr read_crc32
        move.l d0,CFMD_SPT_CRC(a2)
.payload:
        lea map_file_buffer,a0
        lea EDITOR_SPT_BASE,a1
        lea edtr_validation,a3
        lea edtr_validation_scratch,a4
        moveq #0,d0
        move.w CFMD_MAP_BYTES(a2),d0
        moveq #0,d1
        move.w CFMD_SPT_BYTES(a2),d1
        bsr cf_payload_validate
        tst.w d0
        bne object_return
        cmpi.w #2,AUR_BASE+AUR_TOOL
        beq.s .live
        bsr object_undo_edit
        moveq #OBJECT_EDIT_REFUSED,d7
        cmpi.w #1,d0
        bne object_view_publish
        bsr object_owner
        bne object_invariant
        moveq #0,d7
        bra object_view_publish
.live:
        clr.w edtr_view_live
        move.l #-1,OBJECT_LAST_RAW
        clr.l TERRAIN_OP
        clr.l TERRAIN_CURSOR_X
        cmpi.w #EDTR_NOTICE_SAVED,edtr_notice
        bne.s .cursor_ready
        move.l #-1,TERRAIN_CURSOR_X
.cursor_ready:
        bsr terrain_scroll_enter
        move.w AUR_BASE+AUR_CAMERA_X,d0
        move.w AUR_BASE+AUR_CAMERA_Y,d1
        bsr set_camera
        bne object_return
        bsr edtr_prepare_font
        bne object_return
        bsr object_anchor_prepare
        bsr enter_view
        move.w #1,edtr_view_live
        clr.w EDITOR_SESSION_BASE+REQ_ACTION
        bsr render_view
        bsr terrain_objects
.drain:
        clr.w native_last_key
        jsr wait_frame
        jsr editor_pointer_update
        tst.w native_left_down
        bne.s .drain
        tst.w native_right_down
        bne.s .drain
        clr.w native_left_pressed
        clr.w native_right_pressed
object_view_idle:
        jsr wait_frame
        jsr editor_pointer_update
        bsr object_input
        tst.w d0
        beq.s object_view_idle
        move.w d0,d7
        bsr restore_item
        move.w view_origin_x,AUR_BASE+AUR_CAMERA_X
        move.w view_origin_y,AUR_BASE+AUR_CAMERA_Y
        bsr exit_view
        clr.w edtr_view_live
        ; Drain native pointer updates with the return value on the stack.
        move.w d7,-(sp)
.release:
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
        jsr wait_frame
        jsr editor_pointer_update
        tst.w native_left_down
        bne.s .release
        tst.w native_right_down
        bne.s .release
        move.w (sp)+,d7
        bsr.s object_owner
        bne.s object_invariant
object_view_publish:
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        lea object_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbra d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        move.l #OBJECT_VIEW_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        move.w d7,d0
object_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
object_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
        bra.s object_return
object_invariant:
        ; No false restored/cancel result after an ownership invariant failed.
        jsr wait_frame
        bra.s object_invariant

object_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        cmpi.w #AUR_PAGE_OBJECT_VIEW,AUR_BASE+AUR_PAGE_KIND
        bne.s .return
        cmpi.w #AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne.s .return
        tst.w AUR_BASE+AUR_TRANSPORT_STATUS
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
object_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts
object_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES
