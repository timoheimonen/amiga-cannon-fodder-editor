; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The owned hill-font strip serves the preview's H marker of type $18; the
; page's ink is the most contrasting terrain colour.
edtr_prepare_font:
        bsr.s font_strip_prepare
        bne.s .return
        bra terrain_font_palette
.return:
        rts
