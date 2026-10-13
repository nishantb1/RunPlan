# RunPlan

Personal running app for iPhone, built on Windows with [xtool](https://xtool.sh). Design:
`docs/superpowers/specs/2026-10-12-runplan-design.md`.

## Layout

- `RunCore/` is the logic: models, pace maths, workout engine, cues, storage. No UI code,
  unit-tested on Linux.
- `Sources/RunPlan/` is the SwiftUI app.

## Commands

Run inside WSL (Ubuntu app), from `/mnt/c/Users/bobba/Documents/RunPlan`:

```bash
cd RunCore && swift test      # unit tests
xtool dev build               # build xtool/RunPlan.app, no Apple login needed
xtool dev                     # build, sign and install to the connected iPhone
```

Installing needs `xtool auth login` and the iPhone attached to WSL. In an admin PowerShell:
`usbipd list`, then `usbipd bind --busid <id>` once and `usbipd attach --wsl --busid <id>`
each time the phone is plugged in. With a free Apple ID the app expires after 7 days;
run `xtool dev` again to renew it.

## On-device checklist (guided workouts)

- Start the sample workout in Treadmill mode: the step and speed are spoken.
- Beeps play at 3, 2 and 1 seconds before each change, over music.
- Lock the phone for two steps: cues keep playing and the screen is correct on unlock.
- Pause, skip forward, skip back and end all behave.
- Force-quit mid-workout and reopen: the app offers to resume, paused.
- Save the summary: the run appears under Recent runs after relaunch.
