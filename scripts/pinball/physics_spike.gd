class_name PhysicsSpike
extends Node3D

## Physics-spike lifecycle coordinator (DISPOSABLE prototype harness).
##
## The table lives under the authored `Table` node (editable component instances)
## and can equally be built from a JSON table definition (see TableLoader). This
## script builds NO geometry and places NO component (AGENTS.md HARD RULE). It
## keeps the ball in play (respawn at the authored BallSpawn marker), sets up the
## cosmetic environment, mounts the debug tools (overlay, live tuning, watchdog,
## Edit Mode) and routes hotkeys. Not a god controller.

@export var tuning: PinballTuning

@onready var _table: Node3D = $Table
@onready var _ball: PinballBall = $Ball
@onready var _debug_root: Node = $Debug
@onready var _world_env: WorldEnvironment = $Environment/WorldEnvironment

const DEFAULT_TABLE_PATH: String = "res://data/pinball/tables/default_table.json"
const FALLBACK_SPAWN: Vector3 = Vector3(5.95, 0.4, 13.0)

var _overlay: DebugOverlay
var _panel: TuningPanel
var _watchdog: BallWatchdog
var _edit_mode: EditMode
var _baseline: PinballTuning
var _screenshot_countdown: int = -1

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_environment()
	_baseline = tuning.duplicate()

	# Dev hook: rebuild the table from the JSON definition to prove the load path.
	if OS.get_cmdline_user_args().has("loadtable"):
		_boot_from_definition()

	_mount_debug_tools()

	GameEvents.ball_drained.connect(_on_ball_drained)
	reset_ball()
	print("[PhysicsSpike] Ready. Table children: ", _table.get_child_count())

	# Dev hook: export the authored table to the default JSON definition and quit.
	if OS.get_cmdline_user_args().has("exporttable"):
		_export_default_table()
		return
	if OS.get_cmdline_user_args().has("selftest"):
		add_child(preload("res://tools/selftest_probe.gd").new())
	if OS.get_cmdline_user_args().has("edittest"):
		add_child(preload("res://tools/edit_mode_probe.gd").new())
	if OS.get_cmdline_user_args().has("screenshot"):
		_screenshot_countdown = 20
	if OS.get_cmdline_user_args().has("editshot"):
		_edit_mode.toggle()
		_edit_mode._select(_edit_mode._editables.find(_find_left_flipper()))
		_screenshot_countdown = 20

func _boot_from_definition() -> void:
	var def := TableDefinition.load_from(DEFAULT_TABLE_PATH)
	if def == null:
		push_error("[PhysicsSpike] --loadtable: could not load " + DEFAULT_TABLE_PATH)
		return
	var result := TableLoader.build(def, _table)
	print("[PhysicsSpike] Built table from definition: %d components, %d errors"
		% [result["built"], (result["errors"] as Array).size()])

func _export_default_table() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/pinball/tables")
	var def := TableLoader.serialize(_table, "physics_spike_default", "Physics Spike (default)",
		{"tuning": "res://data/pinball/table_tuning.tres"})
	var err := def.save_to(DEFAULT_TABLE_PATH)
	print("[PhysicsSpike] Exported default table (%d components) to %s (err %d)"
		% [def.components.size(), ProjectSettings.globalize_path(DEFAULT_TABLE_PATH), err])
	get_tree().quit()

func _ensure_environment() -> void:
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

	_watchdog = preload("res://scripts/pinball/ball_watchdog.gd").new()
	_watchdog.name = "BallWatchdog"
	_watchdog.ball = _ball
	_watchdog.overlay = _overlay
	_debug_root.add_child(_watchdog)

	_panel = preload("res://scripts/pinball/tuning_panel.gd").new()
	_panel.name = "TuningPanel"
	_panel.tuning = tuning
	_panel.baseline = _baseline
	_panel.ball = _ball
	_debug_root.add_child(_panel)

	_edit_mode = preload("res://scripts/pinball/edit_mode.gd").new()
	_edit_mode.name = "EditMode"
	_edit_mode.table = _table
	_edit_mode.spike = self
	_debug_root.add_child(_edit_mode)

	_refresh_table_refs()

## Re-point debug tools at the current table components (after an Edit Mode load).
func _refresh_table_refs() -> void:
	_overlay.ball = _ball
	_overlay.plunger = _find_plunger()
	_overlay.left_flipper = _find_left_flipper()

## Called by EditMode after it rebuilds the table from a definition.
func on_table_rebuilt() -> void:
	_refresh_table_refs()
	reset_ball()

func _find_plunger() -> Plunger:
	for child in _table.get_children():
		if child is Plunger:
			return child
	return null

func _find_left_flipper() -> Flipper:
	for child in _table.get_children():
		if child is Flipper and (child as Flipper).side == Flipper.Side.LEFT:
			return child
	return null

func get_spawn_position() -> Vector3:
	var marker := _table.get_node_or_null("BallSpawn")
	if marker == null:
		for child in _table.get_children():
			if child is Marker3D:
				marker = child
				break
	return (marker as Node3D).global_position if marker != null else FALLBACK_SPAWN

# ------------------------------------------------------------------------
# Ball lifecycle
# ------------------------------------------------------------------------
func _on_ball_drained(_drained_ball: Node) -> void:
	reset_ball()

func reset_ball() -> void:
	if is_instance_valid(_ball):
		_ball.reset_to(get_spawn_position())

# ------------------------------------------------------------------------
# Debug / QA input (suppressed while Edit Mode owns input)
# ------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _edit_mode != null and _edit_mode.is_active():
		return

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
