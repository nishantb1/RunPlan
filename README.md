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

- Start the sample workout in Treadmill mode: the step and speed are spoken.
- Beeps play at 3, 2 and 1 seconds before each change, over music.
- Lock the phone for two steps: cues keep playing and the screen is correct on unlock.
- Pause, skip forward, skip back and end all behave.
- Force-quit mid-workout and reopen: the app offers to resume, paused.
- Save the summary: the run appears under Recent runs after relaunch.
