; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Synchronous browser file operations and closed-guard catalog refresh.

browser_files_request:
        moveq #10,d0
        tst.w BROWSER_DATA_DRIVE
        bne.s .return
        lea BDQ_CONTEXT,a0
        moveq #31,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        lea BDQ_CONTEXT,a0
        move.l #BDQ_MAGIC,(a0)
        move.l #$00010080,4(a0)
        move.w BROWSER_FILES_VIEW,d0
        addq.w #1,d0
        move.w d0,BDQ_OPERATION(a0)
        move.w BROWSER_DATA_DRIVE,BDQ_DRIVE(a0)
        lea BROWSER_SELECTED_NAME,a1
        lea BDQ_NAME(a0),a2
        moveq #3,d0
.name:
        move.l (a1)+,(a2)+
        dbf d0,.name
        lea BROWSER_DISK_ID,a1
        moveq #3,d0
.id:
        move.l (a1)+,(a2)+
        dbf d0,.id
        move.l BROWSER_DIRECTORY_CRC,(a2)
        bsr browser_delete_open
.return:
        tst.w d0
        rts

; Read-only scan may restore already computed validation only after exact
; unchanged identity/name/directory proof. No selection/confirmation runs here.
browser_files_catalog:
        move.w BROWSER_VALIDATION,-(sp)
        move.w BROWSER_DISPLAY_SAFE,-(sp)
        bsr.s browser_files_request
        bne.s .done
        bsr browser_files_classify
        bne.s .close
        lea BROWSER_SELECTED_NAME,a0
        lea BF_NAME,a1
        moveq #3,d0
.name:
        cmpm.l (a0)+,(a1)+
        bne.s .changed
        dbf d0,.name
        lea BROWSER_DISK_ID,a0
        lea BF_DISK_ID,a1
        moveq #3,d0
.id:
        cmpm.l (a0)+,(a1)+
        bne.s .changed
        dbf d0,.id
        tst.l BDQ_CONTEXT+BDQ_ATTEMPTED
        bne.s .changed
        bsr browser_delete_check
        bra.s .close
.changed:
        moveq #11,d0
.close:
        bsr browser_delete_close
.done:
        tst.w d0
        bne.s .discard
        move.w (sp)+,BROWSER_DISPLAY_SAFE
        move.w (sp)+,BROWSER_VALIDATION
        bra.s browser_files_names
.discard:
        addq.l #4,sp
        rts

; The guard is closed: flatten names before old snapshot bytes become pages.
; Recovery view words pack representative record index:8 / group count:8.
browser_files_names:
        clr.w BROWSER_COUNT
        moveq #0,d6
.record:
        move.w d6,d0
        bsr bf_record
        tst.w BROWSER_FILES_VIEW
        beq.s .normal
        move.w d6,d0
        lea BF_RECOVERY,a1
        bsr bf_test_bit
        beq.s .next
        moveq #0,d7
.group:
        cmp.w BROWSER_COUNT,d7
        bhs.s .new
        move.w d7,d0
        lsl.w #4,d0
        lea BROWSER_NAMES,a1
        adda.w d0,a1
        bsr bf_prefix_equal
        beq.s .count
        addq.w #1,d7
        bra.s .group
.normal:
        cmpi.b #BF_DAMAGED,5(a2)
        blo.s .next
        move.w BROWSER_COUNT,d7
.new:
        move.w d7,d0
        lsl.w #4,d0
        lea BROWSER_NAMES,a1
        adda.w d0,a1
        bsr bf_copy_name
        addq.w #1,BROWSER_COUNT
        move.w d7,d0
        add.w d0,d0
        move.w d6,d1
        lsl.w #8,d1
        lea BF_VIEW_INDICES,a1
        move.w d1,0(a1,d0.w)
.count:
        move.w d7,d0
        add.w d0,d0
        lea BF_VIEW_INDICES,a1
        addq.w #1,0(a1,d0.w)
.next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo .record
        move.w BROWSER_SELECTED,d0
        cmp.w BROWSER_COUNT,d0
        blo.s .selected
        ; Past the end after a deletion: select the new last entry.
        move.w BROWSER_COUNT,d0
        subq.w #1,d0
        bpl.s .last_entry
        moveq #0,d0
.last_entry:
        move.w d0,BROWSER_SELECTED
.selected:
        bra browser_epoch

browser_files_row:
        bsr browser_row_pointer
        move.w BROWSER_SCAN_INDEX,d0
        lsl.w #4,d0
        lea BROWSER_NAMES,a0
        adda.w d0,a0
        movea.l a4,a1
        moveq #7,d1
.hex:
        move.b (a0)+,d0
        cmpi.b #'a',d0
        blo.s .store
        subi.b #32,d0
.store:
        move.b d0,(a1)+
        dbf d1,.hex
        move.b #$FF,(a1)
        move.w BROWSER_SCAN_INDEX,d0
        add.w d0,d0
        lea BF_VIEW_INDICES,a0
        move.w 0(a0,d0.w),d0
        andi.w #$FF,d0
        move.w d0,BROWSER_ROW_PHASES(a4)
        bra browser_page_advance

browser_files_recovery:
        move.w #1,BROWSER_FILES_VIEW
        bra.s browser_files_view_refresh
browser_files_normal:
        clr.w BROWSER_FILES_VIEW
browser_files_view_refresh:
        clr.w BROWSER_SELECTED
        clr.w BROWSER_RESUMING
        clr.w BROWSER_VALIDATION
        bra browser_control_inspect

browser_files_delete:
        tst.w BROWSER_COUNT
        beq browser_idle
        move.w BROWSER_SELECTED,d0
        lsl.w #4,d0
        lea BROWSER_NAMES,a0
        adda.w d0,a0
        lea BROWSER_SELECTED_NAME,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        bsr browser_files_request
        bne.s .refresh
        bsr browser_files_classify
        bne.s .close
        bsr browser_files_select
        bne.s .close
        bsr browser_files_title
        bne.s .close
        bsr browser_files_ui_confirm
        cmpi.w #1,d0
        bne.s .close
        bsr browser_delete_check
        bne.s .close
        move.w #1,BDQ_CONTEXT+BDQ_CONFIRMED
        lea BDQ_CONTEXT,a0
        bsr browser_delete_commit
        bra.s .refresh
.close:
        bsr browser_delete_close
.refresh:
        cmpi.w #14,d0
        bne.s .status
        tst.w BDQ_CONTEXT+BDQ_ATTEMPTED
        bne.s .attempted
        moveq #0,d0
        bra.s .status
.attempted:
        tst.w BDQ_CONTEXT+BDQ_VERIFIED
        beq.s .status
        moveq #-1,d0
.status:
        move.w d0,BROWSER_FILES_STATUS
        clr.w BROWSER_RESUMING
        clr.w BROWSER_VALIDATION
        clr.w BROWSER_CONTROLLER_STATUS
        clr.l BROWSER_ERRORS
        bra browser_control_inspect

browser_files_glue_end:
