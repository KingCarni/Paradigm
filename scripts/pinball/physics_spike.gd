class_name PhysicsSpike
extends Node3D

## Physics-spike lifecycle coordinator (DISPOSABLE prototype harness).
##
## The table itself is authored in physics_spike.tscn: floor, walls, lane, drain,
## flippers, slingshots, bumpers, ramp, ball, spawn marker and plunger are all
## scene nodes with editable transforms. This script builds NO table geometry and
## places NO component (see AGENTS.md "Production table authoring — HARD RULE").
##
## Its only jobs: keep the active ball in play (respawn on drain, using the
## authored BallSpawn marker), configure the cosmetic environment, mount the debug
## tools (overlay, live tuning panel, dead-state watchdog) and route debug hotkeys.
## It is not a god controller and knows nothing about scoring/combat/progression.

@export var tuning: PinballTuning

@onready var _ball: PinballBall = $Ball
@onready var _ball_spawn: Marker3D = $BallSpawn
@onready var _plunger: Plunger = $Plunger
@onready var _debug_root: Node = $Debug
@onready var _world_env: WorldEnvironment = $Environment/WorldEnvironment
@onready var _left_flipper: Flipper = $Components/Flippers/LeftFlipper
@onready var _right_flipper: Flipper = $Components/Flippers/RightFlipper

var _overlay: DebugOverlay
var _panel: TuningPanel
var _watchdog: BallWatchdog
var _baseline: PinballTuning
var _screenshot_countdown: int = -1

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_environment()
	# Immutable snapshot of the authored baseline for the panel's "reset" action.
	_baseline = tuning.duplicate()

	_mount_debug_tools()

	GameEvents.ball_drained.connect(_on_ball_drained)
	print("[PhysicsSpike] Scene-authored table ready. Spawn at ", _ball_spawn.global_position)

	if OS.get_cmdline_user_args().has("selftest"):
		add_child(preload("res://tools/selftest_probe.gd").new())
	if OS.get_cmdline_user_args().has("screenshot"):
		_screenshot_countdown = 20

func _ensure_environment() -> void:
	# Cosmetic only (not table geometry): give the authored WorldEnvironment an
	# environment if it lacks one, using named constants to avoid enum-int drift.
	if _world_env == null or _world_env.environment != null:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.42)
	env.ambient_light_energy = 1.0
	_world_env.environment = env

func _mount_debug_tools() -> void:
	_overlay = preload("res://scripts/pinball/debug_overlay.gd").new()
	_overlay.name = "DebugOverlay"
	_overlay.tuning = tuning
	_debug_root.add_child(_overlay)
	_overlay.ball = _ball
	_overlay.plunger = _plunger
	_overlay.left_flipper = _left_flipper

	_watchdog = preload("res://scripts/pinball/ball_watchdog.gd").new()
	_watchdog.name = "BallWatchdog"
	_watchdog.ball = _ball
	_watchdog.overlay = _overlay
	_watchdog.spawn_marker = _ball_spawn
	_debug_root.add_child(_watchdog)

	_panel = preload("res://scripts/pinball/tuning_panel.gd").new()
	_panel.name = "TuningPanel"
	_panel.tuning = tuning
	_panel.baseline = _baseline
	_panel.ball = _ball
	_debug_root.add_child(_panel)

# ------------------------------------------------------------------------
# Ball lifecycle
# ------------------------------------------------------------------------
func _on_ball_drained(_drained_ball: Node) -> void:
	reset_ball()

func reset_ball() -> void:
	if is_instance_valid(_ball) and is_instance_valid(_ball_spawn):
		_ball.reset_to(_ball_spawn.global_position)

# ------------------------------------------------------------------------
# Debug / QA input
# ------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				reset_ball()
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
