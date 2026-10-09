<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Custom File Creation

`write.s` is an include-only 68000 library that creates one new file in the
`Custom` directory through the Slave's file service (operation 3). The SAVE
overlay uses it. Include `layout.i`, `fodders.i`,
`storage_read.i` and `save.i` first, then include the library in the caller's
code section. It has no header, fixed origin, heap or user interface.

The library only builds a create request and forwards it. Choosing an unused
generation name, writing payloads before the manifest and recovering from a
partial save are the caller's responsibilities (see [SAVE.md](SAVE.md)).

## Calling Convention

Call `cf_write_entry` with JSR or BSR:

| Register | Input |
|---|---|
| A0 | Readable 16-byte NUL-padded canonical **new** filename |
| A1 | Immutable raw source |
| D1.l | Exact source length, 1 through 15,096 bytes |

D0.w returns the status. D1-D7/A0-A6 and SP are preserved; the final TST.W sets
Z on status zero.

The wrapper returns 10 without calling the service when native gameplay is
active, the interrupt priority is 6 or higher, `SAVE_CONTEXT` does not hold a
valid `SVR1` ABI 1 header of 128 bytes, or the length is zero or above 15,096.
When `SAVE_CONTEXT` is not defined at assembly time, the entry always returns 10.

## Request

The wrapper saves the 80-byte reader request at `EDITOR_IO_BASE + 64` on the
stack, then fills it with:

- the filename from A0;
- the disk ID from `SAVE_CONTEXT + SAVE_DISK_ID`;
- expected length D1 and capacity 15,096;
- zero CRC, flags, reserved word and result fields;
- CANCEL copied from `CF_WRITE_CANCEL`.

`CF_WRITE_CANCEL` is a readable longword, zero to proceed and nonzero to cancel.
Its default is `EDITOR_IO_BASE + 444`, the SAVE request's cancellation field;
define the symbol before inclusion to select another one. After the service
returns, the wrapper restores the saved request exactly.

## Service Behaviour

The file service qualifies the Custom directory and requires the `CFEDITOR` ID
to equal the request's disk ID (see [READ.md](READ.md)). It then checks:

| Status | Condition |
|---:|---|
| 10 | Invalid name or request, an existing file with the same case-folded name, or a source span outside the permitted owners |
| 1 | The directory already has 150 records |
| 2 | The file does not fit the remaining quota |

The source must lie wholly inside `map_file_buffer` (15,096 bytes), the resident
SPT slice, the manifest slice or READBACK. The service writes the exact bytes
with `resload_SaveFile`, reads them back in chunks of at most 512 bytes into
serializer WORK 320..831 and compares every byte (status 13 on a mismatch). It
then lists the directory again: the fingerprint must equal the expected
directory with exactly the new record added, and the marker must be unchanged
(status 11). A failed `resload_SaveFile` returns 5; a failed load returns 3.

Status 0 means the file exists with exactly the source bytes. The result fields
hold the length, whole-file CRC and disk ID, but the wrapper restores the
caller's request before returning, so they are not visible to the caller.

## Cancellation and Persistence

CANCEL is checked before every step until the file is written. A cancellation
requested later does not stop verification, but the final check before
publication still returns 14. The file may then already exist and be complete.

This is not an atomic transaction. An interruption between the write and its
verification can leave a complete or partial new file. Use unused generation
names, verify every file, write the manifest last and treat an error as
"unknown", never as proof that nothing was written.

## Other Labels

`cf_write_after_native`, `cf_write_return` and `cf_write_end` mark the service
return, the common exit and the end of the library. None of them is an
alternative entry point.
