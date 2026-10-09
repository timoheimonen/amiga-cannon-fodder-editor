; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Retained authoring owner and source-generation protection. No writes.
        xdef live_files_owner,live_files_protect_source
live_files_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        cmpi.w #LIVE_FILES_PAGE,AUR_BASE+AUR_PAGE_KIND
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

; Check the complete selected mask, not merely the clicked manifest. A damaged
; or missing source manifest cannot grant permission to erase its phase files.
; Same generation in a Custom directory with another CFDI ID is independent. Preserve registers.
live_files_protect_source:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s live_files_owner
        bne.s .return
        btst #0,AUR_BASE+AUR_FLAGS+1
        beq.s .allowed
        lea AUR_BASE+AUR_DISK_ID,a0
        lea BDQ_CONTEXT+BDQ_DISK_ID,a1
        moveq #3,d1
.disk:
        cmpm.l (a0)+,(a1)+
        bne.s .allowed
        dbf d1,.disk
        moveq #10,d0
        move.w BF_RECORD_COUNT,d5
        beq.s .return
        cmpi.w #150,d5
        bhi.s .return
        moveq #0,d6
.record:
        move.w d6,d0
        lea BF_SELECTED,a1
        bsr bf_test_bit
        beq.s .next
        bsr bf_record
        lea AUR_BASE+AUR_SOURCE_NAME,a1
        bsr bf_prefix_equal
        beq.s .protected
.next:
        addq.w #1,d6
        cmp.w d5,d6
        blo.s .record
.allowed:
        moveq #0,d0
        bra.s .return
.protected:
        moveq #LIVE_FILES_SOURCE_PROTECTED,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
