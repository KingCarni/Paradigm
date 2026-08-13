extends Node

## Optional headless physics smoke probe for the greybox spike.
##
## Attached as a child of the table ONLY when the game is launched with the
## user arg `selftest` (see PhysicsSpike._ready), so it runs inside the real
## scene tree with autoloads present. It launches the ball and watches for the
## failure modes in docs/PHYSICS_SPIKE.md — fall-through, escaping geometry,
## runaway energy, broken drain/respawn — then prints a summary and quits.
##
## Run: godot --headless --path <project> -- selftest

var _spike: Node3D
var _ball: RigidBody3D
var _frames := 0
var _min_y := 999.0
var _max_y := -999.0
var _max_speed := 0.0
var _reached_upper := false
var _drains := 0
var _launched := false

var _ramps := 0

func _ready() -> void:
	_spike = get_parent() as Node3D
	GameEvents.ball_drained.connect(func(_b: Node) -> void: _drains += 1)
	GameEvents.component_completed.connect(func(_c: Node, ctx: Dictionary) -> void:
		if ctx.get("type", "") == "ramp":
			_ramps += 1)

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _ball == null:
		_ball = _spike.get_node_or_null("Ball")
		return

	var pos := _ball.global_position
	var speed := _ball.linear_velocity.length()
	_min_y = minf(_min_y, pos.y)
	_max_y = maxf(_max_y, pos.y)
	_max_speed = maxf(_max_speed, speed)
	if pos.z < -3.0:
		_reached_upper = true

	if _frames == 120 and not _launched:
		print("LAUNCH TEST: firing ball up the shooter lane")
		_ball.apply_central_impulse(Vector3(0.0, 0.0, -1.0) * 42.0)
		_launched = true

	# Force a drain to verify detection + respawn.
	if _frames == 1200:
		print("DRAIN TEST: placing ball at drain mouth")
		_ball.reset_to(Vector3(0.0, 0.4, 12.9))

	# Ramp test: place ball at the ramp entry, then fire it up the ramp (-Z).
	if _frames == 1500:
		print("RAMP TEST: placing ball at ramp entry")
		_ball.reset_to(Vector3(-4.5, 0.6, 5.0))
	if _frames == 1512:
		_ball.apply_central_impulse(Vector3(0.0, 0.0, -1.0) * 24.0)

	if _frames % 120 == 0:
		print("f%4d  pos=(%5.1f,%4.1f,%5.1f)  speed=%5.1f  drains=%d"
			% [_frames, pos.x, pos.y, pos.z, speed, _drains])

	if _frames >= 2100:
		_report()
		get_tree().quit()

func _report() -> void:
	print("--- SELFTEST SUMMARY ---")
	print("min_y=%.2f (fall-through if << 0)  max_y=%.2f" % [_min_y, _max_y])
	print("max_speed=%.1f  (clamp is 90)" % _max_speed)
	print("reached_upper_field=%s" % str(_reached_upper))
	print("drains(=respawns)=%d  ramp_completions=%d" % [_drains, _ramps])
	var ok := _min_y > -1.5 and _max_speed <= 91.0 and _reached_upper and _drains >= 1 and _ramps >= 1
	print("RESULT: %s" % ("PASS" if ok else "CHECK"))
