<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Template Data Reading and Decoding

`read.s` supplies `template_read_file`, which reads an original mission file
from the game disks through the native logical-drive track interface. With the
disk library initialized and logical drive 0-3 selected by the caller, D0.w
selects original map 1-72 and D1.w selects MAP (0) or SPT (1). Success returns the positive stored byte count in D0.l.
Failures are `-1` (arguments), `-2` (media), `-3` (file bounds), `-4` (cancel),
`-5` (absent) and `-6` (native read failure). All other registers, SP and SR
control bits are preserved, as is the keep-drive-selected policy.

The reader owns READBACK and the first 400 bytes of serializer scratch. It
uses native command 44 only for bounded standard-track reads; it never writes
and never invokes the original decompressor. It checks the directory, unique
exact case-insensitive filename, supported encoding, stored length, links,
cycles, cancellation and track format, then re-reads the directory before
success. Tracks in the twelve-sector campaign-save format are refused. Original
files end at their stored byte count: an unused final-sector link is ignored.
A failed read may leave partial staging bytes. The caller owns drive search,
prompts and bounded retry policy.

Successful stored bytes still require decoding and structural validation before
authored publication or engine use. Never stage over the only live authored
copy. Neither helper selects a mission, publishes metadata or changes undo.

## RNC Method 1

`rnc.s` supplies `template_rnc_unpack`, a bounded RNC method 1 decoder for
separate caller-owned input and output buffers. It uses a bit reservoir and
canonical Huffman tables and does not call the game's decompressor.

| Register | Input |
|---|---|
| A0 | Even pointer to the complete RNC1 stream |
| D0.l | Exact stream length, including the 18-byte header |
| A1 | Even pointer to a separate writable output buffer |
| D1.l | Output capacity |

D0.l returns the decoded byte count, or `-1` on refusal. Every other register,
SP and SR control bit is preserved. The caller owns the complete buffer extents;
neither may overlap code, stack or another live owner. Source and destination
capacity extents must be disjoint and end within the 24-bit address space.

The decoder requires a nonempty output, nonzero block count, exact packed
extent, unlocked stream and a declared output fitting capacity. It checks the
packed CRC before any output write, and the decoded length and CRC before
success. Tables have at most sixteen symbols, code lengths at most fifteen,
and cannot be oversubscribed. Every control refill, literal extent, backward
reference and output extent is bounded. Literals and overlapping back-references
are copied as bytes. An odd final control word is zero-padded without reading
past the source.

**Failure may leave partial output.** Only a successful return makes the staged
bytes available to subsequent MAP validation. CRC success does not establish
valid MAP geometry, resources, cells, placements or mission policy. The caller
must perform those checks before publishing an authored phase or invoking the
engine. This function neither performs disk I/O nor publishes editor state.

The fixed frame is 216 bytes, plus 56 saved-register bytes and the caller's
four-byte return address. Nested helpers add at most 32 bytes. The surrounding
execution environment must budget interrupt frames separately.

## Original Metadata

`metadata.s` uses the verified executable's immutable tables. `template_lookup`
accepts zero-based mission/phase in D0.w/D1.w and returns the one-based original
map number in D0 and mission phase count in D1, or D0=-1. It validates all 24
phase counts (1-6, total 72) and the selected indices. Other registers survive.

`template_metadata` accepts the same indices and A0 pointing to a caller-owned
384-byte output. It creates one unsaved custom phase, copies bounded original
titles/objectives/aggression, and supplies explicit starting policies. D0 is
zero or -1; other registers survive. Failed output can be partial. The caller
installs payload lengths/CRCs only after reading the matching files, and must
validate the complete phase before publication. Neither routine starts gameplay
or borrows the campaign's roster or progression.

## Live Template Overlay

`template.s` provides the `TMPL` module, loaded as `cf_tmpl.mod`. It accepts a
released authored view with a pending Template page receipt. MENU handles the
unsaved guard before dispatch; a requested Save must finish verification first.

`dialog.s` shows the picker as a dialog of the Slave's dialog service (see
[dialog](../dialog/README.md)): the game's own mission titles in a list of
eight rows, then the phases of the chosen mission, with Previous, Next, Use and
Back. Escape returns from phases to missions, then cancels. The original files
are read by trying logical drives 0 to 3 in turn. If none supplies them, a
"Game disk needed" dialog names disk 2 or 3, offers DF0 to DF3 and permits
Retry or Cancel.

The current draft remains authoritative while the helper stages and validates
its replacement. The final 4,992 bytes of the serializer partition hold packed
MAP input, then the staged SPT/metadata. READBACK retains the decoded MAP
through the final `Custom` directory inspection; the dialogs keep no bitmap
backup.
Publication requires the `Custom` directory to keep the draft's `CFEDITOR` ID.
When a Template phase is appended to a saved mission, the source manifest is
reread at entry and the directory fingerprint seen then must also be unchanged.
Otherwise "Custom directory changed" names the expected marker and offers
Retry or Cancel.
Cancellation leaves the canonical draft and undo history intact.

Publication installs an unsaved one-phase mission, clears prior source/history,
and requests EDTR with a typed replacement receipt. EDTR rebuilds terrain assets
before reacquiring the static view. No overlay pointer remains live after return.
