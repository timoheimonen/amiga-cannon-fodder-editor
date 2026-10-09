; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Headerless synchronous component; the caller owns entry, display and return.
        include "owner.s"
        include "../browser/files.s"
        include "../browser/delete.s"
        include "../storage/read.s"
        include "../storage/manifest.s"
        include "../editor/aur.s"
        include "../editor/page_bounds.s"
live_files_end:
        ifgt live_files_end-live_files_start-(EDITOR_SERIALIZER_BYTES-LIVE_FILES_RESERVED)
        fail "Live file core overlaps private catalog"
        endif
