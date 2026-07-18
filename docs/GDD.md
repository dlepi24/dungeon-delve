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
| Skill 1 (weapon swap for now) | Q | LB |
| Skill 2 (unused for now) | E | RB |
| Interact | F | A / Cross (D-pad up also works) |
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
- 2026-07-17: **In-run 2-weapon loadout, Dustin's call (M7).** You hold up to two FOUND weapons and swap live; a pickup fills an empty slot or replaces the one you are NOT holding. Weapons stay run-scoped — lost on death or extract — so the roguelite model is unchanged. The existing skill_1/skill_2 actions (Q/E, LB/RB) are REPURPOSED as the two weapon slots rather than adding a new verb, keeping the ~10-verb budget intact; if real skills ever ship, weapon-swap needs its own binding and a fresh decision here. Swapping is blocked mid-swing on purpose: attack timings are read live, so a swap during recovery would act as a swap-cancel and erase the commitment attacks are designed to carry.
- 2026-07-17: **Persistent meta stats (M7).** GameState tracks total runs, deepest room reached, best single extract and total kills, saved with the meta save and wiped by New Game. Shown on the title screen — the game should remember you played it.
- 2026-07-17 (later): **Weapon swap is ONE key, Dustin's call after playing it.** Two slot-select keys read as nothing until a second weapon existed. Now skill_1 (Q) toggles between the two held weapons, Dead Cells backpack-style; skill_2 (E) returns to being a free slot for a future skill. HUD shows the loadout as a large active-weapon square with the secondary nested behind it.
- 2026-07-17 (later): **Weapons are SESSION-scoped, not run-scoped — Dustin's call after playing the loadout.** Coming out of the mine alive banks your weapon loadout like your haul: extract, shop, descend again, still armed. Death loses the loadout with everything else, and so does quitting the app (the stash is memory-only, never saved). Reason: losing a found Maul as the *reward for successfully extracting* punished the safe choice and fought the greed pillar. Permanent weapon ownership stays a non-goal; that pressure is routed to the blacksmith instead.
- 2026-07-17 (later): **Second hub vendor: the Blacksmith, Dustin's call.** Sells weapons for banked haul; the rack REROLLS a random subset of the weapon pool every visit, so the smithy is worth checking between runs and a run can start armed instead of gambling on drops. Bought weapons use the identical equip path as found ones — session-scoped, lost on death — so the smith sells a head start, not property. Stock rolls are plain (unseeded) randomness: hub flavour must not burn draws from the delve's seeded streams. Shields / parry gear came up in the same note but is NOT designed — needs a session before anything is built.
- 2026-07-17 (later): **Miniboss: the Overseer guards the deep room.** Dustin asked for a bigger end-of-run challenge as meta upgrades outpace the roster. Pure data (a new EnemyStats .tres + an `E` room glyph) per the content rule. Kit is the poise system examined: a 140-poise crush you must parry or roll, a long quake that punishes camping at mid range, and a charge that answers sniping. 340 HP, dies rich (guaranteed-ish heart, 50/50 buff and weapon, 30 ore). The Dart was cut from the deep room — a lunging add on top of a charging boss crossed from pressure into chaos. Deliberately NOT built yet, needs Dustin's call: depth-scaling enemy stats, and random elite variants of normal enemies in mid rooms.
- 2026-07-17 (round 3): **The Overseer is named — Varok, the Overseer — with a Souls-style boss bar.** Playtest: an unnamed miniboss read as another brute. EnemyStats gains `is_boss`; engaging a boss raises a wide named health bar bottom-centre (Events.boss_engaged). A boss announces itself once per fight, not on every re-aggro.
- 2026-07-17 (round 3): **Variety pass, Dustin's call ("same exact levels all day").** Middle-room pool widened 4 -> 7 (cavern, shaft, gallery). Spawn markers demoted from facts to weight-class suggestions: a seeded stream (Rng.stream("spawns")) may swap grunt<->dart and promotes toward brutes as depth rises. Entry room and the boss are exempt — the gentle opening and the guaranteed Overseer are promises. Determinism preserved: same seed, same monsters, so daily seeds stay fair.
- 2026-07-17 (round 4): **Shrines locked, Dustin's calls in session.** One altar-style shrine offers one bargain, rest-of-run duration (timed power stays the buffs' job), refusable free, STACKING if multiple are found. All three flavours ship in v1: stat trades, pay-carried-ore (converts at-risk loot into strength — the greed pillar in miniature), and curse trades (bane is a rule: harder spawns). Shrine spots are `S` glyphs in room ASCII; the delve lights ~1 per run from the seeded stream so daily seeds see identical offers. Pick-one-of-two offers are a possible later extension of the same data.
- 2026-07-17 (round 4): **Run history logged silently from now on.** Every finished run appends {date, seed, outcome, amount, room, kills} to user://run_history.jsonl (capped at 200, wiped by New Game). No UI reads it yet, deliberately — Dustin judged leaderboards premature, but records not written now can never be ranked later. M8's leaderboard/daily mode will read this file.
- 2026-07-17 (round 5): **Mine heat locked, Dustin's call ("shouldn't be able to roflstomp").** Every extraction survived heats the mine: enemies gain health (+12%/level) and damage (+10%/level), spawns promote toward brutes more often (+5%/level), capped at heat 8. Not punishing by design: heat also pays (+8% ore/level) and clearing all five rooms lands a +50% full-clear bonus, so the greed ceiling out-pays the caution floor. Death cools heat to zero — the streak itself becomes something you are afraid to lose, same emotional shape as carried haul. Persists in the save (it tracks the persistent upgrades it exists to counterweigh).
- 2026-07-17 (round 5): **Blacksmith round 2.** Stock rolls once per surface visit (the close/reopen reroll exploit is dead), and the smith gains a trade: HONING the weapon in hand (+15% damage/poise per level, escalating cost, renames to "+N"). Honing mutates a session duplicate — the .tres on disk is shared by every future drop and must never change; weapon_test pins that. Shop UX: F and ESC close the stalls, walking away closes them.
- 2026-07-17 (round 6): **Gamepad menu navigation wired.** Gameplay bindings existed since M0 (the provisional table); what was missing was the menu layer. Every menu now grabs focus on open, D-pad/stick navigates, A accepts, and B (ui_cancel) backs out one level — shops, settings->keybinds->host, pause, and the title wipe-confirm. The seed field is click-to-edit only so stick navigation cannot get trapped in it. Untested on hardware (no controller on hand); glyph art and the gamepad table's final layout stay open until Dustin plays it on a pad.
- 2026-07-17 (round 7): **Pad select fixed + device-aware hints.** Root cause of "can navigate but not select": Godot's DEFAULT ui_accept carries no joypad button (Enter/Space only; ui_cancel is Escape only) while ui_up/down do carry D-pad/stick — so menus half-worked on a pad. project.godot now overrides ui_accept (+A/Cross) and ui_cancel (+B/Circle), pinned by the check gate. On-screen hints are now device-aware: Keybinds tracks the last active device and hint_for() serves keyboard letters or pad glyphs (Xbox letters vs Sony shapes, sniffed from the controller name), flipping live. Text glyphs only — icon art is M9's. Still untested on hardware.
- 2026-07-17 (round 8): **Interact moved to A/Cross on pad (D-pad up kept as secondary), Dustin's call.** One button now means "engage": A interacts in the world, accepts in menus, dismisses results — the up/F split he could not parse is gone. Known accepted quirk: A near a stall also fires jump (both actions own the button; a hop while the shop opens is harmless in the safe hub). Fixed alongside: on pad, D-pad up inside a shop was BOTH navigation and interact, so browsing closed the shop — close-on-interact now excludes presses that double as ui verbs. Sony pads show shape glyphs (✕ ○ □ △); Xbox keeps letters. Music mix: per-context attenuation — title at full bed, hub -5 dB, delve -8 dB (exports on Hub/RunCoordinator).
- 2026-07-17 (round 9, the variety session — all four tracks Dustin's picks): **(1) Projectiles + ranged enemies.** Projectile extends Hitbox so the combat contract holds: rolls dodge rocks, and a PARRY reflects them — faster, double damage, guaranteed stance break. Ranged attacks are data (projectile_speed); flight is data (can_fly + hover_offset). The Slinger breaks tier-camping from across the room; the Gnat contests the high ground with paper health. Both enter via seeded spawn variation as same-weight alternates — never in the entry room. **(2) Branching descent.** Every middle depth seeds TWO candidate rooms; descending offers the doors with flavour hints (a hint, not a name). Choice writes into the run plan; same seed = same doors for everyone. **(3) FTUE.** First-run verb signs in the entry room, hub Training post into the gym (parry signage + return), result screens explain the economy, one-time swap-key toast. **(4) Juice.** Pad rumble laddered like hitstop, room-entry fades, camera dust, hub lantern flicker. Deferred from this conversation: mine hazards (crumbling platforms/spikes/debris) and data-cheap elite variants — next variety batch.
- 2026-07-17 (round 10): **Flinch fatigue — Dustin's fresh call on the deferred stunlock item.** Chaining flinches between attacks stunlocked everything heavier than a grunt. Only `flinch_limit` hits may interrupt per `flinch_window_ms` (default 4/1800; Brute and Overseer 2); further hits deal full damage but the enemy keeps acting. First hits always flinch, so "flinch freely when idle" holds — this kills only the infinite chain. Parry-stagger untouched. enemy_test pins it.
- 2026-07-17 (round 10): **Three delve music moods** (parameterized generator: original 96 BPM, moodier i-iv-v-VI at 84, driving i-VII-VI-v at 108), one drawn per descent with plain (unseeded) randomness — ambience never touches the seeded streams. **Mine lighting**: CanvasModulate darkness (mild — telegraph colours must survive), procedural lantern on the player, shrine altar lights, vignette; all runtime gradients, zero assets, everything exported. Real art direction (packs vs artist vs AI-generated) is still M9's decision — options laid out for Dustin.
- 2026-07-17 (round 11): **Weapon pickup rules locked, Dustin's call ("I keep losing my upgraded weapons").** Auto-equip only from the bare pickaxe. A free second slot auto-STOWS quietly — walking over loot never switches your hand. With a FULL loadout, a dropped weapon stays on the ground as an offer: "[A] Take X — drops Y", trading only on a deliberate interact and always replacing the STOWED weapon, never the hand. Honed blades can no longer be vacuumed away mid-fight. weapon_test pins all three paths.
- 2026-07-17 (round 12): **Pickup floor probe** — pickups (Areas) never collided with the world; the magnet masked it until full-loadout weapons stopped magneting and fell through the floor. Every falling pickup now settles on a ground raycast. **Auto-pause on controller disconnect** (skipped when the tree is already paused). **Juice round two**: roll afterimages + roll/landing dust, enemy death bursts in body colour, lantern flicker. All visual-only, unseeded, self-freeing.
- 2026-07-17 (round 13, "feel like an actual world"): **Camera zoomed to 1.45 and clamped to per-room bounds** — the world scrolls under you now (zoom_level export on FollowCamera; hub stays a wide diorama on purpose). **Room width is free**: the generator derives each room's size from its ASCII, and HALLS (116 cols, first double-wide) is in the pool. Height stays fixed at 18 — the jump-tier budget depends on it. **Music is a mix**: boss vamp on engage (returns to the interrupted mood on death/exit), 35% chance to drift delve variants per room change. OPEN DESIGN QUESTION for a session, Dustin's call: the traversal mechanic for bigger levels (Ori/Celeste-class movement) — candidates: flip allow_air_roll (the export exists, M1 open question), wall-slide+jump, or a Celeste-style air dash. Bigger rooms make this decision due soon.
- 2026-07-17 (round 14): **Every run guarantees ONE big room** (seeded depth, never branched — the centrepiece is not dodgeable). BIG_POOL is its own pool: halls + the new UNDERCROFT (double-wide, two storeys: covered lane below, walkable roof above, exit off the roof — the most Celeste-shaped room yet). Dustin's "I don't see a new level": one-in-three odds read as never; a guarantee reads as design.
- 2026-07-17 (round 15, the wow pass): **Parry shockwave + camera zoom-punch** on parry/riposte — pillar #3 says mastery is visible; now the game's most skilled input detonates. **Room-clear payoff**: new room_cleared event when the last living enemy in a room falls — gold CLEAR call, and every loose pickup vacuums to the player (weapon trade-offers exempt). The end of a fight is a shower of earnings.
