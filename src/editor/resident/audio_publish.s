; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_audio_publish

; Tail of the native audio initializer. Its entry patch keeps playback disabled
; until every instrument pointer and channel has been initialized. SP points to
; the initializer's saved D0-D7/A0-A6 frame followed by its caller's return PC.
editor_audio_publish:
        move.w  SR,-(SP)
        move.w  #-1,fodders_audio_enabled
        move.w  (SP)+,SR
        movem.l (SP)+,D0-D7/A0-A6
        rts
