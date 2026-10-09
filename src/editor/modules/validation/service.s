; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Exact typed page admission is distinct from the private eight-byte map helper.
vdm_owner:
        bsr aur_validate
        bne.s .return
        moveq #VDM_ERROR_STATE,d0
        cmpi.w #AUR_PAGE_VALIDATION,AUR_BASE+AUR_PAGE_KIND
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

vdm_begin:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s vdm_owner
        bne vdm_return
        lea EDITOR_UI_BASE,a0
        moveq #63,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        lea EDITOR_METADATA_BASE,a0
        lea VDM_ORIGINAL,a1
        move.w #384,d0
        bsr vdm_copy
        lea AUR_BASE,a0
        lea VDM_OWNER,a1
        move.w #128,d0
        bsr vdm_copy
        lea VDM_STATE,a0
        moveq #29,d0
.state_clear:
        clr.l (a0)+
        dbf d0,.state_clear
        move.l #VDM_TAG,VDM_MAGIC
        moveq #0,d0
        bra vdm_return

; Admission plus complete unchanged canonical metadata384/AUR128.
vdm_check:
        bsr vdm_owner
        bne.s .return
        moveq #VDM_ERROR_STATE,d0
        cmpi.l #VDM_TAG,VDM_MAGIC
        bne.s .return
        moveq #VDM_ERROR_STALE,d0
        lea VDM_ORIGINAL,a0
        lea EDITOR_METADATA_BASE,a1
        moveq #95,d1
.metadata:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.metadata
        lea VDM_OWNER,a0
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
vdm_inspect:
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr vdm_epoch
        bne.s .return
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        tst.w d0
        bne.s .return
        bsr vdm_epoch
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        cmpi.l #STORAGE_INSPECT_MAGIC,STORAGE_CONTEXT
        bne.s .return
        lea STORAGE_CONTEXT+8,a0
        lea VDM_OWNER+AUR_DISK_ID,a1
        moveq #3,d1
.id:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.id
        moveq #0,d0
.return:
        tst.w d0
        rts


vdm_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
