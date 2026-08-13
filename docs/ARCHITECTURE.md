# Architecture

## Layering

### Core
Owns application lifecycle, global event vocabulary and non-game-specific utilities.

### Pinball
Owns the physical table: ball, flippers, bumpers, ramps, targets, drains, launch lane and table bounds.

### Systems
Owns run progression, combat, upgrades, table evolution, persistence and other cross-scene gameplay systems.

### UI
Displays game state and forwards player UI intent. UI does not own authoritative gameplay state.

### Data
Authored Resources / data files describe components, upgrades, enemies, encounters, biomes and balance.

## State ownership

- Ball runtime state belongs to the ball / active-ball service.
- Table geometry and installed-component state belongs to table state.
- Encounter combat state belongs to combat/encounter systems.
- Run path, rewards and run resources belong to run state.
- Persistent unlocks/settings belong to persistence/meta systems.

## Production table authoring

Production pinball tables are scene-authored, not generated from a monolithic layout script.

`physics_spike.gd` is explicitly disposable prototype infrastructure. Its current programmatic construction of walls, lanes, camera, ramp positions, bumpers, flippers and other geometry exists only to validate physics quickly and must not become the production table-authoring model.

Production direction:

- A table is represented by an editable Godot scene.
- Reusable pinball components are instantiated as scenes/sub-scenes.
- Designers/developers can move and tune component transforms visually in the Godot editor.
- Component behavior remains modular in scripts; table composition/layout remains authored in scenes.
- Exported Resources/data may drive behavior, tuning, upgrade definitions and component metadata, but should not replace editor-visible table composition.
- Upgrade sockets, expansion areas and other roguelike table-evolution anchors must be explicit authored nodes/markers that can be inspected in the editor.
- Hard-coded world coordinates in a central table-builder script are not an acceptable production authoring workflow.

Before production table/content development proceeds, migrate the reusable systems proven by the physics spike into this scene-authored foundation. `physics_spike.gd` may remain afterward only as a dedicated prototype/QA harness if it still provides value.

## Communication

Prefer explicit Godot signals and narrowly scoped service APIs. A table collision should emit a semantic event such as `component_hit`, which may be consumed by scoring, combat, upgrades and UI without those systems knowing the component's internal implementation.

## Determinism

Run generation must be seeded. Physics does not need perfect lockstep determinism, but debug tooling should make it possible to reproduce content selection and major game-state transitions from a seed and logged events.
