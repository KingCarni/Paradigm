extends Node

## Optional headless physics smoke probe for the scene-authored spike.
##
## Attached as a child of the table ONLY when launched with `-- selftest`, so it
## runs inside the real tree with autoloads present. It exercises the full path
## (launch, free play, flipper actuation, ramp traversal, drain/respawn) and a
## floaty/return-time measurement, watching for the failure modes in
## docs/PHYSICS_SPIKE.md. Prints a summary and quits.
##
## Run: godot --headless --path <project> -- selftest

var _spike: Node3D
var _ball: RigidBody3D
var _ramp: Node3D
var _left_flipper: Node3D
var _frames := 0

var _min_y := 999.0
var _max_y := -999.0
var _max_speed := 0.0
var _max_abs_x := 0.0
var _max_abs_z := 0.0
var _reached_upper := false

var _bumpers := 0
var _slings := 0
var _ramps := 0
var _drains := 0
var _launched := false
var _flipper_moved := false

var _return_start := -1
var _return_frames := -1

func _ready() -> void:
	_spike = get_parent() as Node3D
	GameEvents.ball_drained.connect(_on_drained)
	GameEvents.component_hit.connect(_on_hit)
	GameEvents.component_completed.connect(_on_completed)

func _on_drained(_b: Node) -> void:
	_drains += 1

func _on_hit(_c: Node, _b: Node, ctx: Dictionary) -> void:
	var t := str(ctx.get("type", ""))
	if t == "bumper":
		_bumpers += 1
	elif t == "slingshot":
		_slings += 1

func _on_completed(_c: Node, ctx: Dictionary) -> void:
	if ctx.get("type", "") == "ramp":
		_ramps += 1

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _ball == null:
		_ball = _spike.get_node_or_null("Ball")
		_ramp = _spike.get_node_or_null("Components/Ramp01")
		_left_flipper = _spike.get_node_or_null("Components/Flippers/LeftFlipper")
		return

	var pos := _ball.global_position
	var speed := _ball.linear_velocity.length()
	_min_y = minf(_min_y, pos.y)
	_max_y = maxf(_max_y, pos.y)
	_max_speed = maxf(_max_speed, speed)
	_max_abs_x = maxf(_max_abs_x, absf(pos.x))
	_max_abs_z = maxf(_max_abs_z, absf(pos.z))
	if pos.z < -3.0:
		_reached_upper = true

	# Full-power launch up the shooter lane.
	if _frames == 120 and not _launched:
		print("LAUNCH TEST: firing ball up the shooter lane")
		_ball.apply_central_impulse(Vector3(0.0, 0.0, -1.0) * 62.0)
		_launched = true

	# Return-time (floaty) test: drop the ball at the top, time its roll down a
	# clean left lane to mid-table.
	if _frames == 900:
		print("RETURN TEST: releasing ball at top to measure roll-down time")
		_ball.reset_to(Vector3(-4.5, 0.4, -12.0))
		_return_start = _frames + 2
	if _return_frames < 0 and _return_start > 0 and _frames > _return_start and pos.z >= 0.0:
		_return_frames = _frames - _return_start

	# Drain + respawn.
	if _frames == 1200:
		print("DRAIN TEST: placing ball at drain mouth")
		_ball.reset_to(Vector3(0.0, 0.4, 12.9))

	# Ramp traversal from the authored entry.
	if _frames == 1450 and _ramp != null:
		print("RAMP TEST: placing ball at ramp entry")
		_ball.reset_to((_ramp.get_entry_position() as Vector3) + Vector3(0.0, 0.2, 0.0))
	if _frames == 1465:
		_ball.apply_central_impulse(Vector3(0.0, 0.0, -1.0) * 28.0)

	# Flipper actuation.
	if _frames == 1750 and _left_flipper != null:
		Input.action_press("flipper_left")
	if _frames == 1770 and _left_flipper != null:
		if absf(_left_flipper.rotation.y - (-deg_to_rad(22.0))) > 0.3:
			_flipper_moved = true
		Input.action_release("flipper_left")

	# Slingshot poke: approach the left slingshot from the front (face-normal side)
	# and drive through its kick trigger. Left slingshot is at (-3.5,0.4,8), yaw
	# 150, so its face normal points toward (+X,-Z); the front-outer point and the
	# impulse below carry the ball into the KickTrigger.
	if _frames == 1900:
		print("SLINGSHOT TEST: driving ball into left slingshot from the front")
		_ball.reset_to(Vector3(-2.75, 0.4, 6.7))
	if _frames == 1912:
		_ball.apply_central_impulse(Vector3(-0.5, 0.0, 0.866) * 20.0)

	if _frames % 150 == 0:
		print("f%4d  pos=(%5.1f,%4.1f,%5.1f)  speed=%5.1f  b=%d s=%d r=%d d=%d"
			% [_frames, pos.x, pos.y, pos.z, speed, _bumpers, _slings, _ramps, _drains])

	if _frames >= 2100:
		_report()
		get_tree().quit()

func _report() -> void:
	print("--- SELFTEST SUMMARY ---")
	print("min_y=%.2f  max_y=%.2f  max_speed=%.1f (clamp 90)" % [_min_y, _max_y, _max_speed])
	print("max_abs_x=%.1f (<8)  max_abs_z=%.1f (<16)" % [_max_abs_x, _max_abs_z])
	print("reached_upper=%s  flipper_moved=%s" % [str(_reached_upper), str(_flipper_moved)])
	print("bumpers=%d  slings=%d  ramp_completions=%d  drains=%d" % [_bumpers, _slings, _ramps, _drains])
	print("return_frames(top->mid, lower=weightier)=%d" % _return_frames)
	var in_bounds := _min_y > -1.0 and _max_abs_x < 8.0 and _max_abs_z < 16.0
	var ok := in_bounds and _max_speed <= 91.0 and _reached_upper and _flipper_moved \
		and _bumpers >= 1 and _slings >= 1 and _ramps >= 1 and _drains >= 1
	print("in_bounds=%s" % str(in_bounds))
	print("RESULT: %s" % ("PASS" if ok else "CHECK"))
