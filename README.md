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

Installing needs `xtool auth login`. With a free Apple ID the app expires after 7 days; run
`xtool dev` again to renew it.

The iPhone stays connected to Windows (usbipd stalls at `[Connecting]`, xtool issue 19), and
WSL reaches it through iTunes' Apple Mobile Device service on port 27015. One-time setup in an
admin PowerShell, where `<wsl-ip>` is the `vEthernet (WSL (Hyper-V firewall))` IPv4 address:

```powershell
New-NetFirewallRule -DisplayName "WSL" -Direction Inbound -InterfaceAlias "vEthernet (WSL (Hyper-V firewall))" -Action Allow
netsh interface portproxy set v4tov4 listenport=27015 listenaddress=<wsl-ip> connectport=27015 connectaddress=127.0.0.1
```

Then, before each `xtool dev`, start the bridge in a second WSL terminal and leave it running:

```bash
sudo systemctl stop usbmuxd
sudo python3 tools/muxshim.py "$(ip route list default | awk '{print $3}')" 27015
```

`tools/muxshim.py` stands in for usbmuxd. xtool's bundled libusbmuxd only uses
`/var/run/usbmuxd`, and Apple's Windows service stops answering while a `Listen` request is
open, so the bridge answers `Listen` itself and forwards everything else. If WSL's address
changes after a reboot, rerun the `netsh` line with the new one.

## On-device checklist (guided workouts)

- Start a planned workout in Treadmill mode: the step and speed are spoken.
- Beeps play at 3, 2 and 1 seconds before each change, over music.
- Lock the phone for two steps: cues keep playing and the screen is correct on unlock.
- Pause, skip forward, skip back and end all behave (skip forward is dimmed on the last step; end
  with Stop).
- Force-quit mid-workout and reopen: the app offers to resume, paused.
- Save the summary: the run appears in the Runs tab after relaunch.

## On-device checklist (plan generation)

- Delete and reinstall the app (or start without a plan): onboarding appears.
- A 5K goal of 20:00 for a new runner shows the ambitious-goal warning, and "Train to finish
  instead" clears it.
- Save a plan: the Plan tab shows Today or Next on top and every week below.
- Open a workout, tap Edit, change its date and one step's speed, Save: the change shows, and
  survives a relaunch.
- Run a planned workout and save it: it gets a done mark and the week's count goes up.
- Plan tab > Change plan: onboarding opens with your answers filled in; Cancel changes nothing, and Replace plan asks first.

## On-device checklist (outdoor GPS)

- Start a workout outdoors for the first time: RunPlan asks for location, then waits for GPS and
  enables Start once it is ready.
- With location turned off in Settings: the start sheet explains and offers treadmill mode.
- Run with the phone locked: distance and the route keep recording, and cues keep playing.
- A distance step ends by itself when its distance is covered. To try it without the whole time
  trial, open the time trial, tap Edit and shorten its run step to about 0.25 mi.
- Each mile is announced with its split.
- Running more than 15 s/mi off a step's target pace for 30 s gives "Pick up the pace" or "Ease
  off the pace" (use a workout with a speed target, or add one in Edit). If cues rarely fire
  when you are clearly off pace, note it: GPS noise may be resetting the 30 s timer.
- Walk somewhere with no signal for over 10 s: the live screen shows the GPS warning and distance
  holds.
- Force-quit mid-run and reopen: resuming keeps the distance and route so far.
- Save the summary: it shows distance, splits and the route map, and the run appears in Runs.
- Plan tab > Free run > Outdoor: runs until ended, with no planned workout marked done.

## On-device checklist (history, progress and settings)

- History lists runs newest first; opening an outdoor run shows its splits and route map.
- Progress shows plan completion, the longest run, weekly distance bars (tap one for its miles)
  and, after two runs of at least 100 m, the pace trend (tap for a run's pace).
- Settings > Voice cues off: a workout keeps its beeps but says nothing, and music is not lowered.
- Settings > Keep screen awake off: the screen dims and locks as usual during a workout.
- Settings > Auto-pause outdoors on: stand still for several seconds and "Auto-paused" shows and
  is spoken; set off again and it resumes. A pause by hand stays paused.
- Settings > Change plan opens your answers; Reset everything asks first, then returns to
  onboarding with no runs.
