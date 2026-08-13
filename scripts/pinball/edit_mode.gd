class_name EditMode
extends Node

## Developer-only table Edit Mode v0 (NOT a production editor).
##
## Pauses the tree (suspends ball physics safely), lets the developer select,
## move, rotate, scale, duplicate, delete and add table components, then resume
## Play to test immediately. Layouts save/load via the JSON table-definition
## format (TableLoader / TableDefinition). Keyboard-driven — no production gizmos.
##
## Controls (while active):
##   Tab / Shift+Tab   cycle selection
##   Arrows            move on X/Z    PageUp/PageDown  move on Y   (Shift = coarse)
##   , / .             rotate yaw     - / =            scale down/up
##   Delete            delete         Insert           duplicate
##   1..7              add component from palette
##   Ctrl+S / Ctrl+L   save / load dev layout      Ctrl+D  load default table
##   F2                exit Edit Mode

const DEV_LAYOUT_PATH: String = "user://tables/dev_layout.json"
const DEFAULT_TABLE_PATH: String = "res://data/pinball/tables/default_table.json"

var table: Node3D
var spike: Node   # PhysicsSpike, for ball reset / ref refresh

var active: bool = false
var _editables: Array = []
var _selected: int = -1
var _saved_overrides: Dictionary = {}
var _status: String = ""

var _layer: CanvasLayer
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 360)
	_layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 1.0))
	panel.add_child(_label)
	_layer.visible = false

func is_active() -> bool:
	return active

func toggle() -> void:
	if active:
		_exit()
	else:
		_enter()

func _enter() -> void:
	active = true
	get_tree().paused = true
	_refresh_editables()
	_select(0)
	_layer.visible = true

func _exit() -> void:
	_clear_highlight()
	active = false
	_layer.visible = false
	if spike != null and spike.has_method("reset_ball"):
		spike.reset_ball()
	get_tree().paused = false

func _refresh_editables() -> void:
	_editables.clear()
	if table == null:
		return
	for child in table.get_children():
		if TableRegistry.type_of(child) != "":
			_editables.append(child)

func _select(index: int) -> void:
	_clear_highlight()
	if _editables.is_empty():
		_selected = -1
		return
	_selected = wrapi(index, 0, _editables.size())
	_apply_highlight(_selected_node())

func _selected_node() -> Node3D:
	if _selected < 0 or _selected >= _editables.size():
		return null
	return _editables[_selected] as Node3D

# ------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F2:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return

	var handled := true
	var coarse := key.shift_pressed
	var move_step := 2.0 if coarse else 0.5
	var rot_step := deg_to_rad(15.0 if coarse else 5.0)

	if key.ctrl_pressed:
		match key.keycode:
			KEY_S: _save_layout()
			KEY_L: _load_layout(DEV_LAYOUT_PATH, "dev layout")
			KEY_D: _load_layout(DEFAULT_TABLE_PATH, "default table")
			_: handled = false
	else:
		match key.keycode:
			KEY_TAB:
				_select(_selected + (-1 if key.shift_pressed else 1))
			KEY_LEFT: _translate(Vector3(-move_step, 0, 0))
			KEY_RIGHT: _translate(Vector3(move_step, 0, 0))
			KEY_UP: _translate(Vector3(0, 0, -move_step))
			KEY_DOWN: _translate(Vector3(0, 0, move_step))
			KEY_PAGEUP: _translate(Vector3(0, move_step, 0))
			KEY_PAGEDOWN: _translate(Vector3(0, -move_step, 0))
			KEY_COMMA: _rotate_yaw(-rot_step)
			KEY_PERIOD: _rotate_yaw(rot_step)
			KEY_MINUS: _scale(0.9)
			KEY_EQUAL: _scale(1.0 / 0.9)
			KEY_DELETE: _delete_selected()
			KEY_INSERT: _duplicate_selected()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
				_add_from_palette(key.keycode - KEY_1)
			_: handled = false

	if handled:
		get_viewport().set_input_as_handled()

func _translate(delta: Vector3) -> void:
	var n := _selected_node()
	if n != null:
		n.position += delta

func _rotate_yaw(delta: float) -> void:
	var n := _selected_node()
	if n != null:
		n.rotation.y += delta

func _scale(factor: float) -> void:
	var n := _selected_node()
	if n != null:
		n.scale *= factor

func _delete_selected() -> void:
	var n := _selected_node()
	if n == null:
		return
	var idx := _selected
	_clear_highlight()
	table.remove_child(n)
	n.queue_free()
	_refresh_editables()
	_select(idx)
	_status = "deleted"

func _duplicate_selected() -> void:
	var n := _selected_node()
	if n == null:
		return
	var type := TableRegistry.type_of(n)
	var copy := TableRegistry.instantiate(type)
	if copy == null:
		return
	copy.name = _unique_id(type)
	copy.transform = n.transform
	copy.position += Vector3(1.5, 0.0, 1.5)
	table.add_child(copy)
	TableRegistry.apply_props(copy, type, TableRegistry.read_props(n, type))
	_refresh_editables()
	_select(_editables.find(copy))
	_status = "duplicated -> " + copy.name

func _add_from_palette(slot: int) -> void:
	if slot < 0 or slot >= TableRegistry.PALETTE.size():
		return
	var type := String(TableRegistry.PALETTE[slot])
	var node := TableRegistry.instantiate(type)
	if node == null:
		return
	node.name = _unique_id(type)
	node.position = Vector3(0.0, 0.6, 2.0)
	table.add_child(node)
	_refresh_editables()
	_select(_editables.find(node))
	_status = "added " + type + " -> " + node.name

func _unique_id(type: String) -> String:
	var i := 1
	while table.has_node(NodePath("%s_%d" % [type, i])):
		i += 1
	return "%s_%d" % [type, i]

# ------------------------------------------------------------------------
# Save / load
# ------------------------------------------------------------------------
func _save_layout() -> void:
	DirAccess.make_dir_recursive_absolute("user://tables")
	var def := TableLoader.serialize(table, "dev_layout", "Developer Layout", _current_settings())
	var err := def.save_to(DEV_LAYOUT_PATH)
	if err == OK:
		_status = "saved -> " + ProjectSettings.globalize_path(DEV_LAYOUT_PATH)
		print("[EditMode] ", _status)
	else:
		_status = "SAVE FAILED (%d)" % err

func _load_layout(path: String, label: String) -> void:
	var def := TableDefinition.load_from(path)
	if def == null:
		_status = "LOAD FAILED: " + path
		return
	_clear_highlight()
	var result := TableLoader.build(def, table)
	_refresh_editables()
	_select(0)
	if spike != null and spike.has_method("on_table_rebuilt"):
		spike.on_table_rebuilt()
	_status = "loaded %s (%d built, %d errors)" % [label, result["built"], (result["errors"] as Array).size()]
	print("[EditMode] ", _status)

func _current_settings() -> Dictionary:
	return {"tuning": "res://data/pinball/table_tuning.tres"}

# ------------------------------------------------------------------------
# Selection highlight
# ------------------------------------------------------------------------
func _apply_highlight(node: Node3D) -> void:
	if node == null:
		return
	var hl := StandardMaterial3D.new()
	hl.albedo_color = Color(1.0, 0.85, 0.1)
	hl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in _find_meshes(node):
		_saved_overrides[mesh] = mesh.material_override
		mesh.material_override = hl

func _clear_highlight() -> void:
	for mesh in _saved_overrides:
		if is_instance_valid(mesh):
			mesh.material_override = _saved_overrides[mesh]
	_saved_overrides.clear()

func _find_meshes(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_find_meshes(child))
	return out

# ------------------------------------------------------------------------
# UI
# ------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not active:
		return
	var lines := PackedStringArray()
	lines.append("== EDIT MODE (dev) ==   F2 exit")
	var n := _selected_node()
	if n != null:
		var type := TableRegistry.type_of(n)
		lines.append("selected [%d/%d]  %s  (%s)" % [_selected + 1, _editables.size(), n.name, type])
		lines.append("pos (%.1f, %.1f, %.1f)  yawdeg %.0f  scale %.2f"
			% [n.position.x, n.position.y, n.position.z, rad_to_deg(n.rotation.y), n.scale.x])
	else:
		lines.append("no component selected (add one with 1..7)")
	lines.append("")
	lines.append("Tab select | arrows move XZ | PgUp/PgDn Y | Shift coarse")
	lines.append(", . rotate | - = scale | Del delete | Ins duplicate")
	lines.append("add: " + " ".join(_palette_hint()))
	lines.append("Ctrl+S save  Ctrl+L load  Ctrl+D default")
	if _status != "":
		lines.append("")
		lines.append(_status)
	_label.text = "\n".join(lines)

func _palette_hint() -> PackedStringArray:
	var out := PackedStringArray()
	for i in TableRegistry.PALETTE.size():
		out.append("%d=%s" % [i + 1, TableRegistry.PALETTE[i]])
	return out
