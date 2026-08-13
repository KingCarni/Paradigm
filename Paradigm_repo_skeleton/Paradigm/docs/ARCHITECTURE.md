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

## Communication

Prefer explicit Godot signals and narrowly scoped service APIs. A table collision should emit a semantic event such as `component_hit`, which may be consumed by scoring, combat, upgrades and UI without those systems knowing the component's internal implementation.

## Determinism

Run generation must be seeded. Physics does not need perfect lockstep determinism, but debug tooling should make it possible to reproduce content selection and major game-state transitions from a seed and logged events.
