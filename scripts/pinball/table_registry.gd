class_name TableRegistry
extends RefCounted

## Single source of truth mapping table component TYPE <-> reusable scene <->
## serializable properties. Used by TableLoader (build/serialize) and EditMode
## (palette). Behaviour stays in the component scripts; this only describes which
## reusable scene backs each type and which exported properties are layout data.

## type -> component scene path. "ball_spawn" is a bare Marker3D (no scene).
const SCENES: Dictionary = {
	"wall": "res://scenes/pinball/wall.tscn",
	"bumper": "res://scenes/pinball/bumper.tscn",
	"slingshot": "res://scenes/pinball/slingshot.tscn",
	"ramp": "res://scenes/pinball/ramp.tscn",
	"drain": "res://scenes/pinball/drain.tscn",
	"plunger": "res://scenes/pinball/plunger.tscn",
	"flipper": "res://scenes/pinball/flipper.tscn",
}

## type -> exported property names that are layout/config data (serialized).
const PROPS: Dictionary = {
	"wall": ["size", "wall_color", "friction", "bounce"],
	"bumper": ["radius", "height"],
	"slingshot": ["length", "thickness", "height"],
	"ramp": ["ramp_length", "ramp_width", "ramp_thickness", "ramp_pitch_degrees", "side_wall_height"],
	"drain": ["size"],
	"plunger": ["trigger_size", "min_charge"],
	"flipper": ["side", "action_name", "rest_droop_degrees", "bat_length"],
	"ball_spawn": [],
}

## Types offered in the Edit Mode add palette (order = palette slots 1..N).
const PALETTE: PackedStringArray = ["wall", "bumper", "slingshot", "ramp", "drain", "flipper", "ball_spawn"]

static func is_known(type: String) -> bool:
	return type == "ball_spawn" or SCENES.has(type)

static func instantiate(type: String) -> Node3D:
	if type == "ball_spawn":
		return Marker3D.new()
	if SCENES.has(type):
		var packed: PackedScene = load(SCENES[type])
		if packed != null:
			return packed.instantiate() as Node3D
	return null

## Classify a live node into a component type ("" if not an editable component).
static func type_of(node: Node) -> String:
	if node is TableWall:
		return "wall"
	if node is Bumper:
		return "bumper"
	if node is Slingshot:
		return "slingshot"
	if node is Ramp:
		return "ramp"
	if node is Drain:
		return "drain"
	if node is Plunger:
		return "plunger"
	if node is Flipper:
		return "flipper"
	if node is Marker3D:
		return "ball_spawn"
	return ""

static func props_of(type: String) -> Array:
	return PROPS.get(type, [])

## Convert a live property value into JSON-safe data.
static func value_to_json(v: Variant) -> Variant:
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Color:
		return [v.r, v.g, v.b, v.a]
	if v is StringName:
		return String(v)
	return v

## Coerce JSON data back into the type of an existing property value.
static func value_from_json(json_val: Variant, like: Variant) -> Variant:
	if like is Vector3 and json_val is Array and json_val.size() >= 3:
		return Vector3(json_val[0], json_val[1], json_val[2])
	if like is Color and json_val is Array and json_val.size() >= 3:
		var a: float = json_val[3] if json_val.size() > 3 else 1.0
		return Color(json_val[0], json_val[1], json_val[2], a)
	if like is StringName:
		return StringName(str(json_val))
	if like is int:
		return int(json_val)
	if like is float:
		return float(json_val)
	return json_val

static func read_props(node: Node, type: String) -> Dictionary:
	var out: Dictionary = {}
	for key in props_of(type):
		out[key] = value_to_json(node.get(key))
	return out

static func apply_props(node: Node, type: String, props: Dictionary) -> void:
	for key in props_of(type):
		if props.has(key):
			var current: Variant = node.get(key)
			node.set(key, value_from_json(props[key], current))
