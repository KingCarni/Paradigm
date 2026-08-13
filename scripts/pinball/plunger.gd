class_name Plunger
extends Area3D

## The launcher at the bottom of the launch lane.
##
## While the ball rests in the lane trigger and the launch button is held, charge
## builds toward full; on release the ball is fired up the lane (local -Z) with an
## impulse proportional to charge, up to tuning.launcher_strength. Charge is
## readable for the debug overlay. This is the only launch authority — components
## do not launch themselves.

@export var tuning: PinballTuning
## Local launch direction (up the lane). Table orients the plunger; -Z is up-table.
@export var launch_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var trigger_size: Vector3 = Vector3(1.4, 1.5, 2.0)
## Minimum charge applied on any release, so a quick tap still ejects the ball.
@export var min_charge: float = 0.15

var _charge: float = 0.0
var _ball: PinballBall = null
var _was_pressed: bool = false

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	var box := BoxShape3D.new()
	box.size = trigger_size
	var col := CollisionShape3D.new()
	col.shape = box
	col.name = "Collision"
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_charge() -> float:
	return _charge

func _on_body_entered(body: Node) -> void:
	if body is PinballBall:
		_ball = body

func _on_body_exited(body: Node) -> void:
	if body == _ball:
		_ball = null
		_charge = 0.0

func _physics_process(delta: float) -> void:
	var pressed := Input.is_action_pressed("launch_ball")
	if pressed and _ball != null:
		_charge = minf(1.0, _charge + tuning.launcher_charge_rate * delta)
	# Fire on release.
	if _was_pressed and not pressed and _ball != null:
		_fire()
	_was_pressed = pressed

func _fire() -> void:
	var charge := maxf(_charge, min_charge)
	var dir := (global_transform.basis * launch_direction)
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	_ball.apply_central_impulse(dir * charge * tuning.launcher_strength)
	GameEvents.component_hit.emit(self, _ball, {"type": "launch", "charge": charge})
	_charge = 0.0
