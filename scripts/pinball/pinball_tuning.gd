class_name PinballTuning
extends Resource

## Centralized tuning values for the greybox physics spike.
##
## Every value that meaningfully affects pinball FEEL lives here so it can be
## tweaked from a single .tres in the inspector without editing gameplay code.
## Feel beats realism (see docs/PHYSICS_SPIKE.md): units are exaggerated for
## responsiveness and readability, not physical accuracy.
##
## The table works in a FLAT playfield (XZ plane, +Z toward the drain/flippers,
## -Z toward the top/plunger). Incline is simulated by the gravity vector rather
## than by tilting geometry, which keeps every collision shape axis-aligned for
## high-speed reliability.

# --- Ball ---------------------------------------------------------------
@export_group("Ball")
## Physical radius of the ball, in world units. NOTE: the greybox ball geometry
## is now authored in ball.tscn; this stays as a reference for tooling (e.g. the
## dead-state watchdog) and should be kept in sync with the authored mesh.
@export var ball_radius: float = 0.4
## Mass of the ball. Heavier balls resist bumper/slingshot impulses more. Does
## NOT change gravitational acceleration (gravity is applied as accel, not force).
@export var ball_mass: float = 1.0
## Bounciness of the ball against walls/components (0 = dead, 1 = perfectly elastic).
@export_range(0.0, 1.0) var ball_restitution: float = 0.30
## Rolling/sliding friction of the ball surface.
@export_range(0.0, 1.0) var ball_friction: float = 0.35
## Linear damping applied to the ball. Kept low to preserve momentum (a higher
## value reads as sluggish/floaty rather than weighty).
@export var ball_linear_damp: float = 0.12
## Angular damping applied to the ball's spin.
@export var ball_angular_damp: float = 0.4

# --- Playfield gravity / incline ---------------------------------------
@export_group("Playfield")
## Gravity magnitude pulling the ball down the table, in units/s^2. Exaggerated
## well beyond 9.8 for a snappy, weighty pinball feel. The in-plane pull toward
## the drain is gravity_strength * sin(incline) -- that product is what governs
## "floaty vs weighty", so raise BOTH this and the incline to add weight.
@export var gravity_strength: float = 46.0
## Simulated table incline, in degrees. Larger = faster drain, steeper slope.
## Converted into the in-plane (+Z) component of the gravity vector.
@export_range(0.0, 30.0) var playfield_incline_degrees: float = 11.0

# --- Flippers -----------------------------------------------------------
@export_group("Flippers")
## Angular travel of a flipper from rest to fully raised, in degrees.
@export_range(10.0, 90.0) var flipper_travel_degrees: float = 42.0
## How fast a flipper sweeps up when pressed, in degrees/second. Higher = more
## contact velocity imparted to the ball, i.e. a stronger flip.
@export var flipper_press_speed: float = 1600.0
## How fast a flipper returns to rest when released, in degrees/second.
@export var flipper_return_speed: float = 700.0

# --- Impulse components -------------------------------------------------
@export_group("Impulse Components")
## Outward impulse applied by a bumper when the ball enters its trigger.
@export var bumper_impulse: float = 18.0
## Impulse applied by a slingshot along its face normal.
@export var slingshot_impulse: float = 20.0

# --- Launcher / plunger -------------------------------------------------
@export_group("Launcher")
## Maximum launch impulse when the plunger is fully charged. Scaled up alongside
## the stronger gravity so a full plunge still reaches the top of the table.
@export var launcher_strength: float = 62.0
## How fast the plunger charges toward full while the launch button is held,
## as a fraction (0..1) per second.
@export var launcher_charge_rate: float = 1.5

# --- Safety / nudge -----------------------------------------------------
@export_group("Safety")
## Hard ceiling on ball speed, in units/s. This is an INTENTIONAL simulation
## guard against tunnelling at 120 Hz, not a feel crutch: it is set high enough
## that ordinary play never touches it. Documented per AGENTS.md physics rules.
@export var max_ball_velocity: float = 90.0
## Horizontal impulse applied by a nudge input. Minimal, for feel evaluation only.
@export var nudge_impulse: float = 3.5

## Returns the world-space gravity vector for the ball: mostly -Y (holds the
## ball to the flat field) with a +Z component (rolls it toward the drain),
## derived from [member playfield_incline_degrees].
func gravity_vector() -> Vector3:
	var incline := deg_to_rad(playfield_incline_degrees)
	return Vector3(0.0, -cos(incline), sin(incline)) * gravity_strength
