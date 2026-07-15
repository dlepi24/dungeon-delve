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
- Headless script/error check: `godot --headless --path . --script tools/check.gd`
  - Exits 0 on success, 1 on failure. Run before every commit.
  - Verifies: all 13 InputMap actions bound, the 6 collision layer names, physics
    tick 60, both autoloads registered, main scene loads, and every script under
    `src/` and `tools/` parses.
- Headless smoke run (boots the main scene and quits): `godot --headless --path . --quit-after 3`

Gotchas found in M0, worth not rediscovering:
- `godot --check-only --script foo.gd` exits 0 even on a syntax error. It is not a
  usable gate. `tools/check.gd` uses `GDScript.can_instantiate()` instead, which is
  the thing that actually goes false on a parse error (`load()` returns non-null
  even for a broken script).
- Static typing is enforced by the engine, not by convention:
  `gdscript/warnings/untyped_declaration=2` in `project.godot` makes an untyped
  declaration a hard error, so the headless check fails on it.
- `ProjectSettings.save()` drops any setting equal to its engine default. The
  physics tick pin (60) is exactly such a value, so it carries a comment in
  `project.godot`. If the editor ever strips that line, put it back.
