; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "fodders.i"
        include "layout.i"
        include "session.i"
        include "resident_symbols.i"

        section .text,code
        xdef editor_controller_dispatch,editor_controller_end
        xdef editor_campaign_body_start,editor_campaign_body_end

; Resident-only call. Overlay requests return before dispatching the next image.
; A prepared phase transfers to native preparation; cancel/error returns to the
; permanent bridge for campaign restoration. Scratch registers may change.
editor_campaign_body_start:
editor_controller_dispatch:
        lea     EDITOR_SESSION_BASE,a4
        move.w  sensi_selected_drive,REQ_OLD_DRIVE(a4)
        lea     editor_controller_request(pc),a0
        moveq   #1,d6
        bsr.w   editor_campaign_body_start+(RESIDENT_editor_copy_request-native_controller_body)
        cmpi.w  #2,REQ_ACTION(a4)
        bne.s   .returned
        cmpi.w  #1,(a4)
        bne.s   .invalid
        cmpi.w  #$534E,20(a4)
        bne.s   .invalid
        jmp     RESIDENT_session_prepare_phase
.returned:
        tst.w   REQ_ACTION(a4)
        bne.s   .invalid
        move.w  REQ_STATUS(a4),d0
        ext.l   d0
        rts
.invalid:
        moveq   #-11,d0
        rts
editor_controller_request:
        dc.b    'controller.mod',0,0
        dc.l    $4354524C,EDITOR_SERIALIZER_BYTES
editor_controller_end:

        ifgt editor_controller_end-editor_controller_dispatch-96
        fail "Controller exceeds replaced campaign listing body"
        endif
        dcb.b   96-(*-editor_campaign_body_start),0
editor_campaign_body_end:
