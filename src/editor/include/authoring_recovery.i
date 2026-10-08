; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Resident recovery view of the shared AUR1 authoring record.
RECOVERY_AUR_BASE        equ EDITOR_IO_BASE+224
RECOVERY_AUR_MAGIC       equ $41555231
RECOVERY_AUR_STATUS      equ RECOVERY_AUR_BASE+112
RECOVERY_AUR_REQUEST_ID  equ RECOVERY_AUR_BASE+114
RECOVERY_EDITOR_ID      equ $45445452
RECOVERY_CANCEL_STATUS  equ -10
native_authoring_title   equ native_editor_hill_font+58
; AUR1 assigns +118.w Exit, +120.w PAGE_KIND and +122.w CANDIDATE.
; The page words are zero outside PAGE_PENDING. Initializer clears 112..123; the receiver
; consumes +112..117 only after observing the matching unentered request.

; Live EDTR asset-call frame only; no overlay switch occurs while this is set.
; Recovery owns UI0..35 and preserves this caller-owned longword.
RECOVERY_ASSET_STACK     equ EDITOR_UI_BASE+36
