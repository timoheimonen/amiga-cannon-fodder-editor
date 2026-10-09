; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Default draft initializer, called by the second qualified CTRL pass after
; campaign capture and before EDTR dispatch. No live AUR1 exists on this entry.
; Identity zero is an ordinary ID value, not an unsaved sentinel. The editor
; operation and later save request determine whether a source generation exists.
; D0.w=0 or -1. All other registers, SP and SR control bits are preserved.
        xdef authoring_new
authoring_new:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #-1,d0
        cmpi.w  #2,session_custom_mode
        bne     .return
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne     .return
        cmpi.w  #SESSION_EVENT_HILL,session_event
        bne     .return
        cmpi.w  #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne     .return
        cmpi.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne     .return
        cmpi.w  #1,BROWSER_VERSION
        bne     .return
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne     .return
        cmpi.w  #1,BROWSER_STATE+124
        bne     .return
        tst.w   BROWSER_STATE+126
        bne     .return
        tst.w   native_gameplay_active
        bne     .return
        tst.w   native_fifth_plane
        bne     .return
        move.w  sr,d1
        andi.w  #$0700,d1
        bne     .return

        cmpi.w #BROWSER_TEMPLATE_VALID,BROWSER_NEW_TAG
        bne.s .blank
        bsr template_import
        bra .return
.blank:
        cmpi.w  #BROWSER_NEW_VALID,BROWSER_NEW_TAG
        bne.s   .return
        moveq #0,d0
        move.w BROWSER_NEW_FAMILY,d0
        moveq #0,d1
        move.w BROWSER_NEW_WIDTH,d1
        moveq #0,d2
        move.w BROWSER_NEW_HEIGHT,d2
        bsr.s new_draft_stage
        tst.w d0
        bne.s .return
        ; Initial entry has no live draft. Commit the completed candidate only.
        lea NEW_STAGE_MAP,a0
        lea map_file_buffer,a1
        move.w NEW_STAGE_METADATA+CFMD_MAP_BYTES,d1
        lsr.w #1,d1
        subq.w #1,d1
.map:
        move.w (a0)+,(a1)+
        dbf d1,.map
        lea NEW_STAGE_SPT,a0
        lea EDITOR_SPT_BASE,a1
        move.w #EDITOR_SPT_BYTES/2-1,d1
.spt:
        move.w (a0)+,(a1)+
        dbf d1,.spt
        lea NEW_STAGE_METADATA,a0
        lea EDITOR_METADATA_BASE,a1
        move.w #EDITOR_METADATA_BYTES/4-1,d1
.metadata:
        move.l (a0)+,(a1)+
        dbf d1,.metadata
        lea EDITOR_UNDO_BASE,a0
        move.w #(EDITOR_UNDO_BYTES+EDITOR_MANIFEST_BYTES)/4-1,d1
.local:
        clr.l (a0)+
        dbf d1,.local
        clr.l STORAGE_READY
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
        include "../editor/new_stage.s"
        ifne EDITOR_UNDO_BASE+EDITOR_UNDO_BYTES-EDITOR_MANIFEST_BASE
        fail "Authoring clear requires contiguous undo and manifest owners"
        endif
