; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Admit only an unconsumed object palette request. Publish the entered result
; after restoring the display and confirming the request owner.
aur_page_bounds:
        moveq #AUR_ERROR_STATE,d0
        cmpi.w #OPAL_PAGE_KIND,d1
        bne.s .return
        cmpi.w #AUR_PAGE_NONE,d2
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
