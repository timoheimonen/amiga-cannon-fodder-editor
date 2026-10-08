; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private live-file catalog. Canonical draft/AUR/undo/manifest stay owned.
LIVE_FILES_CONTEXT       equ 1
LIVE_FILES_SOURCE_PROTECTED equ 16
LIVE_FILES_RESERVED      equ 2304
LIVE_FILES_PRIVATE       equ EDITOR_MODULE_BASE+EDITOR_SERIALIZER_BYTES-LIVE_FILES_RESERVED
BROWSER_STATE            equ LIVE_FILES_PRIVATE
CF_DELETE_WORK_BASE      equ BROWSER_STATE+128
BDQ_PROTECTED            equ CF_DELETE_WORK_BASE+776
BDQ_SELECTED             equ BDQ_PROTECTED+20
BDQ_RECOVERY             equ BDQ_SELECTED+20
BDQ_RECORDS              equ BDQ_RECOVERY+20
BDQ_VIEW                 equ BDQ_RECORDS+900
LIVE_FILES_PRIVATE_END   equ BDQ_VIEW+300
; Four 13-line modal rows use READBACK0..8319 only while no I/O runs.
BDQ_SNAPSHOT             equ EDITOR_READBACK_BASE+8320
CF_TRACK_COPY            equ BDQ_SNAPSHOT
LIVE_FILES_SNAPSHOT_END  equ BDQ_SNAPSHOT+6144

        ifgt LIVE_FILES_PRIVATE_END-EDITOR_READBACK_BASE
        fail "Live file state exceeds private module tail"
        endif
        ifgt LIVE_FILES_SNAPSHOT_END-EDITOR_READBACK_BASE-15040
        fail "Live file directory overlaps modal palette"
        endif
