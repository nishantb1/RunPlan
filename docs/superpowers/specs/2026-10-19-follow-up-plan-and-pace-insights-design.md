# Follow-up plan and speeds that learn

Two additions picked from the improvement research of 2026-10-19:
- **Follow-up plan:** Couch to 5K users complain that the plan ends and leaves them alone.
- **Pace suggestions:** like Runna's Pace Insights, the app suggests a change and the runner
  accepts or declines it.

## Follow-up plan

When the plan has no next workout (every workout done or past), the Plan screen's "Plan
complete" line becomes a card.

- **Finale time:** the plan's last workout, if completed, has a recorded duration. Subtracting
  its timed non-run steps (the walking warm-up and cool-down) estimates the time for the goal
  distance. It is nil when there is no finale run or the estimate is not positive.
- **Options:**
  - **Get faster at <distance>:** same distance, 8 weeks.
  - **Build to 10K:** only after a 5K plan, 10 weeks.
  - **Something else:** today's Change plan.
- **The suggested profile:**
  - **Goal:** no goal time.
  - **Fitness:** `recentRace(distance, finale time)`, or `runsTwentyMinutes` without a finale
    time.
  - **Run days:** the same as the current plan.
  - **Start:** today.
- **Opening it:** the first two options open the change-plan screen filled in with that
  profile, so every answer, including the race time, can still be edited. Runs stay in history.

## Pace suggestions

- **Evidence:** each completed planned run with run steps, recorded after the plan's last
  suggestion was accepted or dismissed (`Plan.paceCheckedAt`), gives an actual run pace:
  - **Outdoors:** the tracker sums time and GPS distance while a run step is running. These are
    stored as `RunRecord.runSeconds` and `runMeters`.
  - **Treadmill:** the typed distance minus the non-run steps' planned distance at their
    target, over the planned run-step time. This counts only when the workout has no distance
    run step, every non-run step has a target, and the run lasted at least its planned time
    less 30 s.
  - **Target:** the run steps' combined target, total planned time over total planned miles.
- **Measured rule:** the latest 3 runs with evidence are all more than 15 s/mi off target in
  the same direction. The suggestion is their median offset, rounded to 5 s/mi and capped at
  30 s/mi.
- **Feeling rule:** checked only when the measured rule gives nothing. The latest 2 completed
  planned runs with run steps both felt Too easy (15 s/mi faster) or both Too hard (15 s/mi
  slower).
- **Card:** shows the current and suggested run speed, in mph and /mi, based on the plan's
  easy pace (`PaceCalculator` plus `Plan.paceOffset`), with **Update** and **Not now**.
- **Update:**
  - Every target in workouts not yet done shifts by the change, except walk targets (3.0
    mph).
  - `paceOffset` adds the change, so rebuilding for a too-hard run keeps it.
  - `paceCheckedAt` is set to now.
- **Not now:** only sets `paceCheckedAt`.

## Data

All new fields decode as empty from older saves:
- `RunRecord.runSeconds: Int?`
- `RunRecord.runMeters: Double?`
- `Plan.paceOffset: Int` (0 when missing)
- `Plan.paceCheckedAt: Date?`
