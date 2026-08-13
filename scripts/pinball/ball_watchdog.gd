class_name BallWatchdog
extends Node

## Lightweight invalid/dead-state detector for the physics spike (DEBUG only).
##
## REPORTS bad states so table-geometry bugs stay visible; it never teleports the
## ball (that would hide the very problems we are hunting). The tester sees a
## banner in the overlay and a one-time console log with position, velocity, time
## stationary and the last component interaction. Manual reset (R) stays available.

var ball: PinballBall
var overlay: DebugOverlay
var spawn_marker: Node3D

## Expected legitimate play volume (generous margin around the table).
const BOUND_X: float = 8.0
const BOUND_Z: float = 16.0
const BOUND_Y_MIN: float = -0.5
const BOUND_Y_MAX: float = 6.0
const STATIONARY_SPEED: float = 0.6
const STATIONARY_LIMIT: float = 3.0

var _stationary_time: float = 0.0
var _active_issue: String = ""
var _last_interaction: String = "none"
var _last_interaction_ms: int = 0

func _ready() -> void:
	GameEvents.component_hit.connect(_on_hit)
	GameEvents.component_completed.connect(_on_completed)

func _on_hit(_c: Node3D, _b: Node3D, ctx: Dictionary) -> void:
	_last_interaction = str(ctx.get("type", "hit"))
	_last_interaction_ms = Time.get_ticks_msec()

func _on_completed(_c: Node3D, ctx: Dictionary) -> void:
	_last_interaction = str(ctx.get("type", "complete"))
	_last_interaction_ms = Time.get_ticks_msec()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ball):
		return
	var pos := ball.global_position
	var vel := ball.linear_velocity
	var speed := vel.length()

	if speed < STATIONARY_SPEED:
		_stationary_time += delta
	else:
		_stationary_time = 0.0

	var issue := ""
	if pos.y < BOUND_Y_MIN:
		issue = "UNDER PLAYFIELD"
	elif absf(pos.x) > BOUND_X or absf(pos.z) > BOUND_Z or pos.y > BOUND_Y_MAX:
		issue = "OUT OF BOUNDS"
	elif _stationary_time > STATIONARY_LIMIT and not _in_legit_rest(pos):
		issue = "STUCK / STATIONARY"

	if issue != _active_issue:
		_active_issue = issue
		if issue != "":
			var age := float(Time.get_ticks_msec() - _last_interaction_ms) / 1000.0
			printerr("[Watchdog] %s | pos=(%.1f,%.1f,%.1f) vel=(%.1f,%.1f,%.1f) speed=%.1f stationary=%.1fs last=%s (%.1fs ago)"
				% [issue, pos.x, pos.y, pos.z, vel.x, vel.y, vel.z, speed, _stationary_time, _last_interaction, age])

	if is_instance_valid(overlay):
		if issue == "":
			overlay.set_alert("")
		else:
			overlay.set_alert("! %s  pos(%.1f,%.1f,%.1f) stat %.1fs - press R to reset (state kept for inspection)"
				% [issue, pos.x, pos.y, pos.z, _stationary_time])

## The launch lane is the only place the ball legitimately sits still for long.
func _in_legit_rest(pos: Vector3) -> bool:
	return pos.x > 4.5 and pos.z > 8.0
