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
- **Poise (enemy hyper armor):** enemies flinch freely when idle, walking or recovering, but once a telegraph begins they have poise for the duration of that attack. Poise is per-attack: a heavier swing carries more. Chip it below zero and they are knocked off balance; fail to, and they swing through your pokes and hit you. Poise refills between attacks.
  - A **poise break** staggers them. It does NOT open a riposte — that is parry's reward alone, or parry stops being the greedy option and becomes a worse version of attacking.
  - A **parry** always breaks poise outright, whatever the value. Parry is the answer to a heavy attack you cannot poke through.
  - Exists because attack-spam beat everything: every hit cancelled the enemy's telegraph, so parry was never worth its risk. That is a pillar violation, not a balance nit.
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

### Setting (locked 2026-07-15)
**A collapsing mine. You go down for ore and relics while the shaft fails behind you.**

Why this and not the alternatives: it makes the greed pillar *literal* rather than
abstract. Deeper is richer and less stable, so "extract or push on" is a fact of
the fiction and not a rule bolted onto it. It also fits the Spelunky-style
daily-seed DNA the GDD already commits to.

What it settles:
- **Why you go:** the haul. Ore, relics, whatever is worth carrying up.
- **Why you leave:** the mine is failing. Depth is the timer.
- **Visual language:** rock, timber supports, ore veins, lantern light against
  cold dark. Warm = yours and safe; cold = the mine. Amber = value.
- **What the enemies are:** things that live down there, or things the digging
  woke. Not yet ruled on — that is a roster question for M6.

Still open, and NOT implied by this: death and extraction rules (question 2), the
meta shape (question 3), and the name (question 5). Locking the theme does not
lock those.

### Run structure
- Delve levels are procedurally assembled from hand-built rooms (rooms first, assembly logic later).
- Persistent hub between runs.
- An extraction decision exists mid-run.

### Death, extraction and meta (locked 2026-07-15)
The greed loop, in three decisions:

- **Haul.** You gather haul (ore, relics) as you descend. It is *carried*, not yet
  yours. Enemies drop it; the mine holds it.
- **Extract or descend, every room.** Each room's exit is the decision point. Going
  UP (to the surface) extracts: your carried haul is banked and the run ends safe.
  Going DOWN descends to the next room, richer and more dangerous. The choice is in
  your face at every exit — that IS the greed tension, and up/down maps to the mine
  fiction so it needs no explaining.
- **Death costs everything carried.** Die in the mine and you lose all carried haul.
  Only banked haul is yours. This is the sharp version on purpose: every room deeper
  is more at risk, and the collapsing shaft sells the stakes. (If playtesting proves
  it too punishing, a keep-a-fraction softening is the pre-agreed fallback — decision
  log entry required.)
- **The hub is a vendor.** Banked haul buys permanent stat upgrades that stack across
  runs — so the hub grows even when runs fail (pillar #5). M5 ships ONE upgrade (max
  health) to prove the loop; the rest is M6 content. Not crafting, not base-building
  in v1.

## Open questions
1. ~~**Theme and setting.**~~ **ANSWERED 2026-07-15 — see Setting.**
2. ~~**Death and extraction rules.**~~ **ANSWERED 2026-07-15 — see Death/extraction/meta.**
3. ~~**Meta progression shape.**~~ **ANSWERED 2026-07-15 — vendor with permanent upgrades. See above.**
4. **V1 scope line.** What ships in the first itch.io build.
5. **Name.**

## Decision log
- 2026-07-14: Genre locked: 2D delve-and-return action roguelite. Engine: Godot 4 + GDScript, static typing.
- 2026-07-14: Side-view locked over top-down. Platforming as combat expression.
- 2026-07-14: Input budget locked at ~10 verbs, controller-first discipline. KB+M layout locked, gamepad defaults provisional.
- 2026-07-14: Roll is never punished, no stamina in v1. Parry locked as the greedy pillar with riposte reward.
- 2026-07-14: Competition is async only: daily seeds, leaderboards, ghost replays. Real-time PvP permanently out of scope.
- 2026-07-14: Gray-box before art. Feel stack (buffer, coyote, hitstop, cancel windows) mandatory from Milestone 1.
- 2026-07-15: **Poise / hyper armor added**, Dustin's call after playtesting M4. Enemies keep swinging through pokes during a committed attack; light enemies have little poise, heavy ones a lot. Poise applies ONLY during telegraph/attack, so enemies still flinch when idle and combat stays at the Dead Cells pace rather than drifting to Dark Souls weight. A poise break staggers but gives no riposte; only a parry does. Reason: attack-spam trivially beat everything, which made parry decorative and broke its pillar status.
- 2026-07-15: Enemy attacks are data (`EnemyAttackData` resources) chosen by range, not one hard-coded swing. Folds the Dart's lunge in as a `dash_speed` value rather than a subclass — it turned out to be a number, not a verb. Adding an attack or an enemy variant is now a resource file.
- 2026-07-15: **Setting locked: a collapsing mine.** Dustin's call. You delve for ore and relics while the shaft fails behind you. Chosen because it makes the greed pillar literal — deeper is richer and less stable — rather than a rule sitting on top of an unrelated fiction. Unblocks art, which had been gated on this since M2's gate passed. Does not settle extraction, meta shape or the name.
- 2026-07-15: Key rebinding pulled forward from M7, Dustin's call after finding J/K awkward. The GDD's KB+M table stays the DEFAULT rather than the only option, so the locked layout is now a starting point players can override.
- 2026-07-15: **Run loop locked (M5), Dustin's call.** Gather carried haul in the delve; each room's exit offers extract (go UP, bank haul, end run safe) or descend (go DOWN, richer + deadlier). Death loses ALL carried haul — only banked is kept. Hub is a vendor selling permanent stacking stat upgrades; M5 ships one (max health). Chosen for the sharpest greed tension, which the collapsing-mine fiction already supports. Keep-a-fraction death softening is the pre-agreed fallback if it proves too punishing.
