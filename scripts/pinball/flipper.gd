class_name Flipper
extends AnimatableBody3D

## A single flipper bat.
##
## Implemented as an AnimatableBody3D that rotates about its pivot (local Y) in
## _physics_process. Because it is animatable + sync_to_physics, its motion is
## reported to the physics engine and imparts velocity to the ball on contact —
## a stronger, faster sweep hits the ball harder. Rotation is stepped by fixed
## physics delta, so behaviour is identical across render frame rates and
## deterministic enough to reproduce bugs (AGENTS.md physics rules).

enum Side { LEFT, RIGHT }

@export var tuning: PinballTuning
## Which side this flipper is, which mirrors rest pose and press direction.
@export var side: Flipper.Side = Flipper.Side.LEFT
## Input action that raises this flipper (e.g. "flipper_left").
@export var action_name: StringName = &"flipper_left"
## Resting droop of the bat below horizontal, in degrees.
@export var rest_droop_degrees: float = 22.0
## Length of the bat from the pivot, in world units.
@export var bat_length: float = 3.2

var _rest_yaw: float = 0.0
var _pressed_yaw: float = 0.0
var _current_yaw: float = 0.0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")

	sync_to_physics = true

	var droop := deg_to_rad(rest_droop_degrees)
	var travel := deg_to_rad(tuning.flipper_travel_degrees)
	if side == Side.LEFT:
		_rest_yaw = -droop
		_pressed_yaw = _rest_yaw + travel
	else:
		_rest_yaw = PI + droop
		_pressed_yaw = _rest_yaw - travel

	_current_yaw = _rest_yaw
	rotation.y = _current_yaw
	_build_geometry()

func _build_geometry() -> void:
	var size := Vector3(bat_length, 0.8, 0.7)
	# Bat extends from the pivot along +X, so offset its centre by half length.
	var offset := Vector3(bat_length * 0.5, 0.0, 0.0)

	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = offset
	col.name = "Collision"
	add_child(col)

	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.position = offset
	mesh.name = "Mesh"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.35, 0.2)
	mesh_box.material = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	var pressed := Input.is_action_pressed(action_name)
	var target := _pressed_yaw if pressed else _rest_yaw
	var speed_deg := tuning.flipper_press_speed if pressed else tuning.flipper_return_speed
	var max_step := deg_to_rad(speed_deg) * delta
	_current_yaw = move_toward(_current_yaw, target, max_step)
	rotation.y = _current_yaw
