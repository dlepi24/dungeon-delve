# Roadmap

## Status
- **Current milestone:** M4 PASSED. **M5 is design-blocked — that is now the
  critical path, and it is a design session, not a coding task.**
- **M0-M3 all PASSED.** M1 signed off 2026-07-14; M2 and M3 signed off 2026-07-15
  ("It's genuinely fun"), re-judged after the null-node-reference fix so the
  verdict was given against working telegraphs and counts. Movement, combat and
  juice values are all approved as-is — do not change them without a fresh call
  from Dustin.
- **Last session:** 2026-07-15. Built M4 (seeded RNG with independent streams,
  generated tileset with one-way platforms, six ASCII-authored TileMap rooms,
  seeded assembly, transitions). Dustin walked a full delve: **M4 PASSED**.
  His playtest then found a pillar violation — attack-spam beat everything —
  which produced the poise/hyper-armor system, attacks as `EnemyAttackData`
  resources chosen by range, and enemy jumping. See the GDD decision log.
- **Next step:** re-play the delve to judge poise. Then M5, which cannot start
  without the design session below.
- **Needs a design call from Dustin:**
  - `allow_air_roll` on the player, currently off. The GDD says roll is "always
    available" but never rules on mid-air, and air-rolling changes platforming a
    lot. Feel both, then it goes in the GDD decision log.
  - **GDD tension, interpreted but not ruled on:** roll is "always available" and a
    parry whiff is "punishable" cannot both be literally true — free roll cancels
    would erase the whiff punish. Implemented as: "always available" means no
    stamina or cooldown gating it, not that it cancels any state. So roll does not
    cancel parry recovery, and cancels an attack only inside its cancel window.
    A test pins this. If Dustin rules the other way, the test changes with it.
  - Tuned feel-spec values should be written back into the GDD feel spec table,
    which still holds the untested starting values.
  - **M5 IS NOW BLOCKED on the GDD's open questions.** M5 is the run loop: death,
    pickups, the extraction decision, a hub, one persistent upgrade. Open question 2
    (death and extraction rules) and question 3 (meta progression shape) ARE that
    milestone — there is no honest way to build it by guessing. This is the next
    thing on the critical path and it is a claude.ai design session, not a coding
    task. Questions 1 (theme), 4 (v1 scope) and 5 (name) can wait longer.
  - Placeholders M5 will replace: `Player.respawn_delay_ms` (death currently just
    puts you back), `Enemy.corpse_*` (no drops), and `Delve.auto_start` exists
    precisely so a hub can choose the seed before the run begins.
- **Deferred:** Godot MCP server. No official or registry-listed server exists; all
  candidates are unvetted third-party code. The headless CLI already covers running
  scenes and reading output. Revisit only if tuning feel outgrows the CLI.
- **Lesson worth keeping:** Dustin played two milestones without knowing attack was
  bound to J/LMB, so the combat gates were being judged on movement alone. Both
  rooms now show the controls on screen. State the verbs in the build, not in the
  handoff message.

Update this section at the end of every session: date, what got done, what's next. Feel gates require Dustin's explicit sign-off, not Claude's judgment.

## M0: Scaffold
- Godot 4 project created with folder layout (`src/`, `docs/`, `assets/` reserved for later)
- Git initialized, `.gitignore` covering `.godot/` and OS junk, first commit
- All InputMap actions from the GDD input table defined and bound (KB+M plus provisional gamepad)
- Autoload stubs: `GameState`, `Events` (signal bus)
- Headless CLI check working, exact commands documented in CLAUDE.md Commands section
- ~~Optional: Godot MCP server wired so Claude can run scenes and read output directly~~
  Deferred (2026-07-14): no official server exists, the CLI already covers it.

**Exit:** an empty scene runs from both editor and CLI, repo is clean, commands documented.
**Met 2026-07-14**, with the editor-GUI half awaiting Dustin's click (see Status).

## M1: Gray-box movement and combat core (find the fun)
- Player as a ColorRect capsule with an FSM: idle, run, air, roll, attack, parry, hitstun
- Movement: accel/decel curves, variable jump height, coyote time, input buffering
- Roll with i-frames, attack with commitment and a cancel-into-roll window
- Parry vs a training dummy that swings on a timer
- Every value from the GDD feel spec exposed as `@export`

**Exit gate (Dustin):** moving, jumping, and rolling around an empty room is fun by itself, before any enemy exists. Do not proceed until this is true. This gate is the whole project.
**PASSED 2026-07-14.** Dustin's words: "it's fun". Noted at the same time: the roll
reads as "moving but slightly different" — legible, but it has no visual identity
until M2's squash/stretch pass. Not a blocker, and deliberately not fixed early:
M2 cannot be judged ("hitting the dummy feels crunchy") until the dummy exists.

## M2: Feel pass
- Hitstop, screenshake, squash/stretch, hit flashes on placeholder shapes, placeholder sound effects

**Exit:** hitting the dummy feels crunchy. Art is now permitted going forward, but not required.
**PASSED 2026-07-15** ("It's genuinely fun"), re-judged after telegraphs were
fixed. Art is now PERMITTED but still not required — gray-box remains the default
until it stops carrying the design. Note for later: hitstop is a freeze
flag on a physics-tick clock, NOT `Engine.time_scale`, because time_scale halts
physics stepping and the thaw could then only be timed in render frames — which
would desync the ghost replays M8 depends on. Any new gameplay system must opt in
by checking `Hitstop.is_frozen()`; one that forgets keeps moving through a freeze.

## M3: Enemies
- 2 or 3 enemy types with their own FSMs and clear telegraphs
- At least one enemy designed around parryable attacks
- Damage, health, death, and hurt states in both directions

**Exit:** a single room with 3 enemies is a genuinely fun fight.
**PASSED 2026-07-15.** Interpreted "their own FSMs" as one
parameterised FSM plus `.tres` data, with subclasses only for genuinely different
verbs (DartEnemy lunges). Three copies of approach/telegraph/swing would have
broken the rule that new content is a resource file, not a system edit. If Dustin
wants literally separate FSMs, this is the place to say so.
**Geometry constraint discovered here:** a platform reachable from the floor
(109 px jump, 30 px thick) leaves ~50 px of headroom, which is less than the
player's 56 px body. Reachable platforms are STEPS; anything that walks under one
gets stuck inside it. M4's rooms need a taller vertical budget and a two-stage
climb for real overhangs.

## M4: Rooms and delve structure
- TileMapLayer setup, 6 to 10 hand-built rooms, room-to-room transitions
- Seeded assembly of rooms into a short delve (this is where procgen starts, using the central seeded RNG service)

**Exit:** a seeded 5-room delve is playable start to finish, same seed produces the same delve.
**PASSED 2026-07-15** — Dustin walked a full delve start to finish. Both halves pinned by tests
(`tests/delve_test.tscn` for reproducibility, a headless walk for playability).
Rooms are authored as ASCII in `tools/rooms/room_layouts.gd` and generated into
`src/rooms/delve/` — edit the ASCII, not the scenes. The plan is computed up front
from the seed rather than room by room, so nothing the player does can leak into
the layout; lazy generation would silently break daily seeds.

## M5: Run loop
- Death and restart, resource pickup, the extraction decision (design lands in GDD open question 2 first)
- Hub stub and one upgrade path that persists across runs

**Exit:** the full loop exists: hub, delve, extract or die, spend, go again. The one-more-run pull is real.

## M6: Meta and content
- Meta progression per the GDD decision once made
- More weapons, enemies, and rooms, all as resource files

## M7: Product shell
- Menus, pause, settings (key rebinding, volume), save system, controller glyphs

## M8: Competition
- Daily seed mode, local leaderboard, ghost replay recording and playback
- Online leaderboard later if wanted

## M9: Identity and ship
- Art and audio pass on the locked theme
- itch.io page, HTML5 + Mac + Windows exports

**Exit:** strangers can play it without you explaining anything. Ship it.

Ordering from M6 onward can shift after M5. This file is living, but M1's exit gate never moves.
