<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Authored Test lifecycle

TST1 (`cf_test.mod`, authoring page 14) runs the selected authored phase only after
the ordinary Save transaction has been verified. It rechecks the exact source
generation and selected payload before preparing fresh native troop state.
Selected-phase ERRORs block entry; REVIEWs and other phases' gameplay errors
do not block this selected phase.

The 16 KiB window reserves 4,928 bytes for manifest, SPT and metadata staging,
leaving 11,456 code bytes. Before native play, the former Save context preserves
the authored metadata's 128-byte title-projection tail. Save and this backup have
mutually exclusive lifetimes. The campaign snapshot is never captured again.

Only permanent code enters gameplay after the overlay returns. On outcome, CTRL
routes back to TST1 before ordinary accounting or phase progression. TST1 captures
the result once, then reloads the pinned saved generation. Complete publication
restores MAP, SPT, metadata and the manifest, clears Undo, and requests terrain
assets while retaining camera, tool and source. A win sets the selected TESTED
bit; abort/loss preserve previously earned bits.

A failed reload keeps gameplay mode released and offers RETRY or RETURN to the
original campaign. RETRY stages the saved generation again from the `Custom`
directory; it never changes the saved identity or the captured outcome. Partial
staging is never admitted as an editor view.
