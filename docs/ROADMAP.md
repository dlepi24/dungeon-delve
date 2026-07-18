# Roadmap

## Status
- **Round 10, 2026-07-17 (latest): stunlock killed, music variety, mine
  lighting.** Flinch fatigue (Dustin's fresh call on the long-deferred item):
  only flinch_limit interrupts per window, heavies get 2, pinned by
  enemy_test. Three delve music moods drawn per descent. The mine is now DARK:
  lantern on the player, glowing shrine altars, vignette — all procedural,
  tuning exports on MineAtmosphere in delve_run. Occasional branching (30%)
  replaced every-exit forking. **Graphics direction beyond lighting (asset
  packs vs commissioned pixel artist vs AI-generated + cleanup) is presented
  to Dustin and remains HIS M9 call — spec in the session log.**
- **THE VARIETY SESSION, 2026-07-17 (earlier). Dustin: "greatly vary it up,
  polish it as a game, perfect the first-time journey." All four chosen tracks
  landed:**
  - **Projectiles + ranged enemies**: Projectile extends Hitbox (parry
    REFLECTS it — double damage, stance break); Slinger (thrower, breaks
    tier-camping) and Gnat (flyer, contests high ground) join via seeded spawn
    variation. Ranged = projectile_speed on attacks; flight = can_fly on stats.
  - **Branching descent**: two seeded candidate rooms per depth; descending
    offers doors with flavour hints; choice writes into the plan; daily-seed
    safe. delve_test's stream-isolation replica updated to the new draw.
  - **FTUE**: first-run verb signs in the entry room, hub Training post ->
    gym (parry-signed, returnable, pausable), teaching result screens,
    one-time swap hint.
  - **Juice**: pad rumble laddered like hitstop, room-entry fades, camera
    dust, lantern flicker.
  - Also this day (earlier rounds): interact on A + device-aware glyphs +
    per-context music levels; extract fork needs a committed stick flick.
  - **Deferred, next variety batch (Dustin's queued picks)**: mine hazards
    (crumbling platforms, spikes, telegraphed debris — heat could shake more
    loose) and data-cheap elite variants. Then: hardware-judge the new
    enemies' tuning (slinger/gnat are first-guess numbers), heat curve, buff
    durations, M8 daily seed + leaderboard over run_history.jsonl, name +
    v1 scope (GDD questions 4/5).
- **Round 5 BUILT 2026-07-17 (late): MINE HEAT + blacksmith round 2 + shop UX.**
  - **Mine heat** (Dustin: "shouldn't be able to roflstomp"): each survived
    extraction toughens enemies (+12% hp, +10% dmg, more brute promotions per
    level, cap 8), pays more ore (+8%/level), and a +50% full-clear bonus lands
    for finishing all five rooms. Death cools it to zero. Persists in the save;
    shown in the HUD depth line and on the hub. Knobs: heat_* vars in
    GameState, clear_bonus_fraction on RunCoordinator.
  - **Blacksmith**: stock now rolls once per surface visit (close/reopen
    restock exploit fixed) and the smith HONES the weapon in hand (+15%
    dmg/poise, escalating cost, renames "+N"; session duplicate — the shared
    .tres never mutates, weapon_test pins it).
  - **Shop UX**: F and ESC close both stalls; walking away closes them.
  - Shrine spots added to entry + gap so altars can appear early ("shrines only
    pop up toward the end").
  - **Round 6 (same night): gamepad menu navigation.** Gameplay bindings
    existed since M0; now every menu grabs focus on open, stick/D-pad
    navigates, A accepts, B backs out one level (shops, settings->keybinds,
    pause, title confirm). UNTESTED ON HARDWARE — Dustin had no controller on
    hand. First pad session should check: stick deadzones in play, menu focus
    ring visibility, and whether the GDD's provisional button layout feels
    right. Controller GLYPHS (showing "A" instead of "SPACE") remain open.
  - Round 7 (same night): pad SELECT fixed — engine ui_accept/ui_cancel ship
    with no joypad buttons; project now overrides both (gate-pinned). Hints are
    device-aware: keyboard letters vs Xbox/Sony pad glyphs, flipping live.
  - **Session end. Next session candidates:** hardware gamepad test, playtest
    heat tuning (the heat_* knobs are first-guess values), buff durations,
    controller glyphs, M8 daily seed + leaderboard reading run_history.jsonl,
    and the remaining GDD open questions (v1 scope, name).
- **Round 4 BUILT 2026-07-17 (late): SHRINES + silent run history.** Design
  locked with Dustin in-session (all recommendations accepted): rest-of-run
  bargains, stacking, all three flavours (stat trade / pay-carried-ore /
  curse). Four .tres bargains ship; `S` glyphs in five middle layouts are
  candidate spots and the delve lights ~1 altar per run from the seeded
  stream. Boons show in the HUD buff column; the reserved red debuff column
  now shows banes. Every finished run also appends a silent JSON record to
  user://run_history.jsonl for M8's leaderboards — logging now, ranking later,
  per Dustin ("too early to care about leaderboards, but log if cheap").
  Tuning knobs for Dustin: shrine_chance on the Delve, the four .tres files.
- **M7 round 3 BUILT 2026-07-17 (evening), from Dustin's second playtest pass.**
  - Pause menu slimmed to Resume / Settings… / Quit to title; seed replay and
    abandon-run moved into the settings screen's run section (mid-run only).
  - **Pause now works in the hub** — it was only instanced in the delve. The
    pause menu lost its Delve export (restart rides the Events bus) and is a
    drop-in for any playable scene.
  - **Varok, the Overseer**: the miniboss is named, `is_boss` on EnemyStats,
    and engaging him raises a Souls-style named boss bar (bottom-centre,
    `Events.boss_engaged`). Announces once per fight, not per re-aggro.
  - **Variety pass** for "same exact levels all day": middle-room pool 4 -> 7
    (cavern / shaft / gallery, ASCII-authored, validator-proven), and spawn
    markers are now weight-class suggestions — a seeded stream swaps
    grunt<->dart and promotes toward brutes with depth. Entry room and the
    boss never vary. Same seed still = same delve (daily-seed safe).
  - Title music: already wired (main.gd plays the hub track); if it seems
    silent, the game was likely launched via F6/current-scene. Verify with F5.
  - Physics pin restored after another editor strip (9th).
- **M7 round 2 BUILT 2026-07-17 (same day), from Dustin's playtest notes.**
  Verdict on round 1 was "very fun" with a punch list; all of it landed:
  - Pause menu gained **Quit to title** (Souls-style; full app quit lives on the
    title). Forfeits carried haul like abandoning.
  - **Weapon swap is now ONE key** (Q toggles; E freed back to a future skill).
    HUD shows a Dead Cells-style big active-weapon square with the stowed one
    nested behind it. GDD decision log updated.
  - **Crude icon art baked** (tools/gen_icons.py, ASCII source of truth):
    pickaxe/dagger/maul/spear/ore/heart. WeaponData gained an `icon` export.
  - **HUD art pass**: heart + ore icons, panel backdrops, icon weapon squares;
    world pickups render their icons too (a ground Maul reads different from a
    Dagger).
  - **Weapons are now SESSION-scoped, Dustin's call**: extraction banks the
    loadout like haul; death or app-quit loses it. Never saved to disk.
    weapon_test pins it; GDD logged.
  - **The Blacksmith**: second hub vendor, rerolling random weapon stock each
    visit, prices on WeaponData. Same equip path as drops. Shields/parry gear
    was floated but is NOT designed — needs a session.
  - **The Overseer miniboss** guards the deep room (new EnemyStats .tres + `E`
    room glyph): unpokeable crush, long quake, a charge that answers sniping;
    340 HP, dies rich. Dart cut from that room.
  - **Title-screen mystery**: the scene is set as main_scene and boots clean —
    if it did not appear, the game was likely launched with "Run Current
    Scene" (F6) instead of "Run Project" (F5) / `godot --path .`. Quit-to-title
    now also reaches it in-game.
  - **Buffs already persist through doors** — only run start clears them. They
    are 6-8 s timers (src/systems/buffs/*.tres), so they usually EXPIRE before
    the next door and read as vanishing; duration is Dustin's tuning knob.
  - Deliberately not built, need Dustin's call: depth-scaled enemy stats,
    elite variants in mid rooms, shields/parry gear, buff-duration retune.
- **M7 product shell round 1 BUILT 2026-07-17, judged "very fun".** The game
  now boots to a title screen (Play/Continue, New-game-with-wipe-confirm,
  Settings, Quit, career stats, live-keybind controls line), runs fullscreen
  borderless with the cursor hidden during play, and ships the debug overlay
  OFF (F3 still toggles it; it absorbed the old dev delve HUD's seed/plan).
  One unified HUD (health, haul, weapon loadout, buff timers, room/depth, a
  reserved debuff column) replaced the four scattered pieces. Pickups now toast
  what you got (FloatingText + PickupFeedback over the previously-unconsumed
  signals, plus a new player_healed). New Settings autoload persists music
  volume and window mode in user://settings.cfg (deliberately outside the
  wipeable save); the settings menu embeds the keybinder and is reachable from
  title and pause. NEW MECHANIC (Dustin's call): in-run 2-weapon loadout —
  hold two found weapons, swap live on Q/E (skill slots repurposed, see GDD
  decision log), still run-scoped; swap blocked mid-swing to protect attack
  commitment. Career stats (runs/deepest/best extract/kills) persist and show
  on the title. All tests + the check gate green; weapon_test and loop_test
  extended to pin the loadout and the stats.
  - **For Dustin to judge by eye:** fullscreen + hidden cursor feel, title
    flow, HUD layout/readability, toast feel, swap feel (Q/E), settings
    persistence across restart.
  - Remaining M7 scraps: controller glyphs; gamepad bindings for menus are
    untested; the WASD controls wall was removed from the delve (verbs now live
    on the title screen + rebind screen — a first-run in-world hint is still open).
- **Previous: M6 content underway.** The full loop is proven fun but
  Dustin finds it repetitive after several loops. Landed 2026-07-17: combat-feel
  fixes (attack aim-assist, damage-taken numbers), the weapon upgrade now grants
  attack speed, temporary buffs (Haste/Might/Iron Skin/Frenzy), and WEAPON VARIETY
  (Dagger/Maul/Spear — run-scoped drops that reshape combat). Dustin picked weapon
  variety as the anti-repetition direction; it is built. Next: more enemies + an
  elite, and/or run modifiers — his call after playing.
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
- **Next step:** M6 content, Dustin's wishlist from the 2026-07-16 playtest:
  - Varied drops: coin tiers, hearts to heal, temporary buffs (star-power style).
    NOTE: hearts-to-heal is a DESIGN fork — in-run healing changes run pacing and
    interacts with his "heal 100% at hub" observation. Confirm before building.
  - More vendor upgrades: DONE for armor + damage; weapons-as-items is a bigger M6
    system (drop tables) still open.
  - MUSIC: placeholder synthwave DONE (tools/gen_music.py). Real track is M9.
  - **The repetition problem is the priority.** Same 3 enemies, 6 rooms, 3
    permanent upgrades every run. Highest-leverage fixes, roughly in order:
    (1) more enemy types + an elite/miniboss (data-driven, cheap); (2) ~~weapon
    variety~~ DONE 2026-07-17 (Dagger/Maul/Spear, run-scoped drops); (3) run
    modifiers / events (shrines, risk rooms, a real choice); (4) more/variable
    rooms. Weapons could also become vendor-buyable "start-with" unlocks (deferred).
  - Deferred by Dustin, do NOT touch without a fresh call: combat difficulty /
    stunlock (afraid of overcorrection), and heal-on-descend (he said it is fine,
    but flagged a Diablo-well alternative as a maybe-later).
- **Theme is LOCKED (2026-07-15): a collapsing mine.** Art is unblocked. The
  environment has had a first pass (rock/timber/ore tiles, lantern palette).
  **Character art is the remaining gap** — bodies are still ColorRect capsules,
  and real sprites/animation need either an artist or a decision to use generated
  assets. That is M9's pass and it is a resourcing question, not a coding one.
- **Scope pulled forward, on purpose:** the pause menu and key rebinding (M7) and
  seed entry (M8) exist now. Rebinding is real and persists; the rest are dev
  affordances. M7/M8 still own the full product shell — do not mistake these for
  those milestones being done.
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
  - **M5 questions are ANSWERED and built (2026-07-15):** lose-everything death, the
    exit is the extract/descend fork, vendor with permanent upgrades. See the GDD.
  - Remaining open GDD questions: 4 (v1 scope line) and 5 (name). Neither blocks the
    next build milestone.
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
**BUILT 2026-07-15, awaiting Dustin's call.** Design locked by Dustin (GDD): carried
haul is lost on death, banked on extract; each room's exit is the up=extract /
down=descend fork; the hub vendor sells permanent stacking upgrades (max health
ships). Economy pinned by tests/loop_test.tscn. The "one more run" judgement is
Dustin's. Note: normal descents use a fresh random seed; the daily-seed MODE is
still M8, but the determinism service underneath it is done and used here.

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
