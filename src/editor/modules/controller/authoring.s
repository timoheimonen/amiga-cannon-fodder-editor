; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Two normal-stack CTRL passes: capture at the hill, then dispatch EDTR only
; after the resident bridge has captured the native main-lifecycle stack.
        xdef controller_authoring,controller_authoring_before_begin
        xdef controller_authoring_before_publish,controller_authoring_dispatch
        xdef controller_authoring_new_ready
controller_authoring:
        bsr     controller_authoring_record
        bne     controller_finish
        tst.w   native_fifth_plane
        bne     controller_authoring_bad
        move.w  sr,d1
        andi.w  #$0700,d1
        bne     controller_authoring_bad
        tst.w   session_custom_mode
        beq.s   .initial
        cmpi.w  #2,session_custom_mode
        bne     controller_authoring_bad
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne     controller_authoring_bad
        cmpi.w  #SESSION_EVENT_HILL,session_event
        bne     controller_authoring_bad
        bra.s   .qualified
.initial:
        tst.w   SESSION_SNAPSHOT_VALID
        bne     controller_authoring_bad
.qualified:
        bsr     controller_check_disk
        bne     controller_finish
        cmpi.w  #BROWSER_AUTHORING_NEW,BROWSER_AUTHORING_OPERATION
        beq.s   .ready
        cmpi.l  #1,STORAGE_READY
        bne     controller_authoring_bad
        tst.w   STORAGE_STATUS
        bne     controller_authoring_bad
        ; Gameplay diagnostics intentionally do not block opening a draft.
        bsr     controller_record_metadata
        bne     controller_finish
        bsr     controller_check_payload
        bne     controller_finish
.ready:
        tst.w   session_custom_mode
        bne.s   controller_authoring_dispatch
        cmpi.w  #BROWSER_AUTHORING_NEW,BROWSER_AUTHORING_OPERATION
        bne.s   .configured
        bsr     controller_new_setup
        beq.s   .configured
        cmpi.w  #1,d0
        bne     controller_finish
        ; A normal Cancel returns to the browser with no error or snapshot.
        lea     controller_browser_request(pc),a0
        lea     EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq   #5,d0
.cancel_request:
        move.l  (a0)+,(a1)+
        dbra    d0,.cancel_request
        move.w  #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq   #0,d0
        bra     controller_finish
.configured:
controller_authoring_before_begin:
        bsr     controller_epoch
        bne     controller_finish
        bsr     session_begin_authoring
        bne     controller_finish
        moveq   #1,d7
controller_authoring_before_publish:
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        bsr     controller_epoch
        bne.s   .unmask
        move.w  #REQ_ACTION_PREPARE,EDITOR_SESSION_BASE+REQ_ACTION
.unmask:
        move.w  (sp)+,sr
        tst.w   d0
        bne     controller_finish
        moveq   #0,d7
        bra     controller_finish
controller_authoring_dispatch:
        bsr     controller_epoch
        bne     controller_finish
        cmpi.w  #BROWSER_AUTHORING_NEW,BROWSER_AUTHORING_OPERATION
        bne.s   controller_authoring_new_ready
        bsr     authoring_new
        bne     controller_finish
controller_authoring_new_ready:
        lea     controller_editor_request(pc),a0
        lea     EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq   #5,d0
.request:
        move.l  (a0)+,(a1)+
        dbf     d0,.request
        move.w  #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq   #0,d0
        bra     controller_finish
controller_authoring_bad:
        moveq   #CONTROLLER_STATE_ERROR,d0
        bra     controller_finish

controller_authoring_record:
        moveq   #CONTROLLER_RECORD_ERROR,d0
        cmpi.w  #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne.s   .return
        cmpi.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne.s   .return
        cmpi.w  #1,BROWSER_VERSION
        bne.s   .return
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s   .return
        tst.w   BROWSER_DATA_DRIVE
        bne.s   .return
        tst.w   BROWSER_AUTHORING_RESERVED
        bne.s   .return
        move.w  BROWSER_AUTHORING_OPERATION,d1
        subq.w  #1,d1
        lsr.w   #1,d1
        bne.s   .return
        moveq   #0,d0
.return:
        tst.w   d0
        rts
        even
controller_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l $45445452,EDITOR_SERIALIZER_BYTES
