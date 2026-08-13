# Physics Spike Acceptance Criteria

The first playable table is intentionally greybox.

## Required geometry

- tilted rectangular playfield
- left/right flippers
- launch lane and plunger/launcher
- two slingshot zones
- three bumpers
- one ramp with meaningful vertical elevation
- side walls / guides
- bottom drain

## Pass criteria

- Flippers react immediately and independently.
- The same shot can be repeated with broadly consistent results.
- Ball does not routinely tunnel through walls, flippers or bumpers at expected gameplay speeds.
- Ramp entry and exit are stable.
- Ball cannot become permanently trapped through ordinary play.
- Drain detection is reliable.
- Controller and keyboard both work.
- 120 Hz physics remains performant on a normal development PC.

## Tuning philosophy

Feel beats realism. Real pinball behavior is the reference, but parameters may be exaggerated for responsiveness and readability.

## Implementation notes (first spike pass)

### Physics model
The playfield is **flat and axis-aligned** (XZ plane). Table incline is simulated
by a custom gravity vector — mostly `-Y` (holds the ball to the field) with a
`+Z` component (rolls it toward the drain) — applied in `PinballBall._integrate_forces`.
This keeps every collision shape axis-aligned for the best high-speed reliability
while behaving like an inclined table. Local convention: `+Z` = toward the
drain/flippers, `-Z` = toward the top (bumpers/ramp), `+X` = right (launch lane side).

### Centralized tuning
Every feel value lives in `res://data/pinball/table_tuning.tres`
(`PinballTuning` resource): ball mass/restitution/friction/damping, gravity
strength, incline, flipper travel/press/return speed, bumper & slingshot impulse,
launcher strength & charge rate, max ball velocity, nudge impulse. No magic
numbers in component code.

### Key decisions
- **Flippers** are `AnimatableBody3D`s rotated about Y in `_physics_process`
  (fixed tick → frame-rate-independent, deterministic, no hinge-motor instability).
- **The active ball never sleeps** (`can_sleep = false`). A sleeping `RigidBody3D`
  ignores plunger/bumper/slingshot impulses and can miss collisions ("dead ball").
- **`max_ball_velocity` clamp** (default 90 u/s) is an intentional anti-tunnelling
  guard, set high enough that ordinary play never reaches it (observed peak ~40).
- **Shooter lane** feeds the playfield via an angled deflector at the top; without
  it the launched ball just rattles up and down the lane.
- Components report gameplay only via the `GameEvents` autoload; nothing in the
  pinball layer references run/combat/upgrade systems.

### Validation
Automated headless smoke test (launch → deflect → play → drain/respawn → ramp
traversal), asserting no fall-through, no runaway energy, reliable drain and ramp
completion:

```
godot --headless --path <project> -- selftest
```

One-shot layout screenshot (run windowed): `godot --path <project> -- screenshot`
saves to `user://spike_capture.png`.

### Not implemented in this pass (deferred, out of spike scope)
Drop/stand-up targets, multiball, tilt/ball-save, scoring, and any run/combat/
upgrade hooks. See the PAR-14/15/16 Jira comments for the full done/pending breakdown.

## Pass 2 updates (scene-based authoring)

### Table authoring — the table is a scene, not a script
Per the AGENTS.md / ARCHITECTURE.md HARD RULE, `physics_spike.gd` no longer builds
the table. The table is authored in `scenes/pinball/physics_spike.tscn` with the
hierarchy `Environment / Playfield / Components / BallSpawn / Ball / Plunger /
Debug`. Every wall, flipper, slingshot, bumper, the ramp, the drain and the
plunger is a **scene instance placed by an editable transform** — moving one is an
editor operation, never a code edit.

- Reusable components (`ball`, `flipper`, `bumper`, `slingshot`, `ramp`, `drain`,
  `plunger`) and a parametric `wall` component are **`@tool`** scenes: they build
  their greybox mesh + collision from exported params so the geometry is **visible
  and editable in the Godot editor** (generated children are unsaved; runtime
  callbacks are guarded with `Engine.is_editor_hint()`).
- `physics_spike.gd` is now a thin lifecycle coordinator: it keeps the ball in
  play (respawn on drain via the authored `BallSpawn` marker), sets up the
  cosmetic environment, mounts the debug tools and routes hotkeys. It builds no
  geometry and places no component. It remains a disposable prototype harness.

### Ramp / dead-zone fix (geometric)
Manual Test #1 trapped the ball behind/beside the old ramp. The ramp was redesigned
smaller (≈1.5 × 6, rise ≈1.85) and **flush against the left wall**, fully enclosed
by its own vertical side walls plus a high-end underside cap, so there is no pocket
beside, behind or under it. The low end's slab meets the floor. Fixed by geometry,
**not** by teleporting the ball out of the trap.

### Ball feel baseline (less floaty)
Root cause of "floaty" was a weak in-plane pull: `gravity·sin(incline)`. Raising
incline 7→11° and gravity 32→46 roughly doubles it (≈3.9 → ≈8.8 u/s²) for a
weightier, faster return; damping kept low to preserve momentum; launcher/bumper/
slingshot nudged up to stay proportionate. This is a **starting baseline** — the
live tuning panel is the intended way to dial in real feel.

### Live tuning panel (debug only)
`F4` opens a keyboard-driven panel (Up/Down select, Left/Right adjust, Shift =
coarse). Gravity, incline, restitution, friction, damping, ball mass, flipper
press/return/travel, bumper/slingshot/launcher impulse and max velocity all update
the shared tuning resource live. `Home` resets to the authored baseline; `End`
prints a paste-ready `[resource]` block and writes `user://tuning_export.tres`.

### Dead-state watchdog (report, never hide)
A watchdog reports (console + overlay banner) when the ball goes out of bounds,
under the playfield, or sits stationary >3 s outside the launch lane, logging
position, velocity, stationary time and last component interaction. It never
teleports the ball; manual reset (`R`) stays available and the tester is told a bad
state occurred.

### Validation (Pass 2)
The headless self-test now runs against the scene-authored table and asserts:
boot, spawn, launch, flipper actuation, traversal, bumpers, slingshots, ramp
completion, drain/respawn, in-bounds (no escapes / fall-through), speed under the
clamp, and a return-time (floaty) measurement. `godot --headless -- selftest`.

## Pass 3 updates (Developer Edit Mode + table definitions)

### Table container
All editable components now live under a single `Table` node in
`physics_spike.tscn` (node name = stable component ID). `Ball` stays a runtime
root child. The authored `Table` is still the editor-visible default; it can also
be built from data (below).

### Table-definition format (data-driven layouts)
Layouts can be described as human-readable JSON — see `docs/TABLE_DEFINITION.md`.
`TableRegistry` (type ↔ scene ↔ props), `TableDefinition` (data + JSON I/O) and
`TableLoader` (build/serialize) form the layer; reusable component scenes remain
the runtime implementation. The sample `data/pinball/tables/default_table.json`
mirrors the spike and can be booted with `-- loadtable` or regenerated from the
authored scene with `-- exporttable`.

### Developer Edit Mode v0 (debug only)
Press **F2** to enter/exit Edit Mode. Entering pauses the tree (ball physics
suspended); exiting resets the ball and resumes. Controls: **Tab** cycle
selection, **arrows** move X/Z, **PgUp/PgDn** move Y, **, .** rotate yaw, **- =**
scale, **Del** delete, **Ins** duplicate, **1..7** add from palette, **Ctrl+S/L**
save/load dev layout, **Ctrl+D** load default. The selected component is
highlighted; gameplay input is suppressed while editing. This is the tool for the
Manual Test #2 findings (bumper loop spacing, outlane geometry, ramp shot
reachability) — reposition/retune experimentally, then Play-test immediately.

### Validation (Pass 3)
`selftest` now also round-trips the table definition (serialize → JSON → parse →
build) and asserts it rebuilds cleanly. A separate `-- edittest` headless probe
drives Edit Mode via synthetic input and checks enter/pause, add, duplicate, move,
delete, save, load and exit/unpause.
