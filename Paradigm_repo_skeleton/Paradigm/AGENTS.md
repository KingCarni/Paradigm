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
