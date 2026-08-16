extends CanvasLayer

## Developer Table Editor v1 — view / shell (dev-only).
##
## Renders the editor UI (top toolbar, left Asset Library, right Inspector) and
## handles viewport interaction (mouse pick/hover/drag, transform gizmo, drag-to-
## place ghost). All state/ops go through the TableEditor controller. Hidden in
## Play mode. Keyboard fallbacks retained. No production art.

var editor: TableEditor

# --- palette ---
const BG := Color(0.10, 0.11, 0.13, 0.97)
const BG2 := Color(0.14, 0.15, 0.18, 1.0)
const FG := Color(0.86, 0.89, 0.93)
const ACCENT := Color(0.30, 0.66, 0.92)
const EDIT_COL := Color(0.45, 0.85, 0.45)
const HILITE := Color(1.0, 0.85, 0.1)
const HOVER := Color(0.35, 0.85, 1.0)

const POS_SNAPS := [0.0, 0.25, 0.5, 1.0]
const ROT_SNAPS := [0.0, 5.0, 15.0, 30.0]

var _toolbar: PanelContainer
var _left: PanelContainer
var _right: PanelContainer
var _inspector_box: VBoxContainer
var _asset_list: VBoxContainer
var _search: LineEdit
var _category: OptionButton
var _mode_label: Label
var _dirty_label: Label
var _undo_btn: Button
var _redo_btn: Button
var _status_label: Label

# 3D helpers (added to the spike root)
var _gizmo_root: Node3D
var _ghost: Node3D
var _hover_node: Node3D
var _hilite_saved := {}   # mesh -> orig material_override

# interaction state
var _dragging := false
var _drag_axis := ""      # "", "xz", "x", "z", "y", "ry"
var _placing_type := ""
var _suppress_inspector_sync := false

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_3d_helpers()
	if editor != null:
		editor.selection_changed.connect(_on_selection_changed)
		editor.mode_changed.connect(_on_mode_changed)
		editor.history_changed.connect(_on_history_changed)
		editor.table_changed.connect(_on_table_changed)
		editor.status.connect(_on_status)
	_set_ui_visible(false)

# ========================================================================
# UI construction
# ========================================================================
func _sb(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.border_color = Color(0, 0, 0, 0.4)
	return s

func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(color))
	return p

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", FG)
	return b

func _build_ui() -> void:
	# Top toolbar
	_toolbar = _panel(BG)
	_toolbar.anchor_right = 1.0
	_toolbar.offset_bottom = 40
	add_child(_toolbar)
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 6)
	_toolbar.add_child(tb)

	_mode_label = Label.new()
	_mode_label.custom_minimum_size = Vector2(120, 0)
	tb.add_child(_mode_label)

	var play_btn := _button("▶ Play Test")
	play_btn.pressed.connect(func() -> void: editor.set_editing(false))
	tb.add_child(play_btn)
	tb.add_child(_sep())
	_add_tool(tb, "New", func() -> void: editor.new_table())
	_add_tool(tb, "Save", func() -> void: editor.save())
	_add_tool(tb, "Save As", _open_save_as)
	_add_tool(tb, "Load", _open_load)
	tb.add_child(_sep())
	_undo_btn = _add_tool(tb, "Undo", func() -> void: editor.undo())
	_redo_btn = _add_tool(tb, "Redo", func() -> void: editor.redo())
	tb.add_child(_sep())
	tb.add_child(_mklabel("Pos"))
	_category = null
	var pos_opt := OptionButton.new()
	pos_opt.focus_mode = Control.FOCUS_NONE
	for v in POS_SNAPS:
		pos_opt.add_item("Off" if v == 0.0 else str(v))
	pos_opt.selected = 2
	pos_opt.item_selected.connect(func(i: int) -> void: editor.position_snap = POS_SNAPS[i])
	tb.add_child(pos_opt)
	tb.add_child(_mklabel("Rot"))
	var rot_opt := OptionButton.new()
	rot_opt.focus_mode = Control.FOCUS_NONE
	for v in ROT_SNAPS:
		rot_opt.add_item("Off" if v == 0.0 else "%d°" % int(v))
	rot_opt.selected = 2
	rot_opt.item_selected.connect(func(i: int) -> void: editor.rotation_snap_deg = ROT_SNAPS[i])
	tb.add_child(rot_opt)
	tb.add_child(_sep())
	_add_tool(tb, "Reset Ball", func() -> void: if editor.spike: editor.spike.reset_ball())
	_dirty_label = Label.new()
	_dirty_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	tb.add_child(_dirty_label)

	# Left: Asset Library
	_left = _panel(BG)
	_left.anchor_top = 0.0
	_left.anchor_bottom = 1.0
	_left.offset_top = 44
	_left.offset_left = 0
	_left.custom_minimum_size = Vector2(210, 0)
	add_child(_left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	_left.add_child(lv)
	lv.add_child(_mktitle("ASSET LIBRARY"))
	_search = LineEdit.new()
	_search.placeholder_text = "Search…"
	_search.text_changed.connect(func(_t: String) -> void: _rebuild_asset_list())
	lv.add_child(_search)
	_category = OptionButton.new()
	_category.focus_mode = Control.FOCUS_NONE
	_category.add_item("All")
	for c in TableRegistry.CATEGORIES:
		_category.add_item(c)
	_category.item_selected.connect(func(_i: int) -> void: _rebuild_asset_list())
	lv.add_child(_category)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(scroll)
	_asset_list = VBoxContainer.new()
	_asset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_asset_list)
	_rebuild_asset_list()

	# Right: Inspector
	_right = _panel(BG)
	_right.anchor_left = 1.0
	_right.anchor_right = 1.0
	_right.anchor_bottom = 1.0
	_right.offset_left = -260
	_right.offset_top = 44
	add_child(_right)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(rscroll)
	_inspector_box = VBoxContainer.new()
	_inspector_box.custom_minimum_size = Vector2(240, 0)
	_inspector_box.add_theme_constant_override("separation", 4)
	rscroll.add_child(_inspector_box)

	# Status line (bottom-left)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	_status_label.position = Vector2(220, 8)
	_status_label.anchor_top = 1.0
	_status_label.anchor_bottom = 1.0
	_status_label.offset_top = -26
	add_child(_status_label)

	_refresh_inspector(null)
	_update_mode_label(false)

func _sep() -> Control:
	var c := VSeparator.new()
	return c

func _mklabel(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
	return l

func _mktitle(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", ACCENT)
	return l

func _add_tool(parent: Node, text: String, cb: Callable) -> Button:
	var b := _button(text)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ========================================================================
# Asset library
# ========================================================================
func _rebuild_asset_list() -> void:
	for c in _asset_list.get_children():
		c.queue_free()
	var filter := _search.text.to_lower() if _search != null else ""
	var cat := "All"
	if _category != null and _category.selected > 0:
		cat = TableRegistry.CATEGORIES[_category.selected - 1]
	for type in TableRegistry.palette():
		if cat != "All" and TableRegistry.category(type) != cat:
			continue
		var name := TableRegistry.display_name(type)
		if filter != "" and not (name.to_lower().contains(filter) or type.contains(filter)):
			continue
		_asset_list.add_child(_make_asset_button(type, name))

func _make_asset_button(type: String, disp: String) -> Button:
	var b := Button.new()
	b.text = "%s  %s" % [TableRegistry.icon(type), disp]
	b.tooltip_text = TableRegistry.description(type)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", FG)
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_begin_placement(type))
	return b

# ========================================================================
# Mode / signals
# ========================================================================
func _on_mode_changed(editing: bool) -> void:
	_set_ui_visible(editing)
	_update_mode_label(editing)
	if not editing:
		_cancel_placement()
		_clear_hover()

func _update_mode_label(editing: bool) -> void:
	if _mode_label == null:
		return
	_mode_label.text = "● EDIT MODE" if editing else "▶ PLAY TEST"
	_mode_label.add_theme_color_override("font_color", EDIT_COL if editing else Color(0.95, 0.6, 0.3))

func _set_ui_visible(v: bool) -> void:
	for p in [_toolbar, _left, _right, _status_label]:
		if p != null:
			p.visible = v
	if _gizmo_root != null:
		_gizmo_root.visible = v and editor.selected != null

func _on_selection_changed(node: Node3D) -> void:
	_apply_selection_highlight(node)
	_refresh_inspector(node)
	_update_gizmo()

func _on_history_changed() -> void:
	if _undo_btn != null:
		_undo_btn.disabled = not editor.can_undo()
	if _redo_btn != null:
		_redo_btn.disabled = not editor.can_redo()

func _on_table_changed() -> void:
	if _dirty_label != null:
		_dirty_label.text = "● unsaved" if editor.dirty else ""
	if not _suppress_inspector_sync:
		_sync_inspector_values()

func _on_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg

# ========================================================================
# 3D helpers: gizmo + ghost + highlight
# ========================================================================
var _sel_saved := {}
var _hover_saved := {}
var _fields := {}

func _build_3d_helpers() -> void:
	var root3d: Node3D = editor.spike
	_gizmo_root = Node3D.new()
	_gizmo_root.name = "EditorGizmo"
	root3d.add_child(_gizmo_root)
	_gizmo_root.visible = false
	_build_gizmo()

func _handle(size: Vector3, pos: Vector3, color: Color, axis: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = TableEditor.PICK_LAYER_GIZMO
	body.collision_mask = 0
	body.position = pos
	body.set_meta("gizmo_axis", axis)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	_gizmo_root.add_child(body)

func _build_gizmo() -> void:
	_handle(Vector3(2.2, 0.25, 0.25), Vector3(1.3, 0, 0), Color(0.95, 0.3, 0.3), "x")
	_handle(Vector3(0.25, 0.25, 2.2), Vector3(0, 0, 1.3), Color(0.35, 0.5, 0.95), "z")
	_handle(Vector3(0.25, 2.2, 0.25), Vector3(0, 1.3, 0), Color(0.4, 0.9, 0.4), "y")
	_handle(Vector3(0.6, 0.6, 0.6), Vector3(1.4, 0.0, 1.4), Color(0.95, 0.85, 0.2), "ry")

func _update_gizmo() -> void:
	if _gizmo_root == null:
		return
	var sel := editor.selected
	_gizmo_root.visible = editor.is_active() and sel != null
	if sel != null:
		_gizmo_root.global_position = sel.global_position

# --- highlight ---
func _find_meshes(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_find_meshes(c))
	return out

func _override(node: Node3D, color: Color) -> Dictionary:
	var saved := {}
	if node == null:
		return saved
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in _find_meshes(node):
		saved[m] = m.material_override
		m.material_override = mat
	return saved

func _restore(saved: Dictionary) -> void:
	for m in saved:
		if is_instance_valid(m):
			m.material_override = saved[m]

func _apply_selection_highlight(node: Node3D) -> void:
	_restore(_sel_saved)
	_sel_saved = _override(node, HILITE)

func _set_hover(node: Node3D) -> void:
	if node == _hover_node:
		return
	_restore(_hover_saved)
	_hover_saved = {}
	_hover_node = node
	if node != null and node != editor.selected:
		_hover_saved = _override(node, HOVER)

func _clear_hover() -> void:
	_restore(_hover_saved)
	_hover_saved = {}
	_hover_node = null

# ========================================================================
# Inspector
# ========================================================================
func _refresh_inspector(node: Node3D) -> void:
	_fields.clear()
	for c in _inspector_box.get_children():
		c.queue_free()
	_inspector_box.add_child(_mktitle("INSPECTOR"))
	if node == null:
		var l := Label.new()
		l.text = "No selection.\nClick a component in the\nviewport, or drag one from\nthe Asset Library."
		l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
		_inspector_box.add_child(l)
		return
	var type := TableRegistry.type_of(node)
	_inspector_box.add_child(_kv("ID", node.name))
	_inspector_box.add_child(_kv("Type", TableRegistry.display_name(type)))
	_inspector_box.add_child(HSeparator.new())
	_inspector_box.add_child(_mklabel("Transform"))
	_inspector_box.add_child(_num_field("px", "Pos X", node.position.x, -50, 50, 0.1, func(v): editor.set_transform_field("px", v)))
	_inspector_box.add_child(_num_field("py", "Pos Y", node.position.y, -20, 20, 0.1, func(v): editor.set_transform_field("py", v)))
	_inspector_box.add_child(_num_field("pz", "Pos Z", node.position.z, -50, 50, 0.1, func(v): editor.set_transform_field("pz", v)))
	_inspector_box.add_child(_num_field("ry", "Yaw °", rad_to_deg(node.rotation.y), -360, 360, 1.0, func(v): editor.set_transform_field("ry", v)))
	_inspector_box.add_child(_num_field("scale", "Scale", node.scale.x, 0.1, 20, 0.1, func(v): editor.set_transform_field("scale", v)))
	var props := TableRegistry.editable_properties(type)
	if not props.is_empty():
		_inspector_box.add_child(HSeparator.new())
		_inspector_box.add_child(_mklabel("Properties"))
		for p in props:
			_build_prop_field(node, type, p)

func _kv(k: String, v: String) -> Control:
	var h := HBoxContainer.new()
	var lk := Label.new(); lk.text = k + ":"; lk.custom_minimum_size = Vector2(70, 0)
	lk.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
	var lv := Label.new(); lv.text = v; lv.add_theme_color_override("font_color", FG)
	h.add_child(lk); h.add_child(lv)
	return h

func _num_field(tag: String, label: String, value: float, lo: float, hi: float, step: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_color_override("font_color", Color(0.66, 0.7, 0.75))
	h.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo; sb.max_value = hi; sb.step = step; sb.value = value
	sb.custom_minimum_size = Vector2(140, 0)
	sb.value_changed.connect(func(v: float) -> void:
		if _suppress_inspector_sync: return
		cb.call(v))
	h.add_child(sb)
	_fields[tag] = sb
	return h

func _build_prop_field(node: Node3D, type: String, p: Dictionary) -> void:
	var key := str(p["name"])
	match str(p["type"]):
		"float", "int":
			var v := float(node.get(key))
			_inspector_box.add_child(_num_field("p_" + key, str(p["label"]), v, float(p["min"]), float(p["max"]), float(p.get("step", 1.0)),
				func(val): editor.set_property(node, key, val if str(p["type"]) == "float" else int(val))))
		"enum":
			var h := HBoxContainer.new()
			var l := Label.new(); l.text = str(p["label"]); l.custom_minimum_size = Vector2(70, 0)
			l.add_theme_color_override("font_color", Color(0.66, 0.7, 0.75))
			h.add_child(l)
			var opt := OptionButton.new(); opt.focus_mode = Control.FOCUS_NONE
			var cur = node.get(key)
			var sel_idx := 0
			for i in (p["options"] as Array).size():
				var o = p["options"][i]
				opt.add_item(str(o["label"]))
				opt.set_item_metadata(i, o["value"])
				if str(o["value"]) == str(cur):
					sel_idx = i
			opt.selected = sel_idx
			opt.item_selected.connect(func(i: int) -> void: editor.set_property(node, key, opt.get_item_metadata(i)))
			h.add_child(opt)
			_inspector_box.add_child(h)
		"vector3":
			var vec: Vector3 = node.get(key)
			_inspector_box.add_child(_mklabel("  " + str(p["label"])))
			for comp in [["x", vec.x], ["y", vec.y], ["z", vec.z]]:
				var axis := str(comp[0])
				_inspector_box.add_child(_num_field("p_%s_%s" % [key, axis], "  " + axis, float(comp[1]), float(p["min"]), float(p["max"]), float(p.get("step", 0.1)),
					func(val): _set_vec_component(node, key, axis, val)))
		"color":
			var col: Color = node.get(key)
			_inspector_box.add_child(_mklabel("  " + str(p["label"]) + " (rgb)"))
			for comp in [["r", col.r], ["g", col.g], ["b", col.b]]:
				var ch := str(comp[0])
				_inspector_box.add_child(_num_field("p_%s_%s" % [key, ch], "  " + ch, float(comp[1]), 0.0, 1.0, 0.05,
					func(val): _set_color_component(node, key, ch, val)))

func _set_vec_component(node: Node3D, key: String, axis: String, val: float) -> void:
	var v: Vector3 = node.get(key)
	match axis:
		"x": v.x = val
		"y": v.y = val
		"z": v.z = val
	editor.set_property(node, key, v)

func _set_color_component(node: Node3D, key: String, ch: String, val: float) -> void:
	var c: Color = node.get(key)
	match ch:
		"r": c.r = val
		"g": c.g = val
		"b": c.b = val
	editor.set_property(node, key, c)

func _sync_inspector_values() -> void:
	var node := editor.selected
	if node == null or not is_instance_valid(node):
		return
	_suppress_inspector_sync = true
	_set_field("px", node.position.x)
	_set_field("py", node.position.y)
	_set_field("pz", node.position.z)
	_set_field("ry", rad_to_deg(node.rotation.y))
	_set_field("scale", node.scale.x)
	_suppress_inspector_sync = false

func _set_field(tag: String, value: float) -> void:
	if _fields.has(tag) and is_instance_valid(_fields[tag]):
		(_fields[tag] as SpinBox).set_value_no_signal(value)

# ========================================================================
# Placement (drag from library -> ghost -> place)
# ========================================================================
func _begin_placement(type: String) -> void:
	_cancel_placement()
	_placing_type = type
	_ghost = TableRegistry.instantiate(type)
	if _ghost == null:
		_placing_type = ""
		return
	editor.spike.add_child(_ghost)
	_disable_collisions(_ghost)
	_tint(_ghost, Color(0.3, 0.9, 0.5, 0.55))
	_on_status("Placing %s — click the table (Esc cancels)" % TableRegistry.display_name(type))

func _cancel_placement() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_placing_type = ""

func _disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for c in node.get_children():
		_disable_collisions(c)

func _tint(node: Node, color: Color) -> void:
	for m in _find_meshes(node):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat

func _ground_hit(mouse: Vector2, y: float) -> Variant:
	var cam := editor.camera
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	return Plane(Vector3.UP, y).intersects_ray(from, dir)

func _update_ghost(mouse: Vector2) -> void:
	if _ghost == null:
		return
	var hit = _ground_hit(mouse, 0.5)
	if hit != null:
		var p: Vector3 = hit
		p.x = editor.snap_scalar(p.x, editor.position_snap)
		p.z = editor.snap_scalar(p.z, editor.position_snap)
		p.y = 0.5
		_ghost.position = p

func _place(mouse: Vector2) -> void:
	var hit = _ground_hit(mouse, 0.5)
	var type := _placing_type
	_cancel_placement()
	if hit == null:
		return
	var p: Vector3 = hit
	p.x = editor.snap_scalar(p.x, editor.position_snap)
	p.z = editor.snap_scalar(p.z, editor.position_snap)
	p.y = 0.5
	editor.add_component(type, p)

# ========================================================================
# Input
# ========================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			editor.toggle_mode()
			get_viewport().set_input_as_handled()
			return
		if editor.is_active() and event.ctrl_pressed:
			if event.keycode == KEY_Z and not event.shift_pressed:
				editor.undo(); get_viewport().set_input_as_handled()
			elif (event.keycode == KEY_Y) or (event.keycode == KEY_Z and event.shift_pressed):
				editor.redo(); get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not editor.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_editor_key(event)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _placing_type != "":
			_update_ghost(mm.position)
		elif _dragging:
			_update_drag(mm.position)
		else:
			_set_hover(editor.pick_component(mm.position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb.position)
			else:
				_on_release()

func _editor_key(event: InputEventKey) -> void:
	var step := editor.position_snap if editor.position_snap > 0.0 else 0.5
	var coarse := 5.0 if event.shift_pressed else 1.0
	match event.keycode:
		KEY_ESCAPE:
			if _placing_type != "": _cancel_placement()
			else: editor.clear_selection()
		KEY_DELETE: editor.delete_selected()
		KEY_INSERT: editor.duplicate_selected()
		KEY_TAB: _cycle_selection(-1 if event.shift_pressed else 1)
		KEY_LEFT: editor.nudge_translate(Vector3(-step * coarse, 0, 0))
		KEY_RIGHT: editor.nudge_translate(Vector3(step * coarse, 0, 0))
		KEY_UP: editor.nudge_translate(Vector3(0, 0, -step * coarse))
		KEY_DOWN: editor.nudge_translate(Vector3(0, 0, step * coarse))
		KEY_PAGEUP: editor.nudge_translate(Vector3(0, step * coarse, 0))
		KEY_PAGEDOWN: editor.nudge_translate(Vector3(0, -step * coarse, 0))
		KEY_COMMA: editor.nudge_yaw(-deg_to_rad(15.0 if event.shift_pressed else 5.0))
		KEY_PERIOD: editor.nudge_yaw(deg_to_rad(15.0 if event.shift_pressed else 5.0))
		KEY_MINUS: editor.nudge_scale(0.9)
		KEY_EQUAL: editor.nudge_scale(1.0 / 0.9)

func _on_press(mouse: Vector2) -> void:
	if _placing_type != "":
		_place(mouse)
		return
	# gizmo handle?
	var gh := editor.raycast(mouse, TableEditor.PICK_LAYER_GIZMO)
	if not gh.is_empty() and editor.selected != null:
		var collider = gh.get("collider")
		if collider != null and collider.has_meta("gizmo_axis"):
			_drag_axis = str(collider.get_meta("gizmo_axis"))
			_dragging = true
			editor.gesture_begin()
			return
	# component?
	var comp := editor.pick_component(mouse)
	if comp != null:
		if comp != editor.selected:
			editor.select(comp)
		_drag_axis = "xz"
		_dragging = true
		editor.gesture_begin()
	else:
		editor.clear_selection()

func _on_release() -> void:
	if _dragging:
		editor.gesture_commit()
	_dragging = false
	_drag_axis = ""

func _update_drag(mouse: Vector2) -> void:
	var obj := editor.selected
	if obj == null:
		return
	var cam := editor.camera
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	match _drag_axis:
		"xz", "x", "z":
			var hit = Plane(Vector3.UP, obj.global_position.y).intersects_ray(from, dir)
			if hit != null:
				var p: Vector3 = obj.position
				if _drag_axis != "z":
					p.x = editor.snap_scalar((hit as Vector3).x, editor.position_snap)
				if _drag_axis != "x":
					p.z = editor.snap_scalar((hit as Vector3).z, editor.position_snap)
				editor.set_selected_position_raw(p)
		"y":
			var n := cam.global_transform.basis.z
			n.y = 0.0
			if n.length() < 0.01:
				n = Vector3.FORWARD
			n = n.normalized()
			var hit2 = Plane(n, n.dot(obj.global_position)).intersects_ray(from, dir)
			if hit2 != null:
				var p2: Vector3 = obj.position
				p2.y = editor.snap_scalar((hit2 as Vector3).y, editor.position_snap)
				editor.set_selected_position_raw(p2)
		"ry":
			var hit3 = Plane(Vector3.UP, obj.global_position.y).intersects_ray(from, dir)
			if hit3 != null:
				var d: Vector3 = (hit3 as Vector3) - obj.global_position
				editor.set_selected_yaw(atan2(d.x, d.z))

func _cycle_selection(dir: int) -> void:
	var editable: Array = []
	for c in editor.table.get_children():
		if TableRegistry.type_of(c) != "":
			editable.append(c)
	if editable.is_empty():
		return
	var idx := editable.find(editor.selected)
	editor.select(editable[wrapi(idx + dir, 0, editable.size())])

# ========================================================================
# Save As / Load popups
# ========================================================================
func _open_save_as() -> void:
	var pop := AcceptDialog.new()
	pop.title = "Save Table As"
	pop.dialog_hide_on_ok = true
	var vb := VBoxContainer.new()
	var id_edit := LineEdit.new(); id_edit.placeholder_text = "table id"; id_edit.text = editor.current_id
	var name_edit := LineEdit.new(); name_edit.placeholder_text = "display name"; name_edit.text = editor.current_name
	vb.add_child(_mklabel("ID (filename)")); vb.add_child(id_edit)
	vb.add_child(_mklabel("Display name")); vb.add_child(name_edit)
	pop.add_child(vb)
	add_child(pop)
	pop.confirmed.connect(func() -> void:
		editor.save_as(id_edit.text, name_edit.text)
		pop.queue_free())
	pop.canceled.connect(func() -> void: pop.queue_free())
	pop.popup_centered(Vector2i(320, 160))

func _open_load() -> void:
	var pop := AcceptDialog.new()
	pop.title = "Load Table"
	pop.ok_button_text = "Load"
	var vb := VBoxContainer.new()
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(360, 220)
	var tables := editor.list_saved_tables()
	for t in tables:
		list.add_item("%s   (%s)" % [t["name"], t["path"]])
	vb.add_child(list)
	pop.add_child(vb)
	add_child(pop)
	pop.confirmed.connect(func() -> void:
		var sel := list.get_selected_items()
		if not sel.is_empty():
			editor.load(tables[sel[0]]["path"])
		pop.queue_free())
	pop.canceled.connect(func() -> void: pop.queue_free())
	pop.popup_centered(Vector2i(420, 300))

func _process(_delta: float) -> void:
	if editor != null and editor.is_active():
		_update_gizmo()
