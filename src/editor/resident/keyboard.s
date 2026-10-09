; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_key_store,editor_key_event

; The game's keyboard interrupt, D0.b = the held key's raw code (0 on its
; release). Store it as the game did and let the Slave note a press.
editor_key_store:
        move.b  D0,native_raw_key+1
        move.b  D0,D1
        moveq   #KEY_STORE_OPERATION,D0
        bra     editor_backend_call

; Tail of the game's per-field key translation, D1.w = the held key's event.
; While an editor module runs outside gameplay the Slave keeps an event until
; a module reads it; otherwise it does what the game did.
editor_key_event:
        moveq   #KEY_EVENT_OPERATION,D0
        tst.l   editor_module_active
        beq.s   .call
        tst.w   native_gameplay_active
        bne.s   .call
        moveq   #KEY_HOLD_OPERATION,D0
.call:
        bra     editor_backend_call
