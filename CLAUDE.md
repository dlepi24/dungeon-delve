# CLAUDE.md

## What this is
Untitled 2D side-view delve-and-return action roguelite. Dead Cells is the combat feel reference. Built by Dustin (first real game, learning game dev deliberately) with Claude Code implementing most systems.

## Source of truth
- `docs/GDD.md` holds all design decisions, feel spec values, and open questions. Read it before designing or implementing any gameplay.
- `docs/ROADMAP.md` holds milestones, exit criteria, and current status. Read it at session start. Update its Status section at session end, every session.
- Design decisions happen in claude.ai sessions with Dustin, then land in the GDD decision log. If code and GDD conflict, GDD wins. Flag the conflict instead of silently picking one.

## Tech
- Godot 4.x, GDScript only
- Static typing required on all variables, parameters, and return types
- Feature folders: each feature keeps its scene, script, and resources together (`src/player/`, `src/enemies/`, `src/systems/`)
- Never commit `.godot/`

## Hard rules
- Gray-box first. No art assets until the Milestone 2 exit gate. ColorRects and placeholder shapes only.
- All input goes through InputMap actions (`jump`, `roll`, `attack`, `parry`, ...). Never poll raw keys or buttons in code.
- All gameplay logic runs in `_physics_process` (fixed 60 tick). `_process` is visuals only. Determinism matters because daily seeds and ghost replays depend on it later.
- Every tuning value (speeds, timing windows, damage, cooldowns) is an `@export var` with a sane default. Dustin tunes in the inspector while playing, then final values get committed.
- Cross-system communication via signals. No reaching across the tree with `get_node("../../../")`.
- Content is data. Weapons, enemies, upgrades, and rooms are custom Resources (`.tres`). Adding content should mean adding a resource file, not editing a system.
- Collision layers are named and documented in the GDD. Never use raw layer numbers in code.

## Combat pillars (non-negotiable design intent)
- Roll is safe, always available, and fully viable with i-frames on good timing. Never punish rolling.
- Parry is the greedy option: tight window, big reward, punishable whiff. It is a design pillar, not a side mechanic.
- The feel stack is always on: input buffering, coyote time, hitstop, animation commitment with cancel windows. Starting values live in the GDD feel spec.

## Workflow
- Claude implements systems, scenes, and data files. Dustin playtests, tunes exported values, judges feel, and makes design calls.
- Propose a brief plan before non-trivial work (new system, refactor, anything spanning multiple files).
- After implementing anything playable, end with a short "How to test" note: which scene to run, what to try, what to feel for.
- Verify scripts parse via the headless CLI check before handing anything over (command below).
- Small commits, one feature or fix each, imperative commit messages.
- Dustin is learning game dev, not just receiving code. Give one or two sentences of "why" on each architectural choice as you go.

## Commands
Godot 4.7.1 installed via `brew install --cask godot`. Binary is on PATH at
`/opt/homebrew/bin/godot`; the editor app is `/Applications/Godot.app`.

- Open in editor: `godot --editor --path .` (or just open Godot.app)
- Run game from CLI: `godot --path .`
- Run a specific scene: `godot --path . res://src/main/main.tscn`
- Headless script/error check: `godot --headless --path . res://tools/check.tscn`
  - Exits 0 on success, 1 on failure. Run before every commit.
  - Verifies: all 13 InputMap actions bound, the 6 collision layer names, the
    `CollisionLayers` constants still matching those names, physics tick 60, both
    autoloads registered, main scene loads, and every script under `src/`,
    `tools/` and `tests/` parses.
  - It is a SCENE, not `--script`, and must stay that way: `--script` mode never
    registers autoload singletons, so `load()` on anything referencing `Events`
    fails with "Identifier not found" even though the game runs fine.
- Headless smoke run (boots the main scene and quits): `godot --headless --path . --quit-after 3`
- Seeded RNG determinism test: `godot --headless --path . res://tests/rng_test.tscn`
- Delve assembly test: `godot --headless --path . res://tests/delve_test.tscn`
  - Pins M4's exit criterion: same seed produces the same delve. Also checks every
    room's entry/exit is standable, which is a run-ending bug you otherwise only
    find by walking into it.
- Regenerate the tileset: `godot --headless --path . --script tools/gen_tileset.gd`
  (run twice on a clean checkout — the PNG must be imported before the TileSet can
  reference it). Regenerate rooms: `godot --headless --path . res://tools/gen_rooms.tscn`
  - Rooms are authored as ASCII in `tools/rooms/room_layouts.gd`. That is the source
    of truth; the `.tscn` files under `src/rooms/delve/` are generated output and a
    regen overwrites them. The generator validates first and refuses to build a
    broken layout.
- Enemy poise / AI test: `godot --headless --path . res://tests/enemy_test.tscn`
  - Pins the poise pillar: light enemies break in one poke, the Brute cannot be
    poked out of its swing at all, a parry always breaks poise, and a poise break
    gives no riposte. Attack-spam beating everything is a silent regression — the
    game still plays, it just stops being the game it is meant to be.
- Regenerate enemy data: `godot --headless --path . res://tools/gen_enemies.tscn`
  - A one-time BOOTSTRAP, not a pipeline. The `.tres` files under
    `src/enemies/data/` are ordinary resources — tune them in the inspector. Do
    not re-run this over tuned values; it exists because a typed
    `Array[EnemyAttackData]` is fiddly to hand-write correctly.
- Run-loop economy test: `godot --headless --path . res://tests/loop_test.tscn`
  - Pins M5's greed pillar: extract banks carried haul, death forfeits it, the
    vendor spends banked haul, and meta persists while run state does not. If any
    of that breaks, the whole game's tension is gone and nothing else catches it.
- Weapon variety test: `godot --headless --path . res://tests/weapon_test.tscn`
  - Weapons are WeaponData resources; the player's own exports are the base
    pickaxe, and equipping overrides them for the run (run-scoped). A new weapon is
    a `.tres`, added to the drop pool in `enemy.gd`.
- Feel stack behaviour test: `godot --headless --path . res://tests/feel_test.tscn`
  - Exits 0/1. Asserts coyote, input buffering and roll i-frames actually fire.
    Not a feel judgement — that is always Dustin's — just proof the mechanisms run,
    because all three fail silently and look like bad tuning when they break.
- After adding or renaming any `class_name` script, or adding any asset, run
  `godot --headless --editor --quit` once before the checks. Global class names
  only register when the editor scans the project, so a fresh run reports "Could
  not find type X" until then. New assets are the same story from the other side:
  a script that `preload`s a not-yet-imported file fails with "no resource loaders
  (unrecognized file extension)". Import first, then check.
- Regenerate character sprites: `python3 tools/gen_sprites.py`
  - Frames are authored as ASCII in `tools/sprites/player_frames.py` and
    `tools/sprites/enemy_frames.py` — those are the source of truth, same
    discipline as the rooms. Validates and refuses to bake a broken sheet. Writes
    the PNG by hand (zlib+struct), so no Pillow needed.
  - **Enemy art is GREYSCALE on purpose.** `BodyJuice` tints it from `EnemyStats`
    — idle colour, yellow wind-up, red swing, blue stagger, white flash. That tint
    IS the telegraph the GDD demands, so it has to survive the art. Pre-coloured
    enemy sprites would fight the tint and turn to mud. The player is full colour
    and is never base-tinted (`tint_sprite_with_base_colour = false`), only flashed.
  - Part heights must ADD UP to the canvas height and feet must land on the last
    row. Get it wrong and the character floats above the floor or wears its legs
    as detached stilts — both shipped once.
  - Animation names match the player's FSM state names lowercased. `PlayerSprite`
    reads the live state and plays it, so there is no second animation state
    machine to fall out of sync with the real one.
- Regenerate placeholder music: `python3 tools/gen_music.py` (dark synthwave loops,
  delve + hub). Synthesised like the SFX, reproducible, replaced by real audio at
  M9. The `Music` autoload forces the imported WAV to LOOP_FORWARD at runtime.
- Regenerate the placeholder SFX with `python3 tools/gen_sfx.py`. They are
  synthesised, not sourced — reproducible and unmistakably placeholder. Real audio
  is M9.

Gotchas found in M0/M1, worth not rediscovering:
- `godot --check-only --script foo.gd` exits 0 even on a syntax error. It is not a
  usable gate. `tools/check.gd` uses `GDScript.can_instantiate()` instead, which is
  the thing that actually goes false on a parse error (`load()` returns non-null
  even for a broken script).
- Autoloads do not exist in `--script` mode. Anything that touches `Events` must
  run as a scene. This is why both `tools/check.tscn` and `tests/feel_test.tscn`
  are scenes.
- An `Area2D` hitbox toggled via `monitoring` will miss a target that is already
  standing inside it, because `area_entered` only fires on a *new* overlap — the
  exact training-dummy case. `Hitbox` keeps monitoring on permanently and gates
  hits with a flag, sweeping `get_overlapping_areas()` when it opens.
- **Exported node references in hand-written `.tscn` files silently resolve to
  null** unless the node header carries `node_paths=PackedStringArray("prop")`:
  ```
  [node name="Hud" parent="." instance=ExtResource("1") node_paths=PackedStringArray("player")]
  player = NodePath("../Player")
  ```
  Without it Godot assigns the literal NodePath to a property expecting a Node,
  fails quietly, and leaves it null. **No error, no warning.** This killed every
  enemy telegraph colour, every hit flash and the whole F3 overlay for three
  milestones. If a node reference is a fixed child, prefer `@onready var x = $Child`
  and skip the export entirely — that is what `BodyJuice` and `Hitbox` do now.
- **A Control INSTANCED under another Control silently collapses to a 0x0 rect
  at the origin** unless the instance node declares `layout_mode = 1` plus its
  full anchor set — the packed scene root's own anchors are NOT enough. The
  editor writes these properties silently; hand-written `.tscn` files omit
  them. Under a CanvasLayer or Node2D parent the rule does not apply, which is
  why it hid for weeks: only the title screen's SettingsMenu/RecordsScreen and
  the KeybindScreen inside settings ever met the failing case. Symptom: the
  menu "opens in the top-left corner, half off-screen". Rule: instancing a
  Control scene under a Control parent? Restate layout_mode + anchors +
  offsets + grow on the instance node, always.
- **Node `_ready` order is a trap for group lookups.** Godot runs `_enter_tree`
  on every node in a scene before it runs any `_ready`, and `_ready` fires
  children-first, siblings in tree order. A node whose `_ready` runs before the
  Player's will not find it via `get_first_node_in_group("player")`. This shipped:
  the Delve sits above the Player in `delve_run.tscn`, so the Delve, every Room and
  every Enemy resolved a **null player** — enemies stood still, exits never fired,
  the player was never placed in the room, and nothing errored. Two defences now:
  the Player joins the group in `_enter_tree`, and every consumer resolves the
  player **lazily** rather than caching it in `_ready`. Anything that must touch
  another node's `@onready` state from `_ready` should `call_deferred` instead —
  that is why `Delve` defers its auto-start.
- `SceneTree.process_frame` is emitted *before* node `_process` runs, so
  `await get_tree().process_frame` resumes BEFORE the frame's `_process`. Awaiting
  it once and then reading a visual value reads the previous frame's state. Await
  twice. (`physics_frame` does not have this problem — it fires after.)
- Fade/decay effects should apply the visual and THEN decay, never the reverse: one
  long frame otherwise drives the effect to zero before it is ever drawn.
- Static typing is enforced by the engine, not by convention:
  `gdscript/warnings/untyped_declaration=2` in `project.godot` makes an untyped
  declaration a hard error, so the headless check fails on it.
- `ProjectSettings.save()` drops any setting equal to its engine default. The
  physics tick pin (60) is exactly such a value, so it carries a comment in
  `project.godot`. If the editor ever strips that line, put it back. (It already
  happened once, in M1.)
- `Input.action_press()` is not usable for testing `is_action_just_pressed()`. A
  synthetic press is invisible to `_physics_process` on the tick it is injected
  and surfaces around the *release* instead, so tests built on it pass and fail
  for unrelated reasons. Held state (`is_action_pressed`, `get_axis`) is fine, so
  simulated movement works. For one-shot verbs, drive `InputBuffer.press()`
  directly — see the note in `src/systems/input_buffer.gd`.
