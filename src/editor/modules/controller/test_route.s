; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; A Test outcome never enters normal completion accounting or NEXT. Missing
; TST1 returns action0 through the permanent original-campaign reconstruction.
controller_test_dispatch:
        moveq #CONTROLLER_STATE_ERROR,d0
        cmpi.w #1,session_custom_mode
        bne controller_finish
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne controller_finish
        cmpi.w #SESSION_EVENT_OUTCOME,session_event
        bne controller_finish
        tst.w native_gameplay_active
        bne controller_finish
        cmpi.l #E7_TAG,E7_CONTEXT
        bne controller_finish
        cmpi.b #E7_TEST_PLAY,E7_STAGE
        bne controller_finish
        lea controller_test_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.copy:
        move.l (a0)+,(a1)+
        dbf d1,.copy
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
        bra controller_finish
controller_test_request:
        dc.b "cf_test.mod",0,0,0,0,0
        dc.l TEST_MODULE_ID,EDITOR_SERIALIZER_BYTES
