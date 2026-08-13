# Paradigm Agent Instructions

This repository is intended to be safe for work by Codex, Claude and human contributors.

## Before changing code

1. Read `README.md`.
2. Read `docs/TECHNICAL_DIRECTION.md`.
3. Read `docs/ARCHITECTURE.md`.
4. Read `docs/DEFINITION_OF_DONE.md`.
5. Read the Jira ticket in full and implement only its intended scope.

## Non-negotiable project direction

- Godot 4.x.
- GDScript unless explicitly changed by project decision.
- 3D gameplay and physics.
- Fixed / authored pinball camera, not free-roaming player camera.
- Windows/Steam first.
- Controller support is required from the beginning.
- Avoid platform-specific assumptions in gameplay systems so later console ports remain practical.
- Data-driven content: upgrades, enemies, encounters and balance values should not require core-code edits.

## Architectural rules

- Keep pinball physics code separate from roguelike/run logic.
- Components communicate through explicit signals/events or narrow interfaces.
- Do not create a god-object table manager.
- Keep scene scripts focused on the object they own.
- Shared systems belong under `scripts/systems/` or `scripts/core/`.
- Prefer Resources/data definitions for authored content.
- Avoid hard-coded absolute paths, user-specific paths, secrets and machine-specific state.

### Production table authoring — HARD RULE

`physics_spike.gd` is disposable prototype infrastructure. Its programmatic table-layout approach MUST NOT become the production table-authoring system.

- Production tables must be authored as editable Godot scenes/sub-scenes with visible transforms in the editor.
- Physical components such as bumpers, ramps, lanes, drains, walls, flippers and upgrade sockets must be placeable/tunable through scene instances and exported data rather than hard-coded world-position constants in a monolithic builder script.
- Reusable component behavior may remain scripted, but level/table composition belongs in scenes.
- The physics spike may continue using code-built geometry only until the scene-based authoring foundation replaces it.
- Do not add new production gameplay/content dependencies to `physics_spike.gd`.
- Before production table/content work proceeds, migrate the useful spike components into a scene-authored table foundation and retain the spike only as a disposable QA/prototype harness if useful.

## Physics rules

Pinball feel has priority over physical realism.

- Physics changes must be tested at the configured physics tick rate.
- High-speed collision behavior must be considered explicitly.
- Flipper behavior must remain deterministic enough to reproduce bugs.
- Do not silently cap ball speed unless documented and justified.
- Never add cosmetic effects that alter gameplay collision unintentionally.

## Completion notes

When completing a Jira ticket, report:

- files changed
- behavior implemented
- validation performed
- known limitations
- follow-up work discovered
