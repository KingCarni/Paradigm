# Pinball Scenes

Greybox physics-spike scenes. **No final art** belongs here during the spike.

## The table is scene-authored (HARD RULE)

`physics_spike.tscn` is the table. Its layout is authored **visually in the Godot
editor** as a tree of scene instances with editable transforms — it is NOT built
from `Vector3` constants in a script (see AGENTS.md / `docs/ARCHITECTURE.md`
"Production table authoring"). Moving a wall, bumper, ramp, flipper or drain is an
editor operation.

Hierarchy:

```
PhysicsSpike (physics_spike.gd — lifecycle only, builds no geometry)
├── Environment   Camera, Sun, WorldEnvironment
├── Table         ALL editable components (flat; node name = stable component ID):
│                 Floor, WallLeft/Right/Top/Bottom, LaneDivider, LaneDeflector,
│                 Drain, LeftFlipper, RightFlipper, LeftSlingshot, RightSlingshot,
│                 Bumper01/02/03, Ramp01, BallSpawn (Marker3D), Plunger
├── Ball          the active ball (runtime object, not part of the table definition)
└── Debug         runtime mount for overlay / tuning panel / watchdog / Edit Mode
```

The authored `Table` is the editor-visible default and can equally be built from a
JSON **table definition** (see `docs/TABLE_DEFINITION.md`): `TableRegistry`,
`TableDefinition` and `TableLoader` translate between layout data and component
scenes. **Developer Edit Mode** (F2) edits the live `Table` and saves/loads these
definitions. Reusable component scenes remain the runtime implementation.

## Reusable `@tool` components

Each component scene builds its own greybox mesh + collision parametrically and is
marked `@tool`, so the geometry is **visible and editable in the editor** while the
`.tscn` stays a trivial root + script + exported params:

- `wall.tscn` — parametric box (`size`, `wall_color`, `friction`, `bounce`) used
  for the floor, walls, lane divider and deflector.
- `ball.tscn` — `RigidBody3D` + `PinballBall`.
- `flipper.tscn` — `AnimatableBody3D` + `Flipper` (`side` / `action_name` per instance).
- `bumper.tscn` — `StaticBody3D` + `Bumper` (pop bumper + trigger ring).
- `slingshot.tscn` — `StaticBody3D` + `Slingshot`.
- `ramp.tscn` — `StaticBody3D` + `Ramp` (enclosed, dead-zone-free ramp with
  entry/exit traversal detection).
- `drain.tscn` — `Area3D` + `Drain`.
- `plunger.tscn` — `Area3D` + `Plunger`.

## Tuning

All feel values live in `res://data/pinball/table_tuning.tres`
(`scripts/pinball/pinball_tuning.gd`) — a single shared resource every component
reads. Edit it in the inspector, or retune live in-game with the `F4` tuning panel
(`End` exports a paste-ready block).

## Rule

Component behaviour stays in `scripts/pinball/`. Components communicate outward
only through the `GameEvents` autoload; nothing in the pinball layer references
run/combat/scoring/upgrade systems.
