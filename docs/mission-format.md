# Cannon Fodder custom mission file format

08.10.2026 Timo Heimonen (timo.heimonen@proton.me)

This document describes the files of a custom mission of the in-game level
editor for the Amiga version of Cannon Fodder. A mission is a set of raw
files in the `Custom` directory of the WHDLoad install: one manifest
`gggggggg.cmi` and, for each phase, a map `ggggggggpp.map` and an object list
`ggggggggpp.spt`. The manifest is a 16-byte `CFMI` header followed by JSON
that holds the titles and settings and names the other files with their
lengths and CRC-32s. The map and the object list are the game's own formats
for a phase's terrain grid and its objects, stored unpacked. The document
gives every field, the values the editor and the game take, what the editor
writes, and the checks that decide whether a mission can be opened, played
or only reviewed. [`patch.py`](../patch.py) is the installer, which also
lists, exports and imports missions (see the [user's guide](manual.md)).
The terrain graphics are not in a mission's files: the game loads them from
its own disks by the names in the map.

What the editor writes into the fields is the editor's behaviour, not part
of the format. The notes on the editor describe editor version 1.0; a later
version that writes otherwise changes only those notes. The format itself is
version 1: `CFMI` version 1 with the schema `cannon-fodder-custom-mission-v1`.

## Overview

| File | Size | Content |
| --- | --- | --- |
| `gggggggg.cmi` | 17-4,096 bytes | The manifest: `CFMI` header, JSON body. See [the manifest](#the-manifest-cmi) |
| `ggggggggpp.map` | 96 + 2 x cells, at most 15,096 bytes | The phase's terrain: two tileset names, size, one word per cell. See [the map](#the-map-map) |
| `ggggggggpp.spt` | 10-430 bytes | The phase's objects: 10-byte records. See [the object list](#the-object-list-spt) |

*gggggggg* is the generation, eight lowercase hexadecimal digits; *pp* is
the zero-based phase number, two lowercase hexadecimal digits `00`-`05`. A
mission of *n* phases has 2*n* + 1 files. All multi-byte numbers in the
files are big-endian. Offsets are hexadecimal and count from the start of
the file. A phase file is used only through the manifest that names it with
its exact length and CRC-32, so a file changed without its manifest is
refused.

## The Custom directory

`Custom` holds the editor's own files (its marker `CFEDITOR` and its `.mod`
modules, 18 files) and the missions. The editor and `patch.py` refuse the
whole directory unless:

- it holds at most 150 files, the editor's 18 included;
- every name has 1-14 characters from `A-Z`, `a-z`, `0-9`, `.`, `-` and `_`;
- every file holds 1-65,535 bytes;
- no two names differ only in case;
- there is no file named `CFSDISK` (a campaign save disk's marker);
- `CFEDITOR` is present and intact: a 64-byte record that `patch.py` writes
  with the directory's name and a random identity. Do not change it.

`patch.py` also refuses subdirectories and links there. When the directory
breaks these rules, the hill shows `CHECK CUSTOM DIR` when EDITOR or CUSTOM
is clicked. The game reads `Custom` when it starts: restart it after changing
`Custom` from outside the game, and never change it while the game runs.

**The quota.** Besides the 150 files, `Custom` has a fixed quota of 1,872
units of 510 bytes (954,720 bytes). Every file in the directory, the
editor's own included, uses its size rounded up to whole units: a 666-byte
map uses 2 units. The editor's lists show the files and bytes left. The
quota is a limit of the editor, not the free space of the hard disk.

**Case.** Names are compared without regard to case (ASCII letters only):
a manifest's reference `0000004000.map` finds a file `0000004000.MAP`. The
editor writes every mission file name in lower case, the manifest's
references must be in lower case, and `patch.py list` and `export` expect
the manifest's own name in lower case. `patch.py export` and `import` write
the names in lower case. Write lower case.

**Other files.** A file whose name is not a mission name (eight hexadecimal
digits and `.cmi`, or ten and `.map` or `.spt`) is left alone by every
operation but counts toward the 150 files and the quota. Keep only the
editor's files and missions in `Custom`.

## Generations and mission IDs

A mission has two numbers:

- The **generation** names its files. Each Save writes a complete new
  generation under new names; the files of a generation are never changed
  once written.
- The **mission ID**, the manifest's `id`, says which generations belong to
  one mission. It does not appear in the file names.

**How a Save writes.** The editor:

1. picks the new generation: the lowest value from `00000000` upward that is
   not the first eight characters (in any case) of a file in `Custom`;
2. for a new mission and for Save as, picks the mission ID: it starts from 0
   for a new mission and from the source mission's ID for Save as, and counts
   up while any valid manifest in `Custom` has that ID. Save keeps the ID;
3. sets `revision` to 0 for a new mission and Save as, and to the old
   revision + 1 (after 65,535 comes 0) for Save;
4. refuses the Save before writing anything unless 2*n* + 1 files are free
   and the quota has room for all the new files, while the old generation
   still exists (`Could not save`);
5. writes every phase's map and object list under the new names, the phases
   that did not change copied from their old files, and reads each file back;
6. writes the manifest last and reads it back;
7. deletes every other complete generation with the same ID: for each, the
   manifest first, then its maps and object lists.

A generation is complete when its manifest is valid and every file it names
is present with the right length and CRC-32 and passes the
[structural checks](#structural-checks); errors of the
[gameplay checks](#gameplay-errors) do not matter. Save as writes a new ID,
so the mission it started from stays as it was.

**The current generation.** No file points to a current generation. Each
valid manifest in `Custom` is listed as a mission, and the files it names
are that mission's files. Because a Save deletes the other complete
generations of its ID, a mission normally has one manifest. When that last
step is interrupted, two manifests with the same ID remain and both are
listed; the revision numbers do not choose between them.

**Interrupted saves.** A Save that stops (a reset, F10, a power cut) before
its manifest is written leaves the previous generation intact and the new
payload files without a manifest. **Recover...** in the mission lists offers,
and deletes after a confirmation, every file with a mission name that no
valid manifest names:

- payload files of a generation without a valid manifest;
- damaged manifests;
- payload files under a valid manifest's generation whose phase number is
  not below its phase count.

A valid manifest protects itself and the files it names, even when one of
them is missing or damaged.

**Delete.** **Delete...** on a valid manifest deletes every valid manifest
with the same ID and every mission file under their generations. On a
damaged manifest it deletes only the files of that generation.

**IDs must be unique.** The editor treats every manifest with the same ID as
a generation of one mission: Delete removes them all, and a Save of one
deletes the others when they are complete. `patch.py import` does not
compare IDs. Give a mission written by hand an ID that no other manifest in
the target `Custom` has; a random one is best.

## The manifest (`.cmi`)

The file is a 16-byte header and a JSON body:

| Offset | Size | Field | Value |
| --- | ---: | --- | --- |
| `$00` | 4 | Magic | `CFMI` (`43 46 4D 49`) |
| `$04` | 2 | Version | 1 |
| `$06` | 2 | Header size | 16 |
| `$08` | 4 | Body length | The file's length - 16: 1-4,080 |
| `$0C` | 4 | Body CRC-32 | CRC-32 of bytes `$10` to the end |
| `$10` | Body length | Body | JSON, ASCII |

The file holds exactly 17-4,096 bytes, nothing after the body. The CRC is
CRC-32/ISO-HDLC, the CRC of ZIP and PNG and Python's `zlib.crc32`:
polynomial `$04C11DB7` reflected, initial value and final XOR `$FFFFFFFF`;
the CRC of the ASCII text `123456789` is `$CBF43926`. The header's CRC
covers the body only; the CRCs of the map and object list in the body cover
those whole files.

### JSON rules

The body is one JSON object of the [mission fields](#mission-fields). A
reader accepts only:

- ASCII bytes; whitespace only as space, tab, CR and LF;
- objects with exactly their listed keys, no key twice, in any order;
- integers as plain decimal numbers: no sign, fraction or exponent (`-0`,
  `1.0` and `1e2` are refused), within each field's range;
- `true` and `false` only in the boolean fields, `null` only in `countdown`;
- strings with the normal JSON escapes, judged by the characters they
  decode to.

**The canonical form.** The editor writes the body in one form, the one
Python's `json.dumps(value, sort_keys=True, separators=(",", ":"),
ensure_ascii=True)` gives: keys in ASCII order, no whitespace, `"` and `\`
as the only escapes in titles, arrays in their own order. A canonical
manifest is at most 3,146 bytes. The editor reads any body that keeps the
rules and writes the canonical form on its next Save. Write the canonical
form to get the same bytes as the editor.

### Mission fields

| Key | Type | Values | Meaning | The editor writes |
| --- | --- | --- | --- | --- |
| `schema` | string | `cannon-fodder-custom-mission-v1` | The format | That string |
| `id` | string | Eight uppercase hexadecimal digits | The mission ID, see [generations](#generations-and-mission-ids) | See the Save steps |
| `revision` | integer | 0-65,535 | Counts the Saves of the mission; never chooses between generations | 0, then + 1 at each Save |
| `title` | string | 1-63 printable ASCII characters, `$20`-`$7E` | The mission title, shown in the lists and the briefing. See [titles](#titles) | `NEW MISSION` in a new mission |
| `initial_recruits` | integer | 1-32,767 | The recruits available for the whole mission ("Recruits") | 15 in a new mission |
| `phases` | array | 1-6 [phase objects](#phase-fields) | The phases in the order they are played | One phase in a new mission |

The phase at index *i* of the array (from 0) is played as phase *i* + 1,
and its files are `gggggggg` + *i* as two lowercase hexadecimal digits. The
squad's soldiers, their ranks and the remaining recruits carry over from one
phase to the next.

### Phase fields

| Key | Type | Values | Meaning ("setting") | New mission |
| --- | --- | --- | --- | --- |
| `title` | string | 1-63 printable ASCII characters | The phase title. See [titles](#titles) | `PHASE 1` |
| `map` | object | See below | The phase's map file | |
| `spt` | object | See below | The phase's object list | |
| `objectives` | array | 1-8 distinct integers 1-8 | The [objectives](#objectives), in the order chosen | `[1]` |
| `aggression` | object | `minimum` and `maximum`, integers 0-20, `minimum` <= `maximum` | The lowest and highest enemy aggression: more aggressive enemies move faster and shoot sooner ("Aggression, up to") | 0, 0 |
| `new_recruit_rank` | integer | 0-7 | The rank of new recruits ("Recruit rank") | 0 |
| `grenades_per_troop` | integer | 0 or 2 | Grenades for each soldier at the start of the phase ("Grenades": None, 2 each) | 0 |
| `rockets_per_troop` | integer | 0 or 1 | Rockets for each soldier at the start of the phase ("Rockets": None, 1 each) | 0 |
| `enemy_grenades` | boolean | | Whether enemies throw grenades | `false` |
| `overview` | boolean | | Whether the overview map is available during the phase ("Overview map") | `true` |
| `countdown` | null or string | `null` or `original-final-map` | The countdown of the campaign's final mission. Needs `overview` false | `null` |

`map` and `spt` are objects with exactly these keys:

| Key | Type | Values |
| --- | --- | --- |
| `name` | string | `gggggggg` + *pp* + `.map` or `.spt`: the manifest's own generation, the phase's index, lower case |
| `length` | integer | The file's exact length: 1-15,096 for a map, 1-430 for an object list |
| `crc32` | string | CRC-32 of the whole file, eight uppercase hexadecimal digits |

The names in quotes are the labels of the editor's Mission and phase
settings dialog. A phase copied with Template gets the campaign phase's map,
objects, objectives, titles and settings.

### Objectives

| ID | Objective | Rule in the game |
| ---: | --- | --- |
| 1 | Kill all enemy | Every counted enemy must die |
| 2 | Destroy buildings | Every counted building must be destroyed |
| 3 | Rescue hostages | Every hostage must be brought to the rescue tent |
| 4 | Protect civilians | A civilian's death fails the phase |
| 5 | Kidnap enemy leader | The enemy leader must be brought to the rescue tent |
| 6 | Destroy factory | Shown in the briefing only: 1 and 2 decide when the phase is complete |
| 7 | Destroy computer | As 6, and the phase needs a computer to destroy |
| 8 | Get civilian home | A civilian must reach the civilian home |

A phase is complete when all its objectives are met. 4, 6 and 7 cannot end
a phase by themselves, so a phase needs 1, 2, 3, 5 or 8, and 6 and 7 need
both 1 and 2. Kill all enemy and Destroy buildings are met at once when there
is nothing to count. The editor keeps the objectives in the order they were
switched on.

### Titles

The format allows 1-63 printable ASCII characters, but the editor and the
game draw titles with the game's own fonts, which lack most of them:

- the editor's title entry takes `A-Z`, `0-9` and space, and only a title
  that fits 288 pixels of the hill's font and 320 pixels of the briefing's;
- the lists show lower-case letters in upper case, and a title they cannot
  draw as `UNSUPPORTED TITLE` or `TITLE TOO WIDE` (`LONG TITLE` in Open);
  such a mission can be edited but not played.

Write titles of upper-case letters, digits and spaces, and check their width
in the editor.

## The map (`.map`)

The map is a 96-byte header and the cells:

| Offset | Size | Field | Values | The editor writes |
| --- | ---: | --- | --- | --- |
| `$00` | 16 | Base tileset name | The [terrain pair](#terrain-pairs)'s base name, a NUL, then any bytes | The name with `.blk`, zero padding |
| `$10` | 16 | Sub tileset name | The pair's sub name, the same way | The name with `.blk`, zero padding |
| `$20` | 48 | Other | Not checked; write 0 | 0 in a new map; kept |
| `$50` | 4 | Signature | `cfed` (`63 66 65 64`) | `cfed` |
| `$54` | 2 | Width | Cells across, not 0 | 19 or more |
| `$56` | 2 | Height | Cells down, not 0 | 15 or more |
| `$58` | 8 | Other | Not checked; write 0 | 0 in a new map; kept |
| `$60` | 2 x cells | Cells | One word per cell, see below | |

The cells are stored row by row: cell (*x*, *y*) is the word at
`$60` + 2 * (*y* * width + *x*). A cell is 16 x 16 pixels, so the map is
width * 16 by height * 16 pixels.

**Size.** The file is exactly 96 + 2 * width * height bytes. Width and height
are not 0, and width * height is at most 7,500 cells, which makes at most
15,096 bytes. A map narrower than 19 cells or lower than 15 is a gameplay
error: the editor can open and save it, not play it. The editor's New and
Resize dialogs keep 19 x 15 and more and 7,500 cells at most.

### Terrain pairs

The two names select the terrain, whose graphics and tile data the game
loads from its own disks by these names. Only these six pairs are
supported:

| Base | Sub | The editor calls it |
| --- | --- | --- |
| `junbase` | `junsub0` | Jungle A |
| `junbase` | `junsub1` | Jungle B |
| `icebase` | `icesub0` | Ice |
| `desbase` | `dessub0` | Desert |
| `morbase` | `morsub0` | Moor |
| `intbase` | `intsub0` | Interior |

Each name is written in lower case exactly as shown, either alone or with
`.blk` (`junbase` or `junbase.blk`), and ends with a NUL inside its 16 bytes.
The bytes after the NUL are not checked; the editor writes zeros there in a
new map and keeps them otherwise.

### Cells

| Bits | Mask | Field | Values |
| --- | --- | --- | --- |
| 0-8 | `$01FF` | Tile | 0-398: a tile of the terrain pair. 399: no graphics, a review item. 400-511: an error |
| 9-12 | `$1E00` | Reserved | Write 0; set bits are a review item |
| 13-15 | `$E000` | Marker class | 0: no marker. 1-4: the classes the editor sets. 5-7: a review item |

The tile gives the cell's picture and how the game treats it (ground,
water, blocked and so on). The editor's tile page offers the 399 tiles
0-398 of each terrain.

**Markers.** A cell with a nonzero marker class is a marker. Markers are
invisible and can change where enemies see the squad. The game collects at
most ten marker cells, so more than ten is an error. The editor's Marker
tool steps a cell through classes 1-4 and changes only bits 13-15; Paint and
Fill change only bits 0-8. Classes 5-7 have no known use and are a review
item, and for classes 1, 2, 3, 5, 6 and 7, which change the game's line of
sight test, the Check asks for a test play.

## The object list (`.spt`)

The object list is a series of 10-byte records, with no header and no end
marker: the file's length gives the number of records.

| Offset | Size | Field | Values |
| --- | ---: | --- | --- |
| `$00` | 2 | Ignored | Not read by the game. The editor writes 0 |
| `$02` | 2 | Ignored | Not read by the game. The editor writes 0 |
| `$04` | 2 | X | Position across, see below |
| `$06` | 2 | Y | Position down in map pixels; the editor keeps 0 to height * 16 - 1 |
| `$08` | 2 | Type | The [object type](#object-types), `$00`-`$6E` |

**Records.** A phase has 1-43 records: the file holds 10-430 bytes, a
multiple of 10. The order of the records matters:

- people, vehicles, turrets and the helicopter call pad (the types marked
  *first 30* below) must be among the first 30 records, with their
  companion records;
- a type with [companion records](#companion-records) must be followed at
  once by exactly those records;
- the phase asks for one soldier for each active player soldier (`$00`)
  among the first 30 records; at least one is needed, and the whole list
  may hold at most eight active ones, the squad's size.

**X.** The game adds 16 to X (in 16 bits) when it loads the record. For an
active object X + 16 is its position across the map in pixels, so X is the
map position - 16. The editor places objects inside the map and not in its
first column of cells: map X 16 to width * 16 - 1, file X 0 to
width * 16 - 17. When X + 16 has its top bit set, the object is disabled:

| File X | X + 16 | Result |
| --- | --- | --- |
| `$0000`-`$7FEF` | `$0010`-`$7FFF` | An active object at map X = file X + 16 |
| `$8000` | `$8010` | Disabled. Allowed only for a companion record `$04` or `$29` of an active owner |
| `$FFEF` | `$FFFF` | Ends the game's object list: an error |
| `$7FF0`-`$7FFF`, `$8001`-`$FFEE`, `$FFF0`-`$FFFF` | Other | Disabled or wrapped: an error |

Y must be below `$8000` for an active object. A position past the map's
right or bottom edge (X or Y at least width * 16 or height * 16) is a review
item.

**What the editor writes.** A new object goes in as one bundle: the owner
with its X and Y, then its companion records, which get X `$8000` and Y 0
(the companion of type `$3C` gets the owner's X and Y instead). Both
ignored words are 0. A new mission has one record: a player soldier at the
map's centre. A phase always keeps at least one object.

### Object types

The editor's object page offers these 70 types. The checks accept every type
`$00`-`$6E`; the others are the game's internal objects (shots, explosions,
companion parts and so on). A `(?)` marks a description that is a best guess.
In the notes, *first 30* means the record must be among the first 30,
*counted* that the game counts it when it loads the phase, so it must never
be disabled, *enemy* and *building* that the Check counts it for objectives 1
and 2, and `+` the companion records that follow it.

| Type | Object | Notes |
| --- | --- | --- |
| `$00` | Player soldier | First 30, counted |
| `$48` | Hostage | First 30, counted; for objective 3 |
| `$05` | Enemy soldier | First 30, counted, enemy |
| `$24` | Enemy soldier with rockets (?) | First 30, counted, enemy |
| `$6A` | Enemy leader | First 30, counted; + `$29`; for objective 5 |
| `$0F` | Roof (?) | |
| `$14`, `$19`, `$58` | Door that enemies come out of (three kinds) | Building |
| `$64` | Reinforced door that enemies come out of | Building |
| `$18` | Hole that enemies come out of: invisible, the editor shows an H | |
| `$4A`, `$4B` | Door that civilians come out of (two kinds) | |
| `$4C` | Door that civilians with spears come out of | |
| `$49` | Rescue tent | For objectives 3 and 5 |
| `$5A` | Civilian home | For objective 8 |
| `$63` | Helicopter call pad | First 30 |
| `$6C`, `$6D`, `$6E` | Computer (three kinds) | Building; for objective 7 |
| `$28`, `$2A`, `$2B`, `$2C` | Enemy helicopter: grenades, unarmed, missiles, homing missiles | First 30, enemy; + `$04 $04 $29` |
| `$6B` | Enemy helicopter with homing missiles, second kind | First 30; + `$04 $04 $29` |
| `$31`, `$32`, `$33`, `$34` | Player helicopter: grenades, unarmed, missiles, homing missiles | First 30; + `$04 $04` |
| `$66`, `$67`, `$68` | Player helicopter that comes when called (?) | First 30; + `$04 $04` |
| `$3F`, `$40` | Player car, unarmed and with a gun (?) | First 30; + `$04` |
| `$41` | Player tank | First 30; + `$04` |
| `$45` | Enemy tank | First 30, enemy; + `$04 $29` |
| `$50`, `$51`, `$52` | Enemy car: unarmed, with a gun, other (?) | First 30, enemy; + `$04 $29` |
| `$4E`, `$4F` | Player turret (two kinds) | First 30 |
| `$54`, `$55` | Enemy turret (two kinds) | First 30, enemy; + `$29` |
| `$69` | Enemy turret with homing missiles (?) | First 30, enemy; + `$29` |
| `$0D`, `$11` | Shrub (two kinds) (?) | |
| `$0E` | Tree (?) | |
| `$10` | Snowman (?) | |
| `$12` | Waterfall (?) | |
| `$1B` | Dead soldier (?) | |
| `$25`, `$26` | Crate of grenades, crate of rockets | |
| `$36`, `$37` | Mine (two kinds) (?) | |
| `$38` | Spikes (?) | |
| `$3C` | Boiling pot (?) | + `$04`, at the owner's position |
| `$3D`, `$3E` | Civilian (two kinds) (?) | First 30 |
| `$46` | Civilian with a spear (?) | First 30 |
| `$53` | Hidden civilian (?) | First 30 |
| `$42`, `$43` | Bird flying left, bird flying right | |
| `$44` | Seal (?) | |
| `$5B`, `$5C` | Seal mine, spider mine (?) | |
| `$5D` | Rank bonus | |
| `$5E`, `$5F` | Rocket bonus, armour bonus (?) | |
| `$60`, `$62` | Bonus for the squad leader, bonus for the squad | |

### Companion records

A vehicle and a few other types take the records right after them as parts
of the same object. The owner must be followed at once by exactly these
types, in this order; the editor places, moves and deletes the whole bundle
as one object:

| Owner | Followed by |
| --- | --- |
| `$28`, `$2A`, `$2B`, `$2C`, `$6B` | `$04`, `$04`, `$29` |
| `$31`, `$32`, `$33`, `$34`, `$65`, `$66`, `$67`, `$68` | `$04`, `$04` |
| `$45`, `$50`, `$51`, `$52` | `$04`, `$29` |
| `$3C`, `$3F`, `$40`, `$41` | `$04` |
| `$54`, `$55`, `$69`, `$6A` | `$29` |

The whole bundle must end within the first 43 records, and for every owner
but `$3C` within the first 30. A companion record may be disabled (X
`$8000`); any other record with X `$8000` is an error.

## Checks

The checks have three levels. `patch.py` applies the same rules in `list`,
`export` and `import`.

### Structural checks

A mission that fails one of these cannot be opened, tested or played: Open
shows it as `Blocked`, or `Damaged` when the manifest itself fails, and a
damaged manifest can only be deleted. `patch.py list` shows it as
`INCOMPLETE`, and `export` and `import` refuse it.

| Rule | The Check says |
| --- | --- |
| The manifest keeps the [header](#the-manifest-cmi), [JSON](#json-rules) and field rules, and its name is `gggggggg.cmi` | (`Damaged` in the lists) |
| Every file the manifest names exists | (a read error, status 3) |
| Each file has the length in the manifest | `Wrong file length` |
| Each file has the CRC-32 in the manifest | `Checksum differs` |
| The map is at least 96 bytes, has `cfed`, a width and a height that are not 0, at most 7,500 cells and exactly 96 + 2 x cells bytes | `Map file damaged` |
| The map's names are a supported [terrain pair](#terrain-pairs), each ending in a NUL | `Terrain files differ` |
| The object list is a multiple of 10 bytes, and no type is above `$6E` | `Object file damaged` |

### Gameplay errors

A mission with an error can be opened, edited and saved, so that unfinished
work is never lost, but it cannot be played (`Invalid` in the lists), and a
phase with an error cannot be tested. The Check lists each one; `patch.py
list` shows the mission as `INVALID` with the number of errors.

| Check | Condition |
| --- | --- |
| `Map below 19 x 15` | Width below 19 or height below 15 |
| `Tile not in the terrain` | A tile number above 399 |
| `More than ten markers` | More than ten cells with a marker class |
| `Building parts missing` | An owner not followed by exactly its [companion records](#companion-records) |
| `Too many objects to draw` | An owner's bundle ends after record 43 |
| `Too many actors` | An owner's bundle (not `$3C`'s) ends after record 30 |
| `Object X ends the list` | X is `$FFEF` |
| `Disabled object alone` | X is `$8000` on a record that is not a `$04` or `$29` companion of an active owner |
| `Object X out of range` | X is `$7FF0`-`$FFFF` but not `$8000` or `$FFEF` |
| `Counted object disabled` | A type `$00`, `$05`, `$24`, `$48` or `$6A` is disabled |
| `Object Y is negative` | An active object has Y `$8000` or more |
| `Actor after slot 30` | An active *first 30* type after record 30 |
| `No player soldier` | No active `$00` among the first 30 records |
| `More than 8 soldiers` | More than eight active `$00` records |
| `No objective can finish` | None of the objectives 1, 2, 3, 5 and 8 |
| `Needs objectives 1 and 2` | Objective 6 or 7 without both 1 and 2 |
| `No computer to destroy` | Objective 7 without an active `$6C`, `$6D` or `$6E` |
| `No hostage or leader` | Objective 3 or 5 without an active `$48` or `$6A` |
| `No rescue tent` | Objective 3 or 5 without an active `$49` |
| `No civilian home` | Objective 8 without an active `$5A` |
| `Countdown needs no map` | `countdown` set and `overview` true |

### Review items

A review item does not stop play: it is something only playing can confirm.
Every phase has at least the review item `Play once to confirm`, because the
checks cannot prove that a phase can be won, so a mission without errors is
always `Review` in the lists (`Review: playable, some goals need a playtest.`
in the Custom levels list). `patch.py list` shows it as `REVIEW` with the
number of review items.

| Check | Condition |
| --- | --- |
| `Tile 399 has no graphics` | A cell uses tile 399 |
| `Reserved cell bits set` | A cell has any of bits 9-12 set |
| `Marker class 5 to 7` | A marker of class 5, 6 or 7 |
| `Marker affects sight` | A marker of class 1, 2, 3, 5, 6 or 7 |
| `Object outside the map` | An active object with X at least width * 16 or Y at least height * 16 |
| `No enemies at start` | Objective 1 and no active `$05`, `$24`, `$28`, `$2A`, `$2B`, `$2C`, `$45`, `$50`, `$51`, `$52`, `$54`, `$55` or `$69` |
| `No buildings at start` | Objective 2 and no active `$14`, `$19`, `$58`, `$64`, `$6C`, `$6D` or `$6E` |
| `Factory is only a label` | Objective 6 |
| `Several rescue tents` | Objective 3 or 5 and more than one active `$49` |
| `Civilian home untested` | Objective 8 |
| `Play once to confirm` | Always, in every phase |

"Active" means that X + 16 is below `$8000`. The Check runs over every phase
of the mission and shows the place of each item; the mission lists check
the selected mission when it is selected.

## Checklist for writing a mission

A mission that follows these rules opens, plays and passes the checks with
only review items:

1. Pick a generation that no file in `Custom` starts with (in any case) and
   an ID that no manifest there has.
2. Name the files `gggggggg.cmi`, `gggggggg00.map`, `gggggggg00.spt`,
   `gggggggg01.map` and so on, all in lower case, one map and one object
   list per phase, 1-6 phases.
3. Map: a supported terrain pair in the two 16-byte slots, `cfed`, width at
   least 19, height at least 15, at most 7,500 cells, the cells row by row;
   tiles 0-398, bits 9-12 zero, at most ten markers of class 1-4; zeros in
   the other header bytes.
4. Object list: 1-43 records of five words; the first two words 0; types from
   the [table](#object-types); one to eight player soldiers `$00`, at least
   one of them in the first 30 records; every *first 30* type in the first
   30 records with its bundle; each owner followed at once by its
   companions, which may have X `$8000` and Y 0; every other X in
   `$0000`-`$7FEF` (map X - 16) and Y inside the map.
5. Phase settings: 1-8 distinct objectives including 1, 2, 3, 5 or 8, with
   the objects they need; 6 and 7 only with 1 and 2; aggression 0-20 with
   `minimum` <= `maximum`; rank 0-7; grenades 0 or 2; rockets 0 or 1;
   `countdown` `null`, or `original-final-map` with `overview` false.
6. Titles of 1-63 upper-case letters, digits and spaces that fit the
   game's font; 1-32,767 initial recruits; `revision` 0.
7. The manifest's references: each file's name, exact length and CRC-32 in
   eight uppercase hexadecimal digits.
8. The manifest: the canonical JSON body, then the 16-byte header with
   `CFMI`, 1, 16, the body's length and its CRC-32.
9. Room in `Custom`: 2*n* + 1 free files and the quota.
10. Copy the files into `Custom` while the game is not running, or put them
    in a directory of their own and add them with `patch.py import`, which
    checks them first. Then start the game.

## Example

A one-phase mission on the Jungle A terrain: a 19 x 15 map whose cells are
all tile 0, one player soldier at the map's centre and one enemy soldier,
objective Kill all enemy, aggression 0-2, 15 recruits, the overview map on.
Generation `00000040`, ID `7A3C19E2`:

| File | Bytes | CRC-32 | Quota units |
| --- | ---: | --- | ---: |
| `0000004000.map` | 666 | `28E0BC02` | 2 |
| `0000004000.spt` | 20 | `6E3FEA6A` | 1 |
| `00000040.cmi` | 470 | | 1 |

The map, 96 + 2 x 285 bytes:

| Offset | Bytes | Content |
| --- | --- | --- |
| `$00` | `6A 75 6E 62 61 73 65 2E 62 6C 6B 00 00 00 00 00` | `junbase.blk`, zero padding |
| `$10` | `6A 75 6E 73 75 62 30 2E 62 6C 6B 00 00 00 00 00` | `junsub0.blk`, zero padding |
| `$20` | 48 bytes of `00` | |
| `$50` | `63 66 65 64 00 13 00 0F` | `cfed`, width 19, height 15 |
| `$58` | 8 bytes of `00` | |
| `$60` | 285 words `00 00` | Every cell tile 0, no marker |

The object list, two records:

| Record | Bytes | Content |
| --- | --- | --- |
| 0 | `00 00 00 00 00 88 00 78 00 00` | Player soldier, X 136, Y 120: map position (152, 120) |
| 1 | `00 00 00 00 00 F0 00 20 00 05` | Enemy soldier, X 240, Y 32: map position (256, 32) |

The manifest's body, shown here with line breaks; the file holds it in the
canonical form, one line of 454 bytes without spaces:

```json
{"id": "7A3C19E2", "initial_recruits": 15,
 "phases": [
  {"aggression": {"maximum": 2, "minimum": 0}, "countdown": null,
   "enemy_grenades": false, "grenades_per_troop": 0,
   "map": {"crc32": "28E0BC02", "length": 666, "name": "0000004000.map"},
   "new_recruit_rank": 0, "objectives": [1], "overview": true,
   "rockets_per_troop": 0,
   "spt": {"crc32": "6E3FEA6A", "length": 20, "name": "0000004000.spt"},
   "title": "PHASE 1"}],
 "revision": 0, "schema": "cannon-fodder-custom-mission-v1",
 "title": "FIRST STRIKE"}
```

The canonical body starts `{"id":"7A3C19E2","initial_recruits":15,` and
its CRC-32 is `D7093A40`, so the manifest's header is:

```text
43 46 4D 49  00 01  00 10  00 00 01 C6  D7 09 3A 40
CFMI         1      16     454          body CRC-32
```

In Python the header is `struct.pack(">4sHHII", b"CFMI", 1, 16, len(body),
zlib.crc32(body))`. The Check finds no error and the one review item `Play
once to confirm`; `patch.py list` shows the mission as `REVIEW`.
