; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Display ownership of the tile and object pages. The including module
; supplies draw_toolbar.
enter_view:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.s display_acquire
        bsr draw_toolbar
        bsr publish_ring
        movem.l (sp)+,d0-d7/a0-a6
        rts

; A page shows the canvas from its first row and column.
set_ring:
        clr.l RING_X
        clr.l RING_Y
        clr.w ring_base
        clr.l view_origin_x
        rts

exit_view:
        movem.l d0-d7/a0-a6,-(sp)
        bsr display_release
        movem.l (sp)+,d0-d7/a0-a6
        rts

        include "../editor/display.s"
