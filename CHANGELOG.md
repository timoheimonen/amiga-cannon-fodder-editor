# Changelog

## V1.0 08-10-2026

- The first release: an in-game level editor for Cannon Fodder, as a WHDLoad
  install for an Amiga 1200 compatible machine with Kickstart 3.1, 2 MiB of
  chip and 4 MiB of fast memory.
- `patch.py` makes the install from your own images of the game's three
  disks (identified by their SHA-256): the slave, the game's main program
  with the editor, your disk images, a formatted campaign save disk, the
  Workbench icon (`PRELOAD NOWRITECACHE`) and the `Custom` directory with the
  editor. It also lists, exports and imports missions.
- The recruitment hill has two new disks: EDITOR, the list of your missions
  (Open, New on an empty map or from a phase of the original campaign, Files
  to delete missions), and CUSTOM, the missions to play, each checked when it
  is selected.
- The editor works in the game's own view: tiles and Fill, objects with their
  vehicles' and buildings' companion records, markers, Inspect, Undo, up to
  six phases with their settings, Resize, Check and Test.
- Custom missions play like campaign missions, with the briefing, troops
  carried from phase to phase and a result after each phase; the campaign is
  set aside and restored exactly.
- Saves write a new version of the mission and read it back before the old
  one is removed; Recover deletes what an interrupted save left behind.
- Campaign saves use the game's own LOAD, SAVE and FORMAT screens on the
  install's `SaveDisk`.
