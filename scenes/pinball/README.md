# Pinball Scenes

Greybox physics-spike scenes. **No final art** belongs here during the spike.

## Scenes

- `physics_spike.tscn` — entry point (set as `run/main_scene`). A near-empty
  `Node3D` + `PhysicsSpike` script that authors all table geometry, layout,
  camera, lighting and the debug overlay in code, then instantiates the
  component scenes below at authored transforms.
- `ball.tscn` — `RigidBody3D` + `PinballBall`.
- `flipper.tscn` — `AnimatableBody3D` + `Flipper` (side/action set by the table).
- `bumper.tscn` — `StaticBody3D` + `Bumper` (pop bumper).
- `slingshot.tscn` — `StaticBody3D` + `Slingshot`.
- `ramp.tscn` — `StaticBody3D` + `Ramp` (elevated channel with traversal detection).
- `drain.tscn` — `Area3D` + `Drain`.
- `plunger.tscn` — `Area3D` + `Plunger` (hold-to-charge launcher).

Each component scene is deliberately trivial: the root node has the script and a
reference to `res://data/pinball/table_tuning.tres`; the script builds its own
greybox mesh + collision from the tuning values in `_ready()`. This keeps
fragile 3D transforms out of hand-edited `.tscn` text and all tuning in one place.

## Tuning

All feel values live in `res://data/pinball/table_tuning.tres`
(`scripts/pinball/pinball_tuning.gd`). Edit that resource in the inspector to
retune the whole table — no code edits required.

## Scripts

Component scripts live in `res://scripts/pinball/`. The table communicates
gameplay outward only through the `GameEvents` autoload
(`res://scripts/core/game_events.gd`); no pinball component references run,
combat, scoring or upgrade systems.
