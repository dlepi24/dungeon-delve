# Roadmap

## Status
- **Current milestone:** M0
- **Last session:** none yet
- **Next step:** execute M0

Update this section at the end of every session: date, what got done, what's next. Feel gates require Dustin's explicit sign-off, not Claude's judgment.

## M0: Scaffold
- Godot 4 project created with folder layout (`src/`, `docs/`, `assets/` reserved for later)
- Git initialized, `.gitignore` covering `.godot/` and OS junk, first commit
- All InputMap actions from the GDD input table defined and bound (KB+M plus provisional gamepad)
- Autoload stubs: `GameState`, `Events` (signal bus)
- Headless CLI check working, exact commands documented in CLAUDE.md Commands section
- Optional: Godot MCP server wired so Claude can run scenes and read output directly

**Exit:** an empty scene runs from both editor and CLI, repo is clean, commands documented.

## M1: Gray-box movement and combat core (find the fun)
- Player as a ColorRect capsule with an FSM: idle, run, air, roll, attack, parry, hitstun
- Movement: accel/decel curves, variable jump height, coyote time, input buffering
- Roll with i-frames, attack with commitment and a cancel-into-roll window
- Parry vs a training dummy that swings on a timer
- Every value from the GDD feel spec exposed as `@export`

**Exit gate (Dustin):** moving, jumping, and rolling around an empty room is fun by itself, before any enemy exists. Do not proceed until this is true. This gate is the whole project.

## M2: Feel pass
- Hitstop, screenshake, squash/stretch, hit flashes on placeholder shapes, placeholder sound effects

**Exit:** hitting the dummy feels crunchy. Art is now permitted going forward, but not required.

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
