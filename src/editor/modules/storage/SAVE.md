<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Verified Generation Save

`save.s` combines the file reader, canonical encoder, payload validator,
preflight, file creation and verified generation cleanup. It is a CFMO ABI 2
overlay named `cf_save.mod`, identity `SVR1`, linked at `EDITOR_MODULE_BASE`
(`$0B11FA`) with a 16 KiB image cap. It writes a new generation of files to the
`Custom` directory without overwriting the files of its source generation.

The direct entry `cf_save_entry` takes `A0 = SAVE_CONTEXT` from `save.i`. D0.w
returns the status; D1-D7/A0-A6 and SP are preserved.

## Module Entry

`cf_save_module_entry` takes `D0.w = 2` and `A0 = EDITOR_SESSION_BASE`; anything
else returns 10. In authoring mode 2 it first requires the campaign-snapshot tag
and a valid AUR1 record, then runs `cf_save_qualify`:

- snapshot tag, hill event, Editor purpose, stopped gameplay, four-plane display
  and interrupt priority 0;
- AUR1 asset state complete or incomplete, a pending Save flag, no transport
  status or identity;
- a fresh SVR1 request: header `$00010080`, status unentered, READY zero and no
  pending session result;
- AUR1 and SVR1 source selectors both zero and identical disk IDs;
- a Custom-directory inspection whose `CFEDITOR` ID equals the AUR1 disk ID.

A refused qualification is stored as an entered result (status, stage 1, zero
results) without running the core. The entry then writes `REQ_LAST_RESULT` and
`REQ_RESULT_ID = SVR1`. In mode 2 it requests a DISPATCH of `cf_editor.mod`
(`EDTR`) after checking the AUR1 continuation record; otherwise it requests a
normal resident return. A broken authoring invariant leaves the module in a
non-interactive frame-wait loop instead of returning to the hill.

## Request

The 128-byte SVR1 record occupies resident I/O bytes 352..479. Multi-byte fields
are big-endian; no field contains a pointer. Initialize the complete record for
each call and clear READY before requesting module dispatch, since a failed
module load cannot clear an earlier result.

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 4 | `SVR1` magic |
| 4 | 2 | Request ABI 1 |
| 6 | 2 | Record size 128 |
| 8 | 2 | Flags: 0 new mission, 1 existing source, 3 Save as from source |
| 10 | 2 | Source selector, must be zero (the `Custom` directory) |
| 12 | 6 | Source phase for each target phase; unused slots `$FF` |
| 18 | 1 | Target phase count, 1..6 |
| 19 | 1 | Current authored target phase, zero-based |
| 20 | 16 | Expected nonzero `CFEDITOR` disk ID |
| 36 | 16 | Exact canonical old manifest filename, NUL-padded |
| 52 | 4 | Expected old mission ID |
| 56 | 4 | Exact old CFMI file length, 17..4,096 |
| 60 | 4 | Expected old JSON-body CRC from the CFMI envelope |
| 64 | 4 | Generation hint; replaced with the chosen unused generation |
| 68 | 4 | Target mission ID; a new or Save-as collision advances it modulo 2^32 |
| 72 | 2 | Target revision: zero for new/Save as, old revision plus one modulo 65,536 otherwise |
| 74 | 2 | Returned status |
| 76 | 2 | Last stage |
| 78 | 2 | Number of files created |
| 80 | 4 | New CFMI file length after encoding |
| 84 | 4 | New JSON-body CRC after encoding |
| 88 | 4 | READY, zero until verified commitment, then one |
| 92 | 4 | Live cancellation, nonzero requests cancellation |
| 96 | 2 | Separate cleanup status after a verified save; zero means the scan completed |
| 98 | 30 | Private transaction scratch, cleared on entry |

Without an old source, bytes 36..63 are zero, the count is one, the selected
phase is zero and every source mapping byte is `$FF`. With a source, only the
selected phase may use `$FF` for a new phase; every other active mapping indexes
the old manifest. Reordering or removing old phases needs no second resident MAP.

The current authored MAP is `map_file_buffer`; canonical SPT is at
`EDITOR_SPT_BASE`; current CFMD is at `EDITOR_METADATA_BASE`. CFMD supplies the
exact current payload lengths, root title and recruits, and the selected phase
metadata. Save recomputes the current payload checksums without changing those
records. Filenames and generation metadata are regenerated, never taken from
editable content. Other phases' metadata and payloads come from the old
generation's files.

## Preconditions

`cf_save_entry` refuses (status 10) unless gameplay is stopped, the interrupt
priority is below 6, the source selector is zero, and the lifecycle is either
mode 0 with no snapshot tag or authoring mode 2 with the exact `SN` snapshot tag.
Custom-play mode 1 and inconsistent tags are refused before any file access.
Flags must be 0, 1 or 3, the phase count 1..6, the selected phase below it, and
resident CFMD valid. A new mission (flags 0) requires a phase count of one, zero
source fields, revision zero and a `$FF` first mapping.

The mode-0 direct API still requires the caller to own and freeze the supplied
authored buffers; it does not create an editor session or capture a campaign
snapshot. Keep the module and every named storage owner live until return. No
UI page, native briefing or overview, or module eviction may borrow these
buffers during the call, and only CANCEL may change.

## Transaction

1. Preflight (stage 2): qualify the directory, capture its catalog and choose a
   generation token not used by any existing filename (see
   [PREFLIGHT.md](PREFLIGHT.md)).
2. Without flag 1, choose the target mission ID: every schema-valid canonical
   manifest of 17..4,096 bytes is read and parsed; while one carries the target
   ID the ID is incremented and the scan restarts, at most 151 times (status 12
   after that).
3. Encode the new manifest (stage 3). With a source, the old manifest is read
   and must match the expected ID and body CRC (status 13).
4. Validate every target MAP/SPT pair structurally (stage 4) and add up the
   required quota units for every MAP, SPT and the manifest. Gameplay
   diagnostics do not block draft saves.
5. Run the preflight again (stage 5). The generation and the directory
   fingerprint must be unchanged (status 11). Refuse with 1 when fewer than
   `2n + 1` directory records are free and with 2 when the quota is too small.
6. Create each payload file under its new name (stage 6) and read it back with
   its exact length and whole-file CRC (stage 7). Payloads of the current phase
   are also compared byte for byte with memory. Unchanged phases are read from
   their old files with CRC checks, written from READBACK and read back again.
7. Create the manifest last (stage 8), read it back with its CRC, compare every
   byte and parse the selected phase again (stage 9).
8. Commit (stage 10): back up the resident metadata, install the new selected
   CFMD with a zero title reserve and check cancellation. A cancellation here
   restores the old metadata.
9. Set cleanup status 1 (pending), set READY = 1 and run generation cleanup
   (stage 11, see [CLEANUP.md](CLEANUP.md)).

Every file creation is verified by the file service itself (see
[WRITE.md](WRITE.md)). MAP, SPT and undo remain untouched on success and failure.

From step 1 to the first file write a dialog of the Slave's dialog service,
`Saving the mission` (`progress.s`), names the mission and says that the
screen stays dark while WHDLoad writes the files. It stays at least 25 fields
and closes before the first write and on every exit: WHDLoad keeps the display
dark during each write, and between writes the panel would only flash.

Only zero status with a fresh READY of one permits clearing the caller's dirty
state. Stage, byte counts and file counts alone are not commitment. The CFMI
fields at 60 and 84 hold **body CRCs**, not the reader's whole-file CRC, and
must never be interchanged with MAP/SPT reference CRCs.

## Results

Reader and file-service statuses keep their meanings from [READ.md](READ.md)
and [WRITE.md](WRITE.md). Capacity refusal uses 1 for a full directory and 2
for an exhausted quota; a failed host write returns 5. Negative parser, encoder
or payload statuses are interpreted with the stage and the corresponding library
contract. Diagnostic fields describe partial progress on failure.

A cleanup error is reported separately at offset 96: SAVE still returns zero
with READY = 1, keeping the published metadata. Show the cleanup warning
without blindly writing another generation. Private word 124 counts the files
removed by cleanup; it is not persistent across calls.

Cancellation is checked between file operations. It cannot retract a file
already created, and a late error can leave a complete-looking generation.
Keep authored data dirty in that case. An interrupted Save leaves the previous
generation intact; files of the incomplete new generation remain as orphans that
the browser's RECOVER view can remove.

## Memory

The whole image must fit the 16 KiB linker cap. READBACK is 15,096 bytes.
Serializer WORK 0..863 belongs to the file service, 864..991 to the encoder
state and 1,032..1,287 to one CFMD candidate. The old manifest uses READBACK
0..4,095 with 512-byte parser scratch at 4,096. New output uses manifest bytes
0..3,583; its tail 3,584..4,095 stages one SPT during validation. Accepted old
input may be 4,096 bytes; canonical output is at most 3,146 bytes.

The new-ID scan copies at most 150 catalog records to READBACK 10,240..15,039,
while each candidate manifest uses its first 4,096 bytes. That copy is dead
before encoding or payload I/O. Commitment keeps a 384-byte metadata rollback
copy at READBACK 6,144. After READY, cleanup reuses these buffers; the manifest
slice then holds old-generation canonicalization scratch, not the new manifest.
No second authored MAP, private stack, undo scratch or resident reserve is used.
