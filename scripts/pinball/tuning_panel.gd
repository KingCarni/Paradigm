class_name TuningPanel
extends CanvasLayer

## Live physics-tuning panel for rapid human feel iteration (DEBUG only).
##
## Keyboard driven so it needs no widget framework:
##   F4            toggle panel
##   Up / Down     select parameter
##   Left / Right  decrease / increase   (hold Shift for a coarse step)
##   Home          reset all values to the authored baseline
##   End           save/export current values (console + user://tuning_export.tres)
##
## Values are written straight into the shared PinballTuning resource, so gravity,
## incline, impulses, flipper speeds and max velocity take effect immediately.
## Ball mass/restitution/friction are re-applied to the live body on change.

@export var tuning: PinballTuning
var baseline: PinballTuning
var ball: PinballBall

const PARAMS: Array = [
	{"name": "gravity_strength", "label": "gravity", "step": 1.0, "coarse": 5.0, "min": 0.0, "max": 300.0, "physics": false},
	{"name": "playfield_incline_degrees", "label": "incline (deg)", "step": 0.5, "coarse": 2.0, "min": 0.0, "max": 30.0, "physics": false},
	{"name": "ball_restitution", "label": "restitution", "step": 0.02, "coarse": 0.1, "min": 0.0, "max": 1.0, "physics": true},
	{"name": "ball_friction", "label": "friction", "step": 0.02, "coarse": 0.1, "min": 0.0, "max": 2.0, "physics": true},
	{"name": "ball_linear_damp", "label": "linear damp", "step": 0.02, "coarse": 0.1, "min": 0.0, "max": 5.0, "physics": true},
	{"name": "ball_mass", "label": "ball mass", "step": 0.1, "coarse": 0.5, "min": 0.1, "max": 20.0, "physics": true},
	{"name": "flipper_press_speed", "label": "flip press", "step": 50.0, "coarse": 200.0, "min": 100.0, "max": 6000.0, "physics": false},
	{"name": "flipper_return_speed", "label": "flip return", "step": 50.0, "coarse": 200.0, "min": 100.0, "max": 4000.0, "physics": false},
	{"name": "flipper_travel_degrees", "label": "flip travel", "step": 1.0, "coarse": 5.0, "min": 10.0, "max": 90.0, "physics": false},
	{"name": "bumper_impulse", "label": "bumper", "step": 1.0, "coarse": 5.0, "min": 0.0, "max": 100.0, "physics": false},
	{"name": "slingshot_impulse", "label": "slingshot", "step": 1.0, "coarse": 5.0, "min": 0.0, "max": 100.0, "physics": false},
	{"name": "launcher_strength", "label": "launcher", "step": 2.0, "coarse": 10.0, "min": 0.0, "max": 200.0, "physics": false},
	{"name": "max_ball_velocity", "label": "max velocity", "step": 5.0, "coarse": 20.0, "min": 10.0, "max": 400.0, "physics": false},
]

const SAVE_FIELDS: PackedStringArray = [
	"ball_radius", "ball_mass", "ball_restitution", "ball_friction",
	"ball_linear_damp", "ball_angular_damp", "gravity_strength",
	"playfield_incline_degrees", "flipper_travel_degrees", "flipper_press_speed",
	"flipper_return_speed", "bumper_impulse", "slingshot_impulse",
	"launcher_strength", "launcher_charge_rate", "max_ball_velocity", "nudge_impulse",
]

var _label: Label
var _selected: int = 0
var _last_saved_path: String = ""

func _ready() -> void:
	layer = 2
	var panel := PanelContainer.new()
	panel.position = Vector2(940, 12)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	panel.add_child(_label)
	visible = false

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F4:
		# Live Tuning and Edit Mode are mutually exclusive.
		var ed := get_tree().get_first_node_in_group("table_editor")
		if ed != null and ed.has_method("is_active") and bool(ed.call("is_active")):
			return
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return

	match event.keycode:
		KEY_UP:
			_selected = wrapi(_selected - 1, 0, PARAMS.size())
		KEY_DOWN:
			_selected = wrapi(_selected + 1, 0, PARAMS.size())
		KEY_LEFT:
			_adjust(-1.0, event.shift_pressed)
		KEY_RIGHT:
			_adjust(1.0, event.shift_pressed)
		KEY_HOME:
			_reset_to_baseline()
		KEY_END:
			_save()
		_:
			return
	get_viewport().set_input_as_handled()

func _adjust(direction: float, coarse: bool) -> void:
	var p: Dictionary = PARAMS[_selected]
	var step: float = p["coarse"] if coarse else p["step"]
	var value: float = float(tuning.get(p["name"])) + direction * step
	value = clampf(value, p["min"], p["max"])
	tuning.set(p["name"], value)
	if p["physics"] and is_instance_valid(ball):
		ball.apply_physics_from_tuning()

func _reset_to_baseline() -> void:
	if baseline == null:
		return
	for p in PARAMS:
		tuning.set(p["name"], baseline.get(p["name"]))
	if is_instance_valid(ball):
		ball.apply_physics_from_tuning()

func _save() -> void:
	var lines := PackedStringArray()
	lines.append("# Paradigm tuning export - paste into the [resource] block of")
	lines.append("# res://data/pinball/table_tuning.tres")
	for field in SAVE_FIELDS:
		lines.append("%s = %s" % [field, str(tuning.get(field))])
	var text := "\n".join(lines)
	print("\n", text, "\n")
	var f := FileAccess.open("user://tuning_export.tres", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
		_last_saved_path = ProjectSettings.globalize_path("user://tuning_export.tres")
		print("[TuningPanel] Saved to ", _last_saved_path)

func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray()
	lines.append("LIVE TUNING  (F4 close)")
	lines.append("Up/Down select  Left/Right adjust  Shift=coarse")
	lines.append("Home reset baseline   End save/export")
	lines.append("")
	for i in PARAMS.size():
		var p: Dictionary = PARAMS[i]
		var marker := ">" if i == _selected else " "
		lines.append("%s %-13s %8.2f" % [marker, p["label"], float(tuning.get(p["name"]))])
	if _last_saved_path != "":
		lines.append("")
		lines.append("saved: " + _last_saved_path)
	_label.text = "\n".join(lines)
