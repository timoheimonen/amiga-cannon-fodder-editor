# Changelog

## V1.1 09-10-2026

- Faster: the mission lists, Open mission, Check and the menu dialogs no
  longer read the whole `Custom` directory for every file, and the icon sets
  `WRITEDELAY=10`, so saving a mission takes seconds instead of most of a
  minute (raise it if your file system writes lazily).
- The mission lists check a mission when it is played or opened, not each
  time it is selected: moving through a list is instant and the list stays
  on screen.
- Choosing the Marker tool shows a hint in the information line instead of a
  message to click away. After a won phase, Return continues with the next
  phase. The phase settings return to Mission phases.
- Title entry starts with the title selected, so typing replaces it. Every
  list takes the arrow keys and a double click on a row for its main action.
- Deletion confirmations count files and saved versions.
- Dialogs work from the keyboard: an underlined letter chooses its button
  (the editor menu: N, T, O, S, A, R, P, X, E, C) and the cursor keys move the
  yellow frame that Return chooses. Buttons act when the mouse button is
  released over them, so a press can be taken back.
- Cancel returns to the map from every dialog the editor menu opened. The
  menu has Settings... for the mission and phase settings.
- A saved mission keeps its place in the lists; new missions are added at
  the end. The Template list turns pages and shows the position. Files starts
  at the mission selected in Open. The Resize confirmation names the objects
  and their cells. The game-disk prompt names the install's disk files.
- A Save names the mission before WHDLoad's dark writes. Opening a mission
  with the same terrain no longer reloads its graphics.
- The editor menu shows the version and the author under its title.

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
