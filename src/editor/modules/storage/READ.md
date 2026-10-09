<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Custom Directory File Reading

Custom missions are raw files in the WHDLoad install's `Custom` directory.
`read.s` gives the editor bounded access to them through the WHDLoad Slave's
file service. It does not decompress bytes or interpret mission, map or sprite
formats; an `RNC` prefix is ordinary file data.

The exported entries are:

| Entry | Use |
|---|---|
| `storage_inspect_disk` | Qualify the Custom directory and publish a CFSI record |
| `storage_read_entry` | Read one canonical mission file into READBACK |
| `storage_read_track` | Build a normalized catalog snapshot in the native track scratch |

It also supplies the shared helpers `read_valid_target`, `read_valid_name`,
`read_name_equal` and `read_crc32` (reflected IEEE CRC-32 over a positive byte
count in D1 starting at A0). Every module computes its CRCs through
`read_crc32`, which hands the range to the Slave's backend operation 12.

## File Service

`storage_inspect_disk` and `storage_read_entry` load the operation number into
D0 (1 inspect, 2 read) and jump through the resident backend veneer
`EDITOR_BACKEND_ENTRY` (`$0ADA24`). The Slave patches that veneer before the game
starts. It admits only a request at exactly `EDITOR_IO_BASE + 64`; any other A0
returns status 10 without touching memory. The same service also implements
create (operation 3, see [WRITE.md](WRITE.md)) and delete (operation 4, see
[DELETE.md](DELETE.md)).

D0.w returns the status with condition codes set from it. D1-D7 and A0-A6 are
preserved. The call is synchronous and non-reentrant.

## Request

The 80-byte request is defined by `storage_read.i`. All integers are big-endian.

| Offset | Bytes | Input or result |
|---|---:|---|
| 0 | 16 | Target filename, NUL-padded |
| 16 | 16 | Expected nonzero disk ID |
| 32 | 4 | Expected file length, or zero for bounded length discovery |
| 36 | 4 | Capacity, 1 through 15,096 and not below the expected length |
| 40 | 4 | Expected whole-file CRC-32/ISO-HDLC |
| 44 | 2 | Flags: bit 0 requires the expected CRC; other bits zero |
| 46 | 2 | Reserved, zero |
| 48 | 4 | Result length |
| 52 | 4 | Result whole-file CRC |
| 56 | 16 | Disk ID read back from `CFEDITOR` |
| 72 | 4 | READY: one only after all checks succeed |
| 76 | 4 | Nonzero requests cancellation |

The target must be `hhhhhhhh.cmi`, `hhhhhhhhpp.map` or `hhhhhhhhpp.spt` in
lowercase hexadecimal, with no nonzero byte after its terminator. `CFEDITOR`,
modules and other names are not readable through this entry.

For a valid request address, bytes 48..75 are cleared before any other check.
Read publishes the length, whole-file CRC, disk ID and READY. The file always
lands at `EDITOR_READBACK_BASE`; capacity only bounds its size.

| Status | Meaning |
|---|---|
| 0 | Success |
| 3 | Target absent, or the host could not load a file |
| 10 | Invalid request address or fields |
| 11 | Listing failed or exceeds 150 entries; missing, malformed or different `CFEDITOR`; campaign save present; directory changed during the call |
| 12 | Invalid name, case-folded duplicate, or empty or oversized file in the listing |
| 13 | Expected CRC does not match |
| 14 | Cancelled |
| 15 | File larger than capacity or different from a nonzero expected length |

Failure can leave a partial file in READBACK, but never publishes it. Require
both zero status and READY = 1. Length discovery does not accept empty files; a
discovery caller chooses a suitable capacity and validates the file's own format
and checksum, since transport success is not CFMI validation. Do not change
request fields during a call; only CANCEL may be updated.

## Directory Qualification

Every operation lists `Custom` with `resload_ListFiles` and rebuilds the
150-record directory cache at `EDITOR_DIRECTORY_BASE`:

- At most 150 entries. Each name is 1..14 characters from `A-Z`, `a-z`, `0-9`,
  `.`, `-` and `_`.
- Each file is 1..65,535 bytes long (`resload_GetFileSize`).
- Records are 32 bytes: the name, zero-padded to 16 bytes, and the size as a
  longword at offset 28. They are sorted by ASCII case-folded name; two names
  that fold to the same spelling are rejected (status 12).
- No `CFSDISK` campaign save may be present (status 11).
- `CFEDITOR` must be present with exactly that uppercase spelling and be
  exactly 64 bytes long (status 11).

The `CFEDITOR` marker is a 64-byte `CFDI` record:

| Offset | Bytes | Value |
|---|---:|---|
| 0 | 4 | ASCII `CFDI` |
| 4 | 4 | `$00010010` |
| 8 | 4 | Body length 48 |
| 12 | 4 | CRC-32/ISO-HDLC of bytes 16..63 |
| 16 | 16 | Nonzero disk ID |
| 32 | 32 | Name: 1..31 printable ASCII characters, NUL, zero padding |

Read, create and delete also require the marker's ID to equal the request's
disk ID. The directory fingerprint is the CRC-32 of a normalized 6,144-byte
image: a 32-byte header holding the label `cfdisk` and the record count as the
longword at offset 24, the 150 records, and zero padding. After the operation
the service lists the directory and reads the marker again; the fingerprint and
all 64 marker bytes must match before READY is published.

## Inspection

`storage_inspect_disk` qualifies the Custom directory without a known ID or
filename. It takes the request at `EDITOR_IO_BASE + 64`; only CANCEL at offset 76
is input, and bytes 0..75 are cleared on entry. On success it publishes this
pointer-free `CFSI` record:

| Offset | Bytes | Value |
|---|---:|---|
| 0 | 4 | ASCII `CFSI` |
| 4 | 2 | Version 1 |
| 6 | 2 | Record size 80 |
| 8 | 16 | Disk ID |
| 24 | 32 | Disk name, NUL and zero padding |
| 56 | 4 | Remaining quota in bytes |
| 60 | 2 | Free directory records, 150 minus the record count |
| 62 | 2 | Directory record count, including `CFEDITOR` and modules |
| 64 | 4 | Directory fingerprint |
| 68 | 4 | Reserved, zero |
| 72 | 4 | READY, one |
| 76 | 4 | Unchanged CANCEL input |

The quota is a fixed logical bound, not free hard-disk space. It starts at
1,872 units of 510 bytes; every listed file uses its length divided by 510,
rounded up. The remaining units times 510 are reported. Save admits a new
generation only when its files fit both the quota and the free records.

The qualified directory remains in the 150-record cache for immediate
enumeration. Copy names and sizes into owned storage before another storage call
or module eviction. Directory records are enumeration metadata only: they are
not permission to load or execute files without their own bounded validation.

## Catalog Snapshot

`storage_read_track` with `D2.w = 2` inspects the directory and then writes the
normalized 6,144-byte catalog image described above to the native track scratch
at `(sensi_track_scratch_pointer) + 20`. The record count is the longword at
offset 24 and the first 32-byte record begins at offset 32. Its CRC-32 equals the
inspection fingerprint. The 80-byte request at `EDITOR_IO_BASE + 64` is saved and
restored around the call. Any other D2, a zero or odd scratch pointer, or a
snapshot ending above `$100000` returns status 10. D0.w returns the inspection
status; all other registers are preserved.

## Ownership

| Region | Use during a service call |
|---|---|
| Serializer WORK 0..863 | Service state, marker copy and 512-byte verification buffer |
| Serializer WORK 864..1,287 | Untouched, including the CFMD candidate at 1,032 |
| READBACK | Read destination; a delete keeps a 4,800-byte directory copy at 0 |
| Directory cache | Rebuilt from the listing |
| Request, 80 bytes | Caller request, cancellation and result |

The Slave additionally owns its private 2,400-byte listing buffer. The metadata
parser must not run concurrently. Its 512-byte output does not fit the candidate
area: copy the selected 256-byte record to WORK 1,032..1,287 before a read and
leave it unpublished until the read and later format checks succeed. Undo and
manifest storage are unchanged, and no working pointer survives module eviction.

The directory cache at `EDITOR_DIRECTORY_BASE` is the engine's 150-record
directory cache. The service does not change the engine's directory count, so it
does not establish a valid engine cache: native named-file operations perform
their normal refresh.

CANCEL is checked before every listing, load and verification step. WHDLoad
transfers are not interrupted; a cancellation requested during one is observed
at the next check.

## Build

`read.s` is always part of a combining overlay, which includes `layout.i`,
`module.i`, `fodders.i` and `storage_read.i` once and supplies its own header.
`storage_read_start` and `storage_read_end` delimit the core.
