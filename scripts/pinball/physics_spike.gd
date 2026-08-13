class_name PhysicsSpike
extends Node3D

## Greybox physics-spike table.
##
## Authors all table geometry and layout in code (transforms are easier to reason
## about and review here than in a hand-edited .tscn), instantiates the reusable
## component scenes, sets up the fixed camera + lighting, and owns ONLY the
## active-ball lifecycle (spawn / reset / respawn-on-drain) plus debug hotkeys.
##
## It is deliberately NOT a god controller: it has no knowledge of scoring,
## combat, upgrades or run progression. Components report gameplay via the
## GameEvents autoload; the table just keeps a ball in play.

const BALL_SCENE := preload("res://scenes/pinball/ball.tscn")
const FLIPPER_SCENE := preload("res://scenes/pinball/flipper.tscn")
const BUMPER_SCENE := preload("res://scenes/pinball/bumper.tscn")
const SLINGSHOT_SCENE := preload("res://scenes/pinball/slingshot.tscn")
const RAMP_SCENE := preload("res://scenes/pinball/ramp.tscn")
const DRAIN_SCENE := preload("res://scenes/pinball/drain.tscn")
const PLUNGER_SCENE := preload("res://scenes/pinball/plunger.tscn")

@export var tuning: PinballTuning

# --- Layout constants (world units, table-local; root is unrotated) ------
const FIELD_WIDTH := 14.0
const FIELD_LENGTH := 30.0
const WALL_HEIGHT := 2.0
const WALL_THICKNESS := 0.5
const LANE_DIVIDER_X := 5.0
const SPAWN_POS := Vector3(5.95, 0.4, 13.0)

var _ball: PinballBall
var _plunger: Plunger
var _overlay: DebugOverlay
var _screenshot_countdown: int = -1

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	# Stay processing while paused so we can unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_environment()
	_build_playfield()
	_build_walls()
	_build_launch_lane()
	_spawn_components()
	_spawn_ball()
	_build_overlay()

	GameEvents.ball_drained.connect(_on_ball_drained)
	print("[PhysicsSpike] Table built. Ball spawned at ", SPAWN_POS)

	# Optional headless QA probe (launch with: -- selftest).
	if OS.get_cmdline_user_args().has("selftest"):
		add_child(preload("res://tools/selftest_probe.gd").new())
	# Optional one-shot screenshot for layout review (launch windowed with: -- screenshot).
	if OS.get_cmdline_user_args().has("screenshot"):
		_screenshot_countdown = 20

# ------------------------------------------------------------------------
# Environment: fixed camera + lighting
# ------------------------------------------------------------------------
func _build_environment() -> void:
	var cam := Camera3D.new()
	cam.name = "FixedCamera"
	cam.fov = 52.0
	cam.position = Vector3(0.0, 21.0, 27.0)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.0, -2.0), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-60.0, -35.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.42)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

# ------------------------------------------------------------------------
# Static geometry
# ------------------------------------------------------------------------
func _build_playfield() -> void:
	var field := _make_static_box(
		Vector3(FIELD_WIDTH, 1.0, FIELD_LENGTH),
		Transform3D(Basis(), Vector3(0.0, -0.5, 0.0)),
		Color(0.16, 0.18, 0.22),
		0.4, 0.1)
	field.name = "Playfield"
	add_child(field)

func _build_walls() -> void:
	var half_w := FIELD_WIDTH * 0.5
	var half_l := FIELD_LENGTH * 0.5
	# Left / right outer walls.
	_add_wall("WallLeft", Vector3(WALL_THICKNESS, WALL_HEIGHT, FIELD_LENGTH),
		Vector3(-half_w, WALL_HEIGHT * 0.5, 0.0))
	_add_wall("WallRight", Vector3(WALL_THICKNESS, WALL_HEIGHT, FIELD_LENGTH),
		Vector3(half_w, WALL_HEIGHT * 0.5, 0.0))
	# Top / bottom walls.
	_add_wall("WallTop", Vector3(FIELD_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(0.0, WALL_HEIGHT * 0.5, -half_l))
	_add_wall("WallBottom", Vector3(FIELD_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(0.0, WALL_HEIGHT * 0.5, half_l))

func _build_launch_lane() -> void:
	# Divider between playfield and right launch lane. It spans z from +14 down
	# to -8 (length 22, centre z=3), leaving a gap at the top (-Z) so the
	# launched ball spills into the playfield.
	var divider_length := 22.0
	_add_wall("LaneDivider", Vector3(0.3, WALL_HEIGHT, divider_length),
		Vector3(LANE_DIVIDER_X, WALL_HEIGHT * 0.5, 3.0))

	# Deflector at the top of the lane: a diagonal wall (face normal toward
	# -X,+Z) that redirects the upward-launched ball leftward into the playfield
	# instead of letting it rattle straight back down the shooter lane.
	_add_wall("LaneDeflector", Vector3(3.6, WALL_HEIGHT, 0.4),
		Vector3(5.3, WALL_HEIGHT * 0.5, -11.0), deg_to_rad(-45.0))

func _add_wall(node_name: String, size: Vector3, position: Vector3, yaw: float = 0.0) -> void:
	var body := _make_static_box(size, Transform3D(Basis(Vector3.UP, yaw), position),
		Color(0.30, 0.32, 0.38), 0.1, 0.3)
	body.name = node_name
	add_child(body)

func _make_static_box(size: Vector3, xform: Transform3D, color: Color, friction: float, bounce: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	var phys := PhysicsMaterial.new()
	phys.friction = friction
	phys.bounce = bounce
	body.physics_material_override = phys

	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	body.add_child(col)

	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_box.material = mat
	body.add_child(mesh)
	return body

# ------------------------------------------------------------------------
# Dynamic / interactive components
# ------------------------------------------------------------------------
func _spawn_components() -> void:
	# Flippers.
	_add_flipper("FlipperLeft", Flipper.Side.LEFT, &"flipper_left", Vector3(-2.4, 0.4, 11.0))
	_add_flipper("FlipperRight", Flipper.Side.RIGHT, &"flipper_right", Vector3(2.4, 0.4, 11.0))

	# Drain between the flippers.
	var drain := DRAIN_SCENE.instantiate() as Drain
	drain.name = "Drain"
	drain.position = Vector3(0.0, 0.4, 13.6)
	add_child(drain)

	# Slingshots above the flippers, facing inward / up-table. Kept short and
	# pulled inboard so they never intrude into the right launch lane (x>5).
	_add_slingshot("SlingshotLeft", Vector3(-3.5, 0.4, 8.0), deg_to_rad(150.0), 2.2)
	_add_slingshot("SlingshotRight", Vector3(3.5, 0.4, 8.0), deg_to_rad(210.0), 2.2)

	# Three bumpers on the upper playfield.
	_add_bumper("BumperA", Vector3(-2.5, 0.8, -5.0))
	_add_bumper("BumperB", Vector3(2.5, 0.8, -5.0))
	_add_bumper("BumperC", Vector3(0.0, 0.8, -8.0))

	# One ramp on the left: enters low near the flippers (+Z), climbs to the
	# upper field (-Z). Yaw PI maps ramp-local entry(-Z) to world +Z.
	var ramp := RAMP_SCENE.instantiate() as Ramp
	ramp.name = "Ramp"
	ramp.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-4.5, 0.0, 2.0))
	add_child(ramp)

	# Plunger at the bottom of the launch lane.
	_plunger = PLUNGER_SCENE.instantiate() as Plunger
	_plunger.name = "Plunger"
	_plunger.position = Vector3(5.95, 0.4, 13.0)
	add_child(_plunger)

func _add_flipper(node_name: String, side: Flipper.Side, action: StringName, pos: Vector3) -> void:
	var flipper := FLIPPER_SCENE.instantiate() as Flipper
	flipper.name = node_name
	flipper.side = side
	flipper.action_name = action
	flipper.position = pos
	add_child(flipper)

func _add_slingshot(node_name: String, pos: Vector3, yaw: float, length: float) -> void:
	var sling := SLINGSHOT_SCENE.instantiate() as Slingshot
	sling.name = node_name
	sling.length = length
	sling.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	add_child(sling)

func _add_bumper(node_name: String, pos: Vector3) -> void:
	var bumper := BUMPER_SCENE.instantiate() as Bumper
	bumper.name = node_name
	bumper.position = pos
	add_child(bumper)

func _spawn_ball() -> void:
	_ball = BALL_SCENE.instantiate() as PinballBall
	_ball.name = "Ball"
	_ball.position = SPAWN_POS
	add_child(_ball)

func _build_overlay() -> void:
	_overlay = preload("res://scripts/pinball/debug_overlay.gd").new()
	_overlay.name = "DebugOverlay"
	_overlay.tuning = tuning
	add_child(_overlay)
	_overlay.ball = _ball
	_overlay.plunger = _plunger

# ------------------------------------------------------------------------
# Ball lifecycle
# ------------------------------------------------------------------------
func _on_ball_drained(_drained_ball: Node) -> void:
	_reset_ball()

func _reset_ball() -> void:
	if is_instance_valid(_ball):
		_ball.reset_to(SPAWN_POS)

# ------------------------------------------------------------------------
# Debug / QA input
# ------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reset_ball()
			KEY_F5:
				get_tree().reload_current_scene()
			KEY_F3:
				if is_instance_valid(_overlay):
					_overlay.set_active(not _overlay.visible)

	if event.is_action_pressed("pause_game"):
		get_tree().paused = not get_tree().paused
	if event.is_action_pressed("nudge_left"):
		_nudge(-1.0)
	if event.is_action_pressed("nudge_right"):
		_nudge(1.0)

func _nudge(direction: float) -> void:
	if is_instance_valid(_ball):
		_ball.apply_central_impulse(Vector3(direction * tuning.nudge_impulse, 0.0, 0.0))

func _process(_delta: float) -> void:
	if _screenshot_countdown < 0:
		return
	_screenshot_countdown -= 1
	if _screenshot_countdown == 0:
		var img := get_viewport().get_texture().get_image()
		var path := "user://spike_capture.png"
		img.save_png(path)
		print("[PhysicsSpike] Screenshot saved to ", ProjectSettings.globalize_path(path))
		get_tree().quit()
