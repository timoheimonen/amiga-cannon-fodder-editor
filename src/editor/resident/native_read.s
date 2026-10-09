; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_native_read_checked

; Enter by JMP from the track reader, retaining its caller's return address.
editor_native_read_checked:
        ; The Slave replaces the track-reader entry before it can reach this
        ; decoder continuation. An accidental direct call fails closed.
        moveq   #5,d0
        rts
