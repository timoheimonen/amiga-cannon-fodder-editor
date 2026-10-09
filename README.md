# Cannon Fodder In-Game Level Editor

An in-game level editor for the Amiga game **Cannon Fodder**, as a WHDLoad
install for a hard disk. You build your own missions of up to six phases in
the game's own view, with the game's terrain, soldiers, vehicles and
buildings, test them at once, and play them from the recruitment hill like
the missions of the campaign.

`patch.py` makes the install from your own copy of the game: your images of
its three disks, which it identifies by their SHA-256. This repository holds
only the editor's and the slave's own code and the tools; it contains no game
files and no part of the game's code.

## Screenshots

![The recruitment hill with the EDITOR and CUSTOM disks](docs/screenshots/hill.png)

![The editor: the map view with the tool bar](docs/screenshots/editor-view.png)

![The Custom levels list](docs/screenshots/browser-custom.png)

More: [the tile page](docs/screenshots/tile-page.png),
[the object page](docs/screenshots/object-page.png),
[the mission's phases](docs/screenshots/phases.png),
[the phase settings](docs/screenshots/settings.png),
[Check](docs/screenshots/check.png),
[a test play](docs/screenshots/test-play.png),
[the briefing of a custom mission](docs/screenshots/briefing.png) and
[the mission in play](docs/screenshots/custom-play.png).

## Requirements

- An Amiga 1200 compatible machine (68020) with Kickstart 3.1, WHDLoad 17 or
  later, 2 MiB of chip memory and 4 MiB of fast memory. Tested on an emulated
  A1200 (68020, AGA, Kickstart 3.1, 2 MiB chip and 4 MiB fast memory); not
  tested on real hardware.
- Python 3.8 or later (for `patch.py`).
- [vasm](http://sun.hasenbraten.de/vasm/) `vasmm68k_mot` and
  [vlink](http://sun.hasenbraten.de/vlink/) (only for `build.py`).
- ADF images of the game's three disks with these SHA-256 hashes (the names
  are the ones these images are commonly catalogued under):

| Disk | Image | SHA-256 |
| --- | --- | --- |
| 1 | `Cannon Fodder (1993)(Virgin)(Disk 1 of 3)[cr FLT][f load - save FLT].adf` | `141601cc44ad57792710812d73052cd5d7f11ae203ac955ee61fbc8589a36825` |
| 2 | `Cannon Fodder (1993)(Virgin)(Disk 2 of 3)[cr FLT].adf` | `7f8cf28514f83f02fe421ccc8cc9dfdc134932eeabc7ba9f0a238e9d6486c9f5` |
| 3 | `Cannon Fodder (1993)(Virgin)(Disk 3 of 3)[cr FLT].adf` | `2d62a45de86737594b8b7d6a361f2fbce2624cfe7781208143d88ba2d07e417c` |

Other images are refused.

## Making the install

```sh
python3 patch.py "Disk 1.adf" "Disk 2.adf" "Disk 3.adf" --output CannonFodder
```

The images can be given in any order. `patch.py` checks every image and
every byte it changes before it writes anything, only reads the images, and
reads every file back after writing it. It creates the new directory
`CannonFodder`:

| Path | Contents |
| --- | --- |
| `CannonFodder.slave` | The WHDLoad slave |
| `CannonFodder.info` | The Workbench icon, with the tool types `PRELOAD NOWRITECACHE WRITEDELAY=10` |
| `Main.bin` | The game's main program from your disk 1 with the editor |
| `Disk.1`, `Disk.2`, `Disk.3` | Your disk images; the game only reads them |
| `SaveDisk` | The campaign save disk, formatted; keep it to keep your saves |
| `Custom/` | The editor's modules, its marker file `CFEDITOR` and your missions |

`--name` sets the name the editor shows for `Custom` (`CUSTOM LEVELS` by
default). Copy the directory to your hard disk and start the game from its
icon, or from the shell:

```text
WHDLoad CannonFodder.slave PRELOAD NOWRITECACHE WRITEDELAY=10
```

**F10** quits WHDLoad at once. A saved mission is never damaged by quitting;
unsaved changes are lost.

`patch.py` always writes a new directory and never changes an existing one.
To move your missions to another install, copy their files from `Custom` or
use the mission commands:

```sh
python3 patch.py list CannonFodder/Custom
python3 patch.py export CannonFodder/Custom 0123abcd.cmi --output MyMission
python3 patch.py import OtherInstall/Custom MyMission
```

`list` shows the missions with their titles and states, `export` copies one
complete mission to a new directory, and `import` adds it to a `Custom`
directory if no file of the same name exists and there is room. Do not run
them on an install the game is running from.

## Using the editor

The [user's guide](docs/manual.md) describes it all. In short: the
recruitment hill has two new disks between LOAD and SAVE. **EDITOR** opens
the editor's list of your missions: open one, or start a new one on an empty
map of any of the six terrains or from a phase of the original campaign
(Template); Files deletes missions. **CUSTOM** opens the list of missions to
play; each one is checked when you select it.

The editor works in the game's own view with a tool bar: paint tiles or fill
areas with the terrain of the phase's tile set, place, move and delete
soldiers, enemies, vehicles and buildings, set markers, and inspect a tile or
an object. The editor menu holds the mission's phases (up to six), each
phase's settings (objectives, enemy aggression, recruits' rank, grenades and
rockets, overview and countdown), Save as, Resize, Check and Test, which
plays the phase at once and returns to the editor. Undo reverses whole
operations, about the last 256. Save keeps the previous version of the
mission until the new one has been written and read back.

A custom mission plays like a campaign mission: the briefing, the phases,
your troops carried from phase to phase, and a result after each phase. Your
campaign is set aside while you edit or play a custom mission and comes back
exactly as it was; campaign saves with LOAD and SAVE work as in the original
game and are kept in `SaveDisk`.

## Limitations

- `Custom` holds at most 150 files, the editor's 18 included, and about
  950 KB of missions; a save that does not fit is refused before anything is
  written. Every file there must hold 1 to 65,535 bytes.
- The game reads `Custom` when it starts: restart it after changing `Custom`
  from outside the game. Keep only the editor's files and missions there.
- A mission has at most six phases; a map at most 7,500 cells.
- F10 quits at once, also with unsaved changes.

## Build

```sh
python3 build.py
```

Assembles and links the editor's resident, its seventeen modules and the
slave, and embeds them with the table of the editor's patches in the
generated section of `patch.py`, so that users of `patch.py` need only
Python. The build reads no game file: each patch site in the game's main
program is recorded by its length and the SHA-256 of the bytes expected
there, which `patch.py` checks against your disk 1 before it changes them.

## How it works

- `patch.py` unpacks the game's main program `FODDERC` from your disk 1,
  checks it, writes the editor's hooks into it and appends the editor's
  resident, which gives `Main.bin`.
- `src/whdload/slave.s`, the WHDLoad slave, runs `Main.bin` in its 1 MiB of
  base memory and replaces the game's floppy disk access: game files come
  from `Disk.1` to `Disk.3`, campaign saves go to `SaveDisk`, and the editor
  reads and writes files in `Custom` through the slave's file service. The
  slave also loads the editor's modules, draws the editor's text and dialogs,
  and stands in for the copy protection that WHDLoad cannot run.
- The resident (`src/editor/resident`), appended to the main program, takes
  over at the game's hooks: the recruitment hill, the start and end of play,
  the briefing, the phase settings and the keyboard. A custom mission or the
  editor runs in a campaign of its own; the player's campaign is kept in a
  snapshot and copied back on the return to the hill.
- The editor's screens and tools are seventeen overlay modules
  (`src/editor/modules`) that share one bank of memory and are loaded from
  `Custom` when they are needed. A mission is played and edited with the
  game's own routines: its maps, objects, graphics and gameplay are the
  game's.

## Docs

- The [user's guide](docs/manual.md).
- The [mission file format](docs/mission-format.md): the `.cmi`, `.map` and
  `.spt` files of a custom mission.
- The [architecture](docs/architecture.md): how the slave and the editor fit
  into the game engine.
- The changes by version are in [CHANGELOG.md](CHANGELOG.md).

## Author

Timo Heimonen <timo.heimonen@proton.me>

## Legal

Cannon Fodder is the property of its original rights holders (Sensible
Software / Virgin Interactive). This project is not affiliated with them.
The repository contains no game files and no part of the game's code; you
need your own copy of the game. The project's own code is released under the
[MIT License](LICENSE), which covers only this project's code, not the game.
