# Beginner 5K plan

A new plan for new runners aiming at a 5K, modelled on Runna's New to Running plan and on the
0-to-5K programmes it competes with (NHS / Josh Clark Couch to 5K, None to Run), plus what
runners report about them on forums. It replaces the walk-run phase for 5K goals only; 10K
goals and runners who can already run 20 minutes keep the existing generator.

## What the research says

- **Runna New to Running:** 8 weeks by default (6-16), goal "run a 5k in one go". Walk-runs
  with "generous walking breaks"; each week "increase the running time, reduce the walking
  recoveries"; easy and very short recovery runs; later "simple, structured intervals ... at a
  slightly quicker pace, followed by a walk recovery". Third-party reviews call it a faster
  ramp than other beginner plans.
- **Couch to 5K (NHS / Clark):** 9 weeks, 3 runs a week with a rest day between. Week 1 is
  5 min brisk walk then 1:00 run / 1:30 walk for 20 min; it ends at 30 min continuous. Week 5
  run 3 jumps from 2 × 8 min (5 min walk between) to 20 min non-stop.
- **None to Run:** 12 weeks, starts at 8 × (0:30 run / 2:00 walk), ends at 25 min continuous,
  explicitly conservative.
- **Forums (r/C25K via mirrors and summaries, HealthUnlocked):**
  - W5R3, the first 20-minute run, is the most-cited wall.
  - Repeating a week is normal. The common rule is to repeat a run you could not finish.
  - Don't skip ahead when a week feels easy.
  - Almost everyone runs too fast. Treadmill users quote about 3.0 mph walking and 4-5.2 mph
    running.
  - Graduates can run 30 minutes but often not 5K, because 5K at a beginner's easy pace takes
    35-45 minutes.

No Runna week-by-week schedule is public, and X/Twitter and Reddit could not be read directly.
Reddit content came through search snippets and mirrors.

## Improvements over those plans

1. **Smaller walls.** Walks shrink as runs grow, and the last interval rung before continuous
   running is 2 × 10:00 with a 1:00 walk, not 2 × 8:00 with a 5:00 walk.
2. **5K, not 30 minutes.** Continuous rungs go up in 5-minute steps until the long run covers
   5K at the runner's easy pace, so the final 5K is not a leap past anything run before.
3. **Repeat instead of fail.** "Too hard", or ending a session early, holds the step.
4. **No skipping ahead.** "Too easy" is recorded but never speeds the plan up.
5. **Quicker intervals come late.** Runna's quicker intervals start only once the runner can
   run 20 minutes non-stop, and only with 3 or more run days.

## The ladder

| Step | Session | Running |
|---|---|---|
| 0 | 8 × (1:00 run / 1:30 walk) | 8 min |
| 1 | 7 × (1:30 / 1:30) | 10.5 min |
| 2 | 6 × (2:30 / 1:30) | 15 min |
| 3 | 4 × (4:00 / 1:30) | 16 min |
| 4 | 3 × (6:00 / 1:00) | 18 min |
| 5 | 2 × (10:00 / 1:00) | 20 min |
| 6+ | 20, 25, 30 ... min continuous | to the top |

- **Top step:** the 5K time at easy pace, rounded to the nearest 5 minutes and clamped to
  30-45. For the default 13:30 /mi it is 40 minutes.
- **Starting step:** new runners start at step 0, and "can run 5 minutes" starts at step 3.
- **Warm-up and cool-down:** every session has a 5-minute walk at each end.
- **Targets:** walks at 3.0 mph, runs at easy pace. They are treadmill speeds only.

## Spreading over the plan

- **Week kinds:** the last week is the final week, and every 4th week before it is a cutback.
  The rest are build weeks.
- **Build week steps:** with `B` build weeks starting at step `s` and top step `t`, build week
  `i` is at `min(s + round(i × (t - s) / (B - 1)), previous + jump)`. The jump is 2 from a
  run-walk step and 1 (5 minutes) from a continuous step, so a short plan may stop below the top.
- **Cutback weeks:** these repeat the previous build week's step.
- **The finale:** the 5K needs the final step to be within 2 of the top, so the long run is
  within 10 minutes of the 5K. Otherwise the plan ends with the long session.
  - 8 weeks from new: 0, 2, 4, 4, 6, 7, 8, 8. The long run reaches 35 minutes, then the 5K.
  - 12 weeks from new: reaches step 9, a 40-minute long run.
- **Minimum length:** onboarding asks new runners and 5-minute runners aiming at a 5K for
  at least 8 weeks. The generator still accepts any length and ends where the cap leaves it.

## A week

Run days are ordered Monday first.

- **First run day:** the main session at the week's step.
- **Middle days:** a recovery session. That is the step below for an interval step, or two
  thirds of the minutes for a continuous step, at least 15.
- **Last run day:** the long session. That is one extra repeat for an interval step, or 5 more
  minutes for a continuous step.
- **Quicker intervals:** at a continuous step with 3 or more run days, the main session
  alternates weekly with: 5 min walk, 10 min easy, 6 × (1:00 quicker at tempo pace / 2:00
  walk), 5 min walk.
- **Final week:** the other days are recovery sessions at the last build step. The last run
  day is **Run 5K non-stop** (5 min walk, 5K at easy pace, 5 min walk) when the finale rule
  above allows it. Otherwise it is a long session at the last build step.
- **Cutback weeks:** the last run day is the main session, without the long session's extra.

## Adapting

- **How did that feel?** The save screen adds Too easy / Just right / Too hard
  (`RunRecord.feeling`, optional). It is pre-set to Too hard when a planned session was ended
  early.
- **Hold:** saving Too hard on any workout in a ladder week (`Week.ladderStep` set) rebuilds
  every later week. The next build week repeats the held step, and the rest are spread from it
  as above, so the end date never moves. A later week holding a completed run is left
  untouched. Rebuilt weeks lose hand edits.
- **Push back a day:** this is on any planned workout not yet done. That workout and the
  later not-done workouts in its week move one day later. A workout that would leave its
  7-day week is dropped, except the plan's last workout.

## Data

- `Week.ladderStep: Int?` is new.
- `RunRecord.feeling: Feeling?` is new.
- Both decode as nil from older saves. Existing plans are unchanged.
