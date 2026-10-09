; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_session_continue,editor_session_invariant_failure
        xdef editor_session_cancel_original

; Lifecycle hooks arrive here only after all overlay frames have returned.
; Normal cancellation restores the campaign nonlocally. A refused restoration
; must remain in permanent code and never return through an unknown main stack.
editor_session_continue:
        bsr     editor_resident_start+(native_controller_body-EDITOR_RESIDENT_BASE)
        move.w  d0,EDITOR_SESSION_BASE+REQ_STATUS
editor_session_cancel_original:
        bsr     session_return_original
        move.w  d0,EDITOR_SESSION_BASE+REQ_STATUS
editor_session_invariant_failure:
        bsr     editor_wait_frame
        bra.s   editor_session_invariant_failure
