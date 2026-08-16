class_name TableEditor
extends Node

## Developer Table Editor v1 — controller / model (dev-only).
##
## Pure logic layer: owns editor state (selection, snap, mode, dirty, undo/redo)
## and all operations, emitting signals for the view (EditorShell) to render. It
## has NO widgets, so it is headless-testable. The live `Table` node is the source
## of truth; it serializes to/from the JSON table-definition on save/load.
##
## Registered in group "table_editor"; flippers query is_active() to release
## sync_to_physics while editing.

signal selection_changed(node)
signal table_changed()          ## structure/transform/property mutated
signal mode_changed(editing)
signal history_changed()
signal status(message)

const SOURCE_DIR := "res://data/pinball/tables"
const USER_DIR := "user://tables"
const HISTORY_MAX := 64
const PICK_LAYER_COMPONENT := 1
const PICK_LAYER_PROXY := 2
const PICK_LAYER_GIZMO := 4

var table: Node3D
var spike: Node
var camera: Camera3D

var editing: bool = false
var selected: Node3D = null
var position_snap: float = 0.5   ## 0 = off
var rotation_snap_deg: float = 15.0  ## 0 = off

var current_id: String = "physics_spike_default"
var current_name: String = "Physics Spike (default)"
var current_path: String = ""
var dirty: bool = false

var _undo: Array = []
var _redo: Array = []
var _gesture_before: Transform3D = Transform3D.IDENTITY
var _gesture_node: Node3D = null

func setup(table_node: Node3D, spike_node: Node, cam: Camera3D) -> void:
	table = table_node
	spike = spike_node
	camera = cam
	add_to_group("table_editor")
	_ensure_pick_proxies()

func is_active() -> bool:
	return editing

# ------------------------------------------------------------------------
# Mode
# ------------------------------------------------------------------------
func set_editing(value: bool) -> void:
	if editing == value:
		return
	editing = value
	if editing:
		_ensure_pick_proxies()
		if spike != null and spike.has_method("enter_edit_mode"):
			spike.enter_edit_mode()
		_set_flippers_editing(true)
	else:
		clear_selection()
		_set_flippers_editing(false)
		if spike != null and spike.has_method("enter_play_mode"):
			spike.enter_play_mode()
	mode_changed.emit(editing)

## Flippers are AnimatableBody3D: while editing we must release sync_to_physics so
## direct transform edits stick. Drive this deterministically (not per-frame race).
func _set_flippers_editing(on: bool) -> void:
	if table == null:
		return
	for c in table.get_children():
		if c is Flipper:
			if on:
				(c as Flipper).begin_table_edit()
			else:
				(c as Flipper).end_table_edit()

func toggle_mode() -> void:
	set_editing(not editing)

# ------------------------------------------------------------------------
# Snapping
# ------------------------------------------------------------------------
func snap_scalar(v: float, step: float) -> float:
	return roundf(v / step) * step if step > 0.0 else v

func snap_position(p: Vector3) -> Vector3:
	if position_snap <= 0.0:
		return p
	return Vector3(snap_scalar(p.x, position_snap), snap_scalar(p.y, position_snap), snap_scalar(p.z, position_snap))

func snap_yaw(rad: float) -> float:
	if rotation_snap_deg <= 0.0:
		return rad
	var step := deg_to_rad(rotation_snap_deg)
	return roundf(rad / step) * step

# ------------------------------------------------------------------------
# Selection / picking
# ------------------------------------------------------------------------
func select(node: Node3D) -> void:
	selected = node
	selection_changed.emit(selected)

func clear_selection() -> void:
	if selected != null:
		selected = null
		selection_changed.emit(null)

func raycast(screen_pos: Vector2, mask: int) -> Dictionary:
	if camera == null or table == null:
		return {}
	var space := table.get_world_3d().direct_space_state
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 2000.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_bodies = true
	q.collide_with_areas = true
	q.collision_mask = mask
	return space.intersect_ray(q)

## Return the editable component (direct child of table) under the cursor, or null.
func pick_component(screen_pos: Vector2) -> Node3D:
	var hit := raycast(screen_pos, PICK_LAYER_COMPONENT | PICK_LAYER_PROXY)
	if hit.is_empty():
		return null
	return _component_root(hit.get("collider"))

func _component_root(node: Node) -> Node3D:
	var n: Node = node
	while n != null:
		if n.get_parent() == table and TableRegistry.type_of(n) != "":
			return n as Node3D
		n = n.get_parent()
	return null

# ------------------------------------------------------------------------
# Transform ops
# ------------------------------------------------------------------------
## Live drag: bracket with gesture_begin/commit so the whole drag is one undo step.
func gesture_begin() -> void:
	if selected != null:
		_gesture_node = selected
		_gesture_before = selected.transform

func set_selected_position(pos: Vector3) -> void:
	if selected == null:
		return
	selected.position = snap_position(pos)
	dirty = true
	table_changed.emit()

## Live drag setter — caller has already applied per-axis snapping.
func set_selected_position_raw(pos: Vector3) -> void:
	if selected == null:
		return
	selected.position = pos
	dirty = true
	table_changed.emit()

func set_selected_yaw(yaw: float) -> void:
	if selected == null:
		return
	selected.rotation.y = snap_yaw(yaw)
	dirty = true
	table_changed.emit()

func gesture_commit() -> void:
	if _gesture_node != null and _gesture_node == selected and selected.transform != _gesture_before:
		_record({"kind": "transform", "id": selected.name, "before": _gesture_before, "after": selected.transform})
	_gesture_node = null

## Discrete keyboard nudges (each records its own undo step).
func nudge_translate(delta: Vector3) -> void:
	if selected == null:
		return
	var before := selected.transform
	# delta is already grid-sized; do not re-snap (would drift the untouched axes).
	selected.position += delta
	_record({"kind": "transform", "id": selected.name, "before": before, "after": selected.transform})

func nudge_yaw(delta: float) -> void:
	if selected == null:
		return
	var before := selected.transform
	selected.rotation.y = snap_yaw(selected.rotation.y + delta)
	_record({"kind": "transform", "id": selected.name, "before": before, "after": selected.transform})

func nudge_scale(factor: float) -> void:
	if selected == null:
		return
	var before := selected.transform
	selected.scale = (selected.scale * factor).clamp(Vector3(0.1, 0.1, 0.1), Vector3(20, 20, 20))
	_record({"kind": "transform", "id": selected.name, "before": before, "after": selected.transform})

func set_selected_scale(uniform: float) -> void:
	if selected == null:
		return
	var before := selected.transform
	uniform = clampf(uniform, 0.1, 20.0)
	selected.scale = Vector3(uniform, uniform, uniform)
	_record({"kind": "transform", "id": selected.name, "before": before, "after": selected.transform})

# ------------------------------------------------------------------------
# Add / delete / duplicate
# ------------------------------------------------------------------------
func add_component(type: String, pos: Vector3) -> Node3D:
	if not TableRegistry.is_known(type):
		return null
	var entry := {
		"type": type,
		"id": _unique_id(type),
		"position": [pos.x, pos.y, pos.z],
		"rotation_deg": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"properties": TableRegistry.default_properties(type),
	}
	var node := TableLoader.spawn(entry, table)
	if node == null:
		return null
	_ensure_pick_proxy(node)
	_record({"kind": "add", "entry": TableLoader.entry_for(node)})
	select(node)
	status.emit("Added " + TableRegistry.display_name(type))
	return node

func delete_selected() -> void:
	if selected == null:
		return
	var entry := TableLoader.entry_for(selected)
	var node := selected
	clear_selection()
	table.remove_child(node)
	node.queue_free()
	_record({"kind": "delete", "entry": entry})
	status.emit("Deleted " + str(entry.get("id", "")))

func duplicate_selected() -> Node3D:
	if selected == null:
		return null
	var entry := TableLoader.entry_for(selected)
	entry["id"] = _unique_id(str(entry.get("type", "component")))
	var pos: Array = entry.get("position", [0, 0, 0])
	entry["position"] = [pos[0] + 1.5, pos[1], pos[2] + 1.5]
	var node := TableLoader.spawn(entry, table)
	if node == null:
		return null
	_ensure_pick_proxy(node)
	_record({"kind": "add", "entry": TableLoader.entry_for(node)})
	select(node)
	status.emit("Duplicated -> " + node.name)
	return node

# ------------------------------------------------------------------------
# Inspector properties
# ------------------------------------------------------------------------
func set_transform_field(axis_kind: String, value: float) -> void:
	if selected == null:
		return
	var before := selected.transform
	match axis_kind:
		"px": selected.position.x = snap_scalar(value, position_snap)
		"py": selected.position.y = snap_scalar(value, position_snap)
		"pz": selected.position.z = snap_scalar(value, position_snap)
		"ry": selected.rotation.y = snap_yaw(deg_to_rad(value))
		"scale": selected.scale = Vector3(clampf(value, 0.1, 20.0), clampf(value, 0.1, 20.0), clampf(value, 0.1, 20.0))
	_record({"kind": "transform", "id": selected.name, "before": before, "after": selected.transform})

func set_property(node: Node3D, key: String, value: Variant) -> void:
	if node == null:
		return
	var type := TableRegistry.type_of(node)
	var clamped: Variant = TableRegistry.clamp_property(type, key, value)
	var before: Variant = node.get(key)
	if before == clamped:
		return
	node.set(key, clamped)
	_record({"kind": "property", "id": node.name, "key": key, "before": before, "after": clamped})
	table_changed.emit()

# ------------------------------------------------------------------------
# Undo / redo
# ------------------------------------------------------------------------
func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func undo() -> void:
	if _undo.is_empty():
		return
	var cmd: Dictionary = _undo.pop_back()
	_apply(cmd, true)
	_redo.push_back(cmd)
	dirty = true
	history_changed.emit()
	table_changed.emit()

func redo() -> void:
	if _redo.is_empty():
		return
	var cmd: Dictionary = _redo.pop_back()
	_apply(cmd, false)
	_undo.push_back(cmd)
	dirty = true
	history_changed.emit()
	table_changed.emit()

func _record(cmd: Dictionary) -> void:
	_undo.push_back(cmd)
	if _undo.size() > HISTORY_MAX:
		_undo.pop_front()
	_redo.clear()
	dirty = true
	history_changed.emit()
	table_changed.emit()

func _apply(cmd: Dictionary, inverse: bool) -> void:
	match str(cmd.get("kind", "")):
		"transform":
			var node := _resolve(cmd["id"])
			if node != null:
				node.transform = cmd["before"] if inverse else cmd["after"]
		"property":
			var node := _resolve(cmd["id"])
			if node != null:
				node.set(cmd["key"], cmd["before"] if inverse else cmd["after"])
		"add":
			if inverse:
				_remove_by_id(str(cmd["entry"]["id"]))
			else:
				_ensure_pick_proxy(TableLoader.spawn(cmd["entry"], table))
		"delete":
			if inverse:
				_ensure_pick_proxy(TableLoader.spawn(cmd["entry"], table))
			else:
				_remove_by_id(str(cmd["entry"]["id"]))
	# Selection may have been invalidated by structural changes.
	if selected != null and not is_instance_valid(selected):
		clear_selection()
	elif selected != null and selected.get_parent() != table:
		clear_selection()

func _resolve(id: String) -> Node3D:
	return table.get_node_or_null(NodePath(id)) as Node3D

func _remove_by_id(id: String) -> void:
	var node := _resolve(id)
	if node != null:
		if node == selected:
			clear_selection()
		table.remove_child(node)
		node.queue_free()

# ------------------------------------------------------------------------
# File workflow
# ------------------------------------------------------------------------
func new_table() -> void:
	var def := TableDefinition.new()
	def.id = "untitled"
	def.name = "Untitled Table"
	def.settings = {"tuning": "res://data/pinball/table_tuning.tres"}
	# Minimal playable base: a floor and a ball spawn.
	def.components = [
		{"type": "wall", "id": "Floor", "position": [0, -0.5, 0], "rotation_deg": [0, 0, 0], "scale": [1, 1, 1],
			"properties": {"size": [14, 1, 30], "wall_color": [0.16, 0.18, 0.22, 1], "friction": 0.4, "bounce": 0.1}},
		{"type": "ball_spawn", "id": "BallSpawn", "position": [0, 0.4, 12], "rotation_deg": [0, 0, 0], "scale": [1, 1, 1], "properties": {}},
	]
	_load_definition(def, "", true)
	status.emit("New table")

func load(path: String) -> bool:
	var def := TableDefinition.load_from(path)
	if def == null:
		status.emit("LOAD FAILED: " + path)
		return false
	_load_definition(def, path, false)
	status.emit("Loaded " + def.name)
	return true

func _load_definition(def: TableDefinition, path: String, mark_dirty: bool) -> void:
	clear_selection()
	var result := TableLoader.build(def, table)
	_ensure_pick_proxies()
	current_id = def.id
	current_name = def.name
	current_path = path
	_undo.clear()
	_redo.clear()
	dirty = mark_dirty
	if spike != null and spike.has_method("on_table_rebuilt"):
		spike.on_table_rebuilt()
	history_changed.emit()
	table_changed.emit()
	if not (result["errors"] as Array).is_empty():
		status.emit("Loaded with %d errors" % (result["errors"] as Array).size())

func save(path: String = "") -> bool:
	var target := path if path != "" else current_path
	if target == "":
		target = _default_save_path(current_id)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var def := TableLoader.serialize(table, current_id, current_name, {"tuning": "res://data/pinball/table_tuning.tres"})
	var err := def.save_to(target)
	if err != OK:
		status.emit("SAVE FAILED (%d)" % err)
		return false
	current_path = target
	dirty = false
	table_changed.emit()
	status.emit("Saved -> " + ProjectSettings.globalize_path(target))
	return true

func save_as(id: String, table_name: String) -> bool:
	current_id = _sanitize_id(id)
	current_name = table_name
	return save(_default_save_path(current_id))

func duplicate_table(new_id: String, new_name: String) -> bool:
	current_id = _sanitize_id(new_id)
	current_name = new_name
	current_path = ""
	dirty = true
	return save()

## List saved tables from the source and user table dirs.
func list_saved_tables() -> Array:
	var out: Array = []
	for dir: String in [SOURCE_DIR, USER_DIR]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if f.get_extension() == "json":
				var p: String = dir.path_join(f)
				var def := TableDefinition.load_from(p)
				out.append({"path": p, "id": def.id if def != null else f, "name": def.name if def != null else f})
	return out

func _default_save_path(id: String) -> String:
	var base := SOURCE_DIR if _res_tables_writable() else USER_DIR
	return base.path_join(_sanitize_id(id) + ".json")

func _res_tables_writable() -> bool:
	DirAccess.make_dir_recursive_absolute(SOURCE_DIR)
	var probe := SOURCE_DIR.path_join(".write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true

func _sanitize_id(id: String) -> String:
	var s := id.strip_edges().to_lower()
	var out := ""
	for c in s:
		out += c if ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_") else "_"
	return out if out != "" else "untitled"

# ------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------
func _unique_id(type: String) -> String:
	var base := type.capitalize().replace(" ", "")
	var i := 1
	while table.has_node(NodePath("%s%02d" % [base, i])):
		i += 1
	return "%s%02d" % [base, i]

func _ensure_pick_proxies() -> void:
	if table == null:
		return
	for child in table.get_children():
		if child is Marker3D:
			_ensure_pick_proxy(child)

## Markers have no collider; give them a pick-only proxy so they can be clicked.
func _ensure_pick_proxy(node: Node3D) -> void:
	if node == null or not (node is Marker3D):
		return
	if node.has_node("PickProxy"):
		return
	var body := StaticBody3D.new()
	body.name = "PickProxy"
	body.collision_layer = PICK_LAYER_PROXY
	body.collision_mask = 0
	body.set_meta("greybox_generated", true)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.9, 0.9)
	col.shape = box
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.5, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	node.add_child(body)
