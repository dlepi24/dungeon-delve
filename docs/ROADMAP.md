# Roadmap

## Status
- **Current milestone:** M2 built, awaiting Dustin's "is it crunchy" call.
  **M1 PASSED in full** — the movement gate 2026-07-14 ("it's fun"), and the
  combat half the same day ("OKAY IT'S FUN, i can dodge through the guy and jump
  over him"). Movement and combat timings are approved as-is; do not change them
  without a fresh call from him.
- **Last session:** 2026-07-14. M0 scaffold complete (Godot 4.7.1 via Homebrew, 13
  InputMap actions, 6 named collision layers, tick pinned to 60, autoload stubs,
  `tools/check.gd` as a real negative-tested gate, static typing engine-enforced).
  Then M1 up to the gate: gray-box gym room, player FSM (idle/run/air/roll),
  accel/decel, variable jump, 100 ms buffer, 80 ms coyote, roll with i-frames over
  the middle 200 ms. Debug overlay on F3. `tests/feel_test.tscn` proves coyote,
  buffering and i-frames actually fire (9 assertions, all green).
- **Next step:** Dustin judges the M2 gate — does hitting the dummy feel crunchy?
  Knobs live on the Player inspector under Juice (hitstop frames, squash amounts)
  and on the gym's Camera2D (shake trauma). If it passes, art becomes permitted
  (not required) and M3 starts: 2-3 real enemies with their own FSMs and
  telegraphs, at least one built around parryable attacks.
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
  - Whatever tuned feel-spec values win should be written back into the GDD feel
    spec table, which still holds the untested starting values.
  - The GDD's five open questions (theme, death/extraction, meta shape, v1 scope,
    name) still block M5. M2-M4 do not need them. Worth a claude.ai design session
    within the next few milestones, not today.
- **Deferred:** Godot MCP server. No official or registry-listed server exists; all
  candidates are unvetted third-party code. The headless CLI already covers running
  scenes and reading output. Revisit only if tuning feel outgrows the CLI.
- **Resolved:** the editor-GUI check from M0 — the project has since been imported
  and run repeatedly, and Dustin ran the headless check himself.

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
**Built 2026-07-14, awaiting Dustin's call.** Note for later: hitstop is a freeze
flag on a physics-tick clock, NOT `Engine.time_scale`, because time_scale halts
physics stepping and the thaw could then only be timed in render frames — which
would desync the ghost replays M8 depends on. Any new gameplay system must opt in
by checking `Hitstop.is_frozen()`; one that forgets keeps moving through a freeze.

## M3: Enemies
- 2 or 3 enemy types with their own FSMs and clear telegraphs
- At least one enemy designed around parryable attacks
- Damage, health, death, and hurt states in both directions

**Exit:** a single room with 3 enemies is a genuinely fun fight.

## M4: Rooms and delve structure
- TileMapLayer setup, 6 to 10 hand-built rooms, room-to-room transitions
- Seeded assembly of rooms into a short delve (this is where procgen starts, using the central seeded RNG service)

**Exit:** a seeded 5-room delve is playable start to finish, same seed produces the same delve.

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
