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
upgrade hooks. Ball respawn currently uses a layout constant rather than a data
resource. See the PAR-14/15/16 Jira comments for the full done/pending breakdown.
