; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Resident live-draft detection and by-value editor reload after cancellation.
        xdef editor_authoring_live,editor_authoring_cancel

; Z=1 only for a published AUR1 owned by the current authored session.
; All data/address registers and X are preserved; callers consume Z only.
editor_authoring_live:
        cmpi.w  #2,session_custom_mode
        bne.s   .done
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne.s   .done
        cmpi.l  #RECOVERY_AUR_MAGIC,RECOVERY_AUR_BASE
        bne.s   .done
        cmpi.w  #1,RECOVERY_AUR_BASE+4
.done:
        rts

; Enter with A4=session, no module frames live, and a qualified AUR1.
; The request loop owns the existing drive restoration and resident return.
editor_authoring_cancel:
        move.w  editor_resident_start+(RECOVERY_AUR_STATUS-EDITOR_RESIDENT_BASE)(pc),d0
        bne.s   .restore
        move.w  #RECOVERY_CANCEL_STATUS,RECOVERY_AUR_STATUS
        move.l  REQ_ID(a4),RECOVERY_AUR_REQUEST_ID
.restore:
        lea     editor_authoring_request(pc),a0
        bra     editor_copy_request
editor_authoring_request:
        dc.b    "cf_editor.mod",0,0,0
        dc.l    RECOVERY_EDITOR_ID,EDITOR_SERIALIZER_BYTES
