class_name DebugOverlay
extends CanvasLayer

## Lightweight tuning/QA overlay for the physics spike.
##
## Display-only: shows live ball state, plunger charge, event counters and the
## current tuning values so they can be observed while tuning. Hotkeys for
## reset/restart/toggle are owned by the table (PhysicsSpike), which calls
## set_active() here. Nothing gameplay-authoritative lives in the overlay.

@export var tuning: PinballTuning

var _label: Label
var ball: PinballBall
var plunger: Plunger

var _bumper_hits: int = 0
var _slingshot_hits: int = 0
var _ramp_completions: int = 0
var _launches: int = 0
var _drains: int = 0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")

	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	_label.add_theme_font_size_override("font_size", 15)
	add_child(_label)

	GameEvents.component_hit.connect(_on_component_hit)
	GameEvents.component_completed.connect(_on_component_completed)
	GameEvents.ball_drained.connect(_on_ball_drained)

func set_active(active: bool) -> void:
	visible = active

func _on_component_hit(_component: Node3D, _ball: Node3D, context: Dictionary) -> void:
	match context.get("type", ""):
		"bumper":
			_bumper_hits += 1
		"slingshot":
			_slingshot_hits += 1
		"launch":
			_launches += 1

func _on_component_completed(_component: Node3D, context: Dictionary) -> void:
	if context.get("type", "") == "ramp":
		_ramp_completions += 1

func _on_ball_drained(_ball: Node3D) -> void:
	_drains += 1

func _process(_delta: float) -> void:
	if not visible:
		return
	var speed := 0.0
	var pos := Vector3.ZERO
	if is_instance_valid(ball):
		speed = ball.linear_velocity.length()
		pos = ball.global_position
	var charge := 0.0
	if is_instance_valid(plunger):
		charge = plunger.get_charge()

	var lines := PackedStringArray()
	lines.append("PARADIGM - PHYSICS SPIKE (greybox)")
	lines.append("FPS %d | physics %d Hz" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second])
	lines.append("")
	lines.append("BALL  speed %5.1f u/s  (max %.0f)" % [speed, tuning.max_ball_velocity])
	lines.append("      pos (%5.1f, %4.1f, %5.1f)" % [pos.x, pos.y, pos.z])
	lines.append("PLUNGER charge %3.0f%%" % [charge * 100.0])
	lines.append("")
	lines.append("EVENTS  bumpers %d  slings %d  ramp %d  launches %d  drains %d"
		% [_bumper_hits, _slingshot_hits, _ramp_completions, _launches, _drains])
	lines.append("")
	lines.append("TUNING  gravity %.0f  incline %.0f deg  maxV %.0f"
		% [tuning.gravity_strength, tuning.playfield_incline_degrees, tuning.max_ball_velocity])
	lines.append("        flipper travel %.0f  press %.0f  return %.0f"
		% [tuning.flipper_travel_degrees, tuning.flipper_press_speed, tuning.flipper_return_speed])
	lines.append("        bumper %.0f  sling %.0f  launcher %.0f"
		% [tuning.bumper_impulse, tuning.slingshot_impulse, tuning.launcher_strength])
	lines.append("")
	lines.append("CONTROLS  A/D or LB/RB flippers | Space/A hold+release launch")
	lines.append("          Q/E nudge | R reset ball | F5 restart | F3 overlay | Esc pause")
	_label.text = "\n".join(lines)
