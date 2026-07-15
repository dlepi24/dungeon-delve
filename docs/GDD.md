# Game Design Document

Living document. Decisions get made in design sessions, then land here. The decision log at the bottom is append-only.

## Pitch
A 2D side-view action roguelite. You delve into procedurally assembled depths, fight with tight skill-based combat, gather resources, and decide how greedy to get before extracting. Back at a persistent hub, you spend the haul on gear and upgrades, then go deeper. Dead Cells combat feel, extraction greed tension, Spelunky-style daily-seed competition.

## Design pillars
1. **Tight, fair, readable combat.** Every death feels earned. Responsiveness at Celeste/Dead Cells standard.
2. **Greed tension.** Extract safe or push deeper is the core decision of every run.
3. **Mastery is visible.** A skilled run looks different from an average run. Parry-heavy play is the skill ceiling.
4. **Runs fit a session.** 20 to 40 minutes, with a deliberate one-more-run pull.
5. **Progress persists.** The hub grows even when runs fail.

## Locked decisions

### Perspective and genre
- Side-view platformer-action roguelite. Platforming skill is part of combat expression (spacing, verticality, air control).

### Input
Controller-first design discipline. Budget is ~10 verbs. No new core-combat verbs without a decision log entry.

| Action | KB+M (locked) | Gamepad (provisional, tune in playtest) |
|---|---|---|
| Move | WASD | Left stick |
| Aim up / ladders | W | Stick up |
| Jump | Space | A / Cross |
| Dodge roll | Shift | B / Circle |
| Primary attack | LMB or J | X / Square |
| Parry | RMB or K | Y / Triangle |
| Skill 1 | Q | LB |
| Skill 2 | E | RB |
| Interact | F | D-pad up |
| Consumables | 1 / 2 | D-pad left / right |

Consumables are never core combat. All bindings go through Godot InputMap actions so devices are interchangeable.

### Combat rules
- **Roll:** safe, always available, i-frames on good timing, never punished. No stamina in v1. Add a light stamina cost only if roll spam proves degenerate in playtesting, and only via a decision log entry.
- **Parry:** design pillar. Tight active window, deflects the incoming attack, opens a riposte. Whiffing has recovery frames and is punishable. Reward is speed and style. Roll-only play must remain fully viable.
- **Attacks:** animation commitment (weight) with defined cancel-into-roll windows. Where those windows sit is a primary tuning knob.
- **Enemies:** telegraph everything. Readability over surprise.

### Feel spec (starting values, Dustin tunes everything in-editor)
| Parameter | Start value | Notes |
|---|---|---|
| Physics tick | 60/s fixed | Gameplay in `_physics_process` only |
| Input buffer | 100 ms | Queued inputs fire when legal instead of dropping |
| Coyote time | 80 ms | Jump remains valid briefly after leaving a ledge |
| Jump | Variable height | Release early to cut the jump |
| Roll | ~350 ms total | I-frames cover roughly the middle 200 ms |
| Parry active window | 120 ms | Whiff recovery ~300 ms |
| Hitstop | 3 frames normal hit, 6 on parry | Half of "crunchy" lives here |

Screenshake, squash/stretch, and flashes arrive in Milestone 2.

### Competition model
- No real-time multiplayer, period. Netcode is out of scope.
- Async competition: daily seed runs, leaderboards, ghost replays. Local first, online later if wanted.
- Determinism requirements: seeded RNG through one central service, all gameplay on the fixed tick, ghosts stored as recorded inputs.

### Content architecture
- Data-driven via custom Resources (`.tres`): weapons, enemies, upgrades, rooms.

### Collision layers (initial, may extend in M1)
| # | Name |
|---|---|
| 1 | World |
| 2 | Player |
| 3 | Enemy |
| 4 | PlayerAttack |
| 5 | EnemyAttack |
| 6 | Pickup |

### Run structure
- Delve levels are procedurally assembled from hand-built rooms (rooms first, assembly logic later).
- Persistent hub between runs.
- An extraction decision exists mid-run. Exact mechanism is open (see below).

## Open questions
1. **Theme and setting.** What are we delving into and why. Drives art, naming, and motivation. Next design session topic.
2. **Death and extraction rules.** What you keep, what you lose, how extraction works mechanically.
3. **Meta progression shape.** What the hub does: vendor, crafting, base-building, or a mix. What persists.
4. **V1 scope line.** What ships in the first itch.io build.
5. **Name.**

## Decision log
- 2026-07-14: Genre locked: 2D delve-and-return action roguelite. Engine: Godot 4 + GDScript, static typing.
- 2026-07-14: Side-view locked over top-down. Platforming as combat expression.
- 2026-07-14: Input budget locked at ~10 verbs, controller-first discipline. KB+M layout locked, gamepad defaults provisional.
- 2026-07-14: Roll is never punished, no stamina in v1. Parry locked as the greedy pillar with riposte reward.
- 2026-07-14: Competition is async only: daily seeds, leaderboards, ghost replays. Real-time PvP permanently out of scope.
- 2026-07-14: Gray-box before art. Feel stack (buffer, coyote, hitstop, cancel windows) mandatory from Milestone 1.
