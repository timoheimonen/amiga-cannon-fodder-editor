<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Storage Overlay

`storage.s` combines Custom-directory file reads, directory inspection, CFMI
parsing and MAP/SPT validation in one immutable 68000 CFMO module. Its identity
is `STG1`, filename `cf_storage.mod`, load base `EDITOR_MODULE_BASE` (`$0B11FA`)
and maximum image size 16 KiB. The build packages its body checksum and checks
the complete linked size.

Other storage documents:

- [READ.md](READ.md): Custom-directory file reads, inspection and the catalog
  snapshot.
- [MANIFEST.md](MANIFEST.md): strict CFMI parsing and pointer-free CFMD metadata.
- [PAYLOAD.md](PAYLOAD.md): structural checks, gameplay diagnostics and the CFVR
  result.
- [ENCODE.md](ENCODE.md): canonical CFMI encoding.
- [SAVE.md](SAVE.md), [PREFLIGHT.md](PREFLIGHT.md), [WRITE.md](WRITE.md) and
  [CLEANUP.md](CLEANUP.md): the separate `cf_save.mod` overlay.
- [DELETE.md](DELETE.md): verified file deletion shared by Save cleanup and the
  file-management views.

## Module Entry

`storage_module_entry` takes the module ABI: `D0.w = 2`,
`A0 = EDITOR_SESSION_BASE`. It accepts two callers:

- The mission browser: session mode 0.
- The custom-session controller: session mode 1 with the campaign-snapshot tag,
  the controller transaction tag, controller stage STORAGE, event OUTCOME,
  stopped gameplay, purpose PLAY, controller operation 1 or 2, and a target
  phase below 6 that equals the command block's selected phase.

Both require a `BRW1` version 1 browser record whose source selector
(`BROWSER_DATA_DRIVE`) is zero. A refused entry returns status 10 and leaves the
session request unchanged.

The entry clears composite READY, keeps the caller's 80-byte reader request on
the stack and qualifies the Custom directory with `storage_inspect_disk`. The
inspected `CFEDITOR` identity must equal the request's disk ID (status 11
otherwise). It then restores request bytes 0..47, clears result bytes 48..75,
leaves the live CANCEL field in place and runs `storage_entry`.

On return it stores the status, clears READY on failure, writes
`REQ_LAST_RESULT` and `REQ_RESULT_ID = STG1`, and requests a DISPATCH of
`cf_browser.mod` (`BROW`) in mode 0 or `controller.mod` (`CTRL`) in mode 1.

`storage_entry` is the direct service. It uses the fixed command block in
`storage.i`, not the generic A0 module context. D0.w returns the status;
D1-D7/A0-A6 and SP are preserved. Native briefing, overview, gameplay and other
storage users must be inactive throughout the call. No callback may consume
intermediate state or retain pointers into this overlay.

## Resident Command Block

Offsets are relative to `EDITOR_IO_BASE`. The resident dispatcher owns 0..63.
The storage allocation ends at 224 within the 512-byte I/O partition.

| Offset | Bytes | Meaning |
|---|---:|---|
| 64 | 80 | Reader request/result or CFSI inspection record; see READ.md |
| 144 | 2 | Command: 1 raw read, 2 inspect, 3 load and validate mission |
| 146 | 2 | Selected zero-based phase for command 3 |
| 148 | 4 | Composite READY, zero on entry, one only after success |
| 152 | 2 | Returned status |
| 154 | 2 | Stage: 0 direct operation, 1 manifest read, 2 parse, 3 MAP read, 4 SPT read, 5 payload validation, 6 publication |
| 156 | 2 | Mission phase count after successful initial parsing |
| 158 | 2 | Reserved, zero |
| 160 | 4 | Aggregate gameplay-error bits for completed phases |
| 164 | 4 | Aggregate review bits for completed phases |
| 168 | 32 | Most recently validated phase's CFVR result; selected phase on success |
| 200 | 16 | Private saved manifest name |
| 216 | 4 | Private manifest byte length |
| 220 | 2 | Private reserved word |
| 222 | 2 | Private current phase index |

`storage_entry` clears bytes 148..199 and 220..223 on entry. Only command,
selected phase and the reader request are caller inputs. During a call only the
request's CANCEL field may change. Stage and status together distinguish reader
errors from parser and payload negative codes. Diagnostic fields on failure
describe partial work, not a validated package.

Require both zero dispatcher status and composite READY = 1. A module-load
failure before entry cannot clear an earlier result, so the caller clears
READY before requesting dispatch.

Commands 1 and 2 adapt the reader and inspector without touching resident
metadata, SPT or the engine MAP. The caller initializes the request for each
operation; a CFSI result is not a read request. Unknown commands or a selected
phase outside 0..5 return status 10. A phase index beyond the actual phase count
is rejected by the parser. Both direct commands recheck CANCEL after the inner
call returns, so the inner READY can be one while composite READY stays zero.

## Mission Loading

Command 3 takes a canonical manifest filename and known nonzero disk ID in the
reader request. It sets the manifest capacity to 4,096 bytes and discovers its
exact length; any previous expected length or CRC in the request is ignored.
The CFMI envelope supplies its own body CRC and exact schema checks.

The complete manifest is kept in the 4,096-byte manifest slice. Every phase is
parsed and every referenced MAP/SPT pair is read with its exact length and
CRC, then structurally validated. Gameplay errors remain accepted draft data.
The selected phase is processed last, leaving its MAP in `map_file_buffer` and
its SPT in READBACK. Errors and reviews are ORed across all phases; the final
CFVR gives the selected phase's dimensions, object/troop counts and terrain pair.

Only after all phases pass structural checks does the module publish the
selected CFMD metadata and canonical SPT into their resident slices: 384 bytes
for metadata and 430 bytes for at most 43 ten-byte SPT records. The first 256
metadata bytes are CFMD and the remainder is zero. SPT bytes after the selected
length are zero. These records contain no overlay pointers. READY does not
authorize play when aggregate errors are nonzero, and no static result is TESTED.
Campaign isolation, recruitment bounds, policy adapters, terrain-resource
loading and gameplay entry are the controller's responsibilities.

## Ownership And Failure

The caller grants exclusive ownership of the inactive engine MAP buffer.
Loading uses that buffer as staging and can overwrite it before a later phase
fails, so command 3 must never run over the only unsaved authored MAP. The
caller first saves or explicitly discards that design and keeps engine consumers
disabled until it accepts the new composite READY. This is a file-loading
command, not an in-place validator for the current editor design.

The file service uses serializer WORK 0..863 and the directory cache. The
parser's 512-byte output reuses WORK 0..511 after each read. A separate
256-byte CFMD candidate at WORK 1,032 survives each read. After the manifest has
been copied out of READBACK, the parser uses READBACK 1,024..1,535 as its
512-byte scratch, and payload validation uses WORK 0..127. Neither workspace
survives the next read. The undo log, campaign snapshot, session state, UI
restoration record and guard reserve are not used.

After the final SPT read no more files are read. READBACK 512..895 and
1,024..1,453 temporarily hold the old resident metadata and SPT. New resident
bytes are staged while composite READY remains zero. The final CANCEL check
either publishes READY or restores both old slices byte for byte. Earlier
failures never modify those resident slices. The engine MAP, READBACK, manifest,
directory cache and serializer WORK remain unpublished scratch after failure.

CANCEL is checked at entry, before every file read, after each parse and
immediately before publication. Every file read is a complete file-service
transaction that rechecks the Custom-directory fingerprint and the `CFEDITOR`
identity before it returns.

## Combined Build

`read.s`, `manifest.s` and `payload.s` have no module header or includes of
their own: this wrapper supplies one header and the shared definitions. The
complete combined image must fit the 16 KiB serializer code partition, which
the source asserts.
