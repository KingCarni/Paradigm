class_name TableRegistry
extends RefCounted

## Single source of truth describing every editable table component: which reusable
## scene backs it, its editor/library metadata, and which properties are layout
## data. Used by TableLoader (build/serialize), the Asset Library and the property
## Inspector. Component BEHAVIOUR stays in the component scripts; this only
## describes data. New components (Tesla bumper, portal, spinner, ...) become
## editor-visible by adding a META entry here — no editor UI rewrite.
##
## META is the authoritative source. SCENES / PROPS / PALETTE are derived from it.

## Ordered category list for the Asset Library.
const CATEGORIES: PackedStringArray = [
	"Flippers", "Bumpers", "Slingshots", "Ramps", "Walls / Guides",
	"Targets", "Lanes / Spawns", "Utility",
]

## type -> metadata. editable_properties entries:
##   {name, label, type("float"|"int"|"enum"|"vector3"|"color"), min, max, step, options}
const META: Dictionary = {
	"flipper": {
		"display_name": "Flipper",
		"category": "Flippers",
		"scene": "res://scenes/pinball/flipper.tscn",
		"description": "Player-controlled bat. Left/right handedness set by 'side'.",
		"icon": "🏓",
		"default_properties": {"side": 0, "action_name": "flipper_left", "rest_droop_degrees": 22.0, "bat_length": 3.2},
		"editable_properties": [
			{"name": "side", "label": "Side", "type": "enum", "options": [{"value": 0, "label": "Left"}, {"value": 1, "label": "Right"}]},
			{"name": "action_name", "label": "Input Action", "type": "enum", "options": [{"value": "flipper_left", "label": "flipper_left"}, {"value": "flipper_right", "label": "flipper_right"}]},
			{"name": "bat_length", "label": "Bat Length", "type": "float", "min": 1.0, "max": 6.0, "step": 0.1},
			{"name": "rest_droop_degrees", "label": "Rest Droop", "type": "float", "min": 0.0, "max": 60.0, "step": 1.0},
		],
		"placement_tags": ["flipper_zone"],
	},
	"bumper": {
		"display_name": "Pop Bumper",
		"category": "Bumpers",
		"scene": "res://scenes/pinball/bumper.tscn",
		"description": "Solid bumper that pops the ball outward. Impulse -1 = use global tuning.",
		"icon": "⬤",
		"default_properties": {"radius": 1.0, "height": 1.6, "impulse_override": -1.0},
		"editable_properties": [
			{"name": "radius", "label": "Radius", "type": "float", "min": 0.3, "max": 3.0, "step": 0.1},
			{"name": "height", "label": "Height", "type": "float", "min": 0.4, "max": 4.0, "step": 0.1},
			{"name": "impulse_override", "label": "Impulse (-1=global)", "type": "float", "min": -1.0, "max": 120.0, "step": 1.0},
		],
		"placement_tags": ["playfield"],
	},
	"slingshot": {
		"display_name": "Slingshot",
		"category": "Slingshots",
		"scene": "res://scenes/pinball/slingshot.tscn",
		"description": "Angled kicker. Impulse -1 = use global tuning.",
		"icon": "◣",
		"default_properties": {"length": 2.2, "thickness": 0.4, "height": 1.6, "impulse_override": -1.0},
		"editable_properties": [
			{"name": "length", "label": "Length", "type": "float", "min": 0.6, "max": 6.0, "step": 0.1},
			{"name": "thickness", "label": "Thickness", "type": "float", "min": 0.2, "max": 1.5, "step": 0.05},
			{"name": "height", "label": "Height", "type": "float", "min": 0.4, "max": 4.0, "step": 0.1},
			{"name": "impulse_override", "label": "Impulse (-1=global)", "type": "float", "min": -1.0, "max": 120.0, "step": 1.0},
		],
		"placement_tags": ["playfield"],
	},
	"ramp": {
		"display_name": "Ramp",
		"category": "Ramps",
		"scene": "res://scenes/pinball/ramp.tscn",
		"description": "Elevated channel. Rise = length x sin(pitch).",
		"icon": "◺",
		"default_properties": {"ramp_length": 6.0, "ramp_width": 1.5, "ramp_thickness": 0.35, "ramp_pitch_degrees": 18.0, "side_wall_height": 2.2},
		"editable_properties": [
			{"name": "ramp_length", "label": "Length", "type": "float", "min": 2.0, "max": 16.0, "step": 0.5},
			{"name": "ramp_width", "label": "Width", "type": "float", "min": 0.8, "max": 4.0, "step": 0.1},
			{"name": "ramp_pitch_degrees", "label": "Pitch (rise)", "type": "float", "min": 5.0, "max": 40.0, "step": 1.0},
			{"name": "side_wall_height", "label": "Side Wall H", "type": "float", "min": 0.5, "max": 4.0, "step": 0.1},
			{"name": "ramp_thickness", "label": "Thickness", "type": "float", "min": 0.15, "max": 1.0, "step": 0.05},
		],
		"placement_tags": ["playfield"],
	},
	"wall": {
		"display_name": "Wall / Guide",
		"category": "Walls / Guides",
		"scene": "res://scenes/pinball/wall.tscn",
		"description": "Box collider used for walls, lane guides, deflectors and the floor.",
		"icon": "▬",
		"default_properties": {"size": [2.0, 2.0, 0.5], "wall_color": [0.30, 0.32, 0.38, 1.0], "friction": 0.1, "bounce": 0.3},
		"editable_properties": [
			{"name": "size", "label": "Size", "type": "vector3", "min": 0.1, "max": 60.0, "step": 0.1},
			{"name": "friction", "label": "Friction", "type": "float", "min": 0.0, "max": 2.0, "step": 0.05},
			{"name": "bounce", "label": "Bounce", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05},
			{"name": "wall_color", "label": "Color", "type": "color"},
		],
		"placement_tags": ["structure"],
	},
	"drain": {
		"display_name": "Drain",
		"category": "Utility",
		"scene": "res://scenes/pinball/drain.tscn",
		"description": "Trigger volume that drains the ball.",
		"icon": "▽",
		"default_properties": {"size": [6.0, 2.0, 1.5]},
		"editable_properties": [
			{"name": "size", "label": "Size", "type": "vector3", "min": 0.5, "max": 30.0, "step": 0.1},
		],
		"placement_tags": ["utility"],
	},
	"plunger": {
		"display_name": "Plunger / Launcher",
		"category": "Lanes / Spawns",
		"scene": "res://scenes/pinball/plunger.tscn",
		"description": "Hold-to-charge launcher trigger at the base of the shooter lane.",
		"icon": "⤒",
		"default_properties": {"trigger_size": [1.4, 1.5, 4.0], "min_charge": 0.15},
		"editable_properties": [
			{"name": "trigger_size", "label": "Trigger Size", "type": "vector3", "min": 0.3, "max": 20.0, "step": 0.1},
			{"name": "min_charge", "label": "Min Charge", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05},
		],
		"placement_tags": ["lane"],
	},
	"ball_spawn": {
		"display_name": "Ball Spawn",
		"category": "Lanes / Spawns",
		"scene": "",
		"description": "Marker where the ball spawns / resets.",
		"icon": "◎",
		"default_properties": {},
		"editable_properties": [],
		"placement_tags": ["lane"],
	},
}

# ------------------------------------------------------------------------
# Type lookups
# ------------------------------------------------------------------------
static func all_types() -> Array:
	return META.keys()

static func is_known(type: String) -> bool:
	return META.has(type)

static func meta_of(type: String) -> Dictionary:
	return META.get(type, {})

static func display_name(type: String) -> String:
	return str(meta_of(type).get("display_name", type))

static func icon(type: String) -> String:
	return str(meta_of(type).get("icon", "▪"))

static func description(type: String) -> String:
	return str(meta_of(type).get("description", ""))

static func category(type: String) -> String:
	return str(meta_of(type).get("category", "Utility"))

static func scene_path(type: String) -> String:
	return str(meta_of(type).get("scene", ""))

static func default_properties(type: String) -> Dictionary:
	return (meta_of(type).get("default_properties", {}) as Dictionary).duplicate(true)

static func editable_properties(type: String) -> Array:
	return meta_of(type).get("editable_properties", [])

static func placement_tags(type: String) -> Array:
	return meta_of(type).get("placement_tags", [])

## Types in a category, ordered as META declares them.
static func types_in_category(cat: String) -> Array:
	var out: Array = []
	for type in META.keys():
		if category(type) == cat:
			out.append(type)
	return out

## Palette order (all placeable types).
static func palette() -> Array:
	return META.keys()

# ------------------------------------------------------------------------
# Instantiate / classify
# ------------------------------------------------------------------------
static func instantiate(type: String) -> Node3D:
	if not is_known(type):
		return null
	var path := scene_path(type)
	if path == "":
		return Marker3D.new()  # ball_spawn
	var packed: PackedScene = load(path)
	return packed.instantiate() as Node3D if packed != null else null

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

## Serialized property names (from editable metadata).
static func props_of(type: String) -> Array:
	var out: Array = []
	for p in editable_properties(type):
		out.append(p["name"])
	return out

## Metadata for a single editable property, or {} if not editable.
static func property_meta(type: String, key: String) -> Dictionary:
	for p in editable_properties(type):
		if p["name"] == key:
			return p
	return {}

# ------------------------------------------------------------------------
# JSON coercion
# ------------------------------------------------------------------------
static func value_to_json(v: Variant) -> Variant:
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Color:
		return [v.r, v.g, v.b, v.a]
	if v is StringName:
		return String(v)
	return v

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

# ------------------------------------------------------------------------
# Validation / clamping (for the Inspector; explicit metadata, no reflection)
# ------------------------------------------------------------------------
static func clamp_property(type: String, key: String, value: Variant) -> Variant:
	var pm := property_meta(type, key)
	if pm.is_empty():
		return value
	match str(pm.get("type", "")):
		"float":
			return clampf(float(value), float(pm["min"]), float(pm["max"]))
		"int":
			return clampi(int(value), int(pm["min"]), int(pm["max"]))
		"vector3":
			var v: Vector3 = value if value is Vector3 else Vector3.ZERO
			var lo := float(pm["min"])
			var hi := float(pm["max"])
			return Vector3(clampf(v.x, lo, hi), clampf(v.y, lo, hi), clampf(v.z, lo, hi))
		"enum":
			for opt in pm["options"]:
				if opt["value"] == value or str(opt["value"]) == str(value):
					return opt["value"]
			return pm["options"][0]["value"]
		_:
			return value
