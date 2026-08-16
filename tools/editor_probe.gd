extends Node

## Headless smoke test for Developer Table Editor v1 (controller layer).
## Drives the TableEditor API and checks selection-by-raycast, move/rotate/snap,
## add/delete/duplicate, undo/redo, inspector apply+serialize, save->load
## round-trip, Play<->Edit preservation, flipper-operational-after-move, and that
## only safe data is serialized. Run: godot --headless --path <project> -- editortest

var _spike: Node
var _editor: TableEditor
var _frames := 0
var _r := {}
var _flipper: Node3D
var _flipper_moved_pos := Vector3.ZERO
var _flipper_rest_y := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 600:
		push_error("[editortest] timeout"); get_tree().quit(); return
	if _editor == null:
		_spike = get_parent()
		if _spike.has_method("get_editor"):
			_editor = _spike.get_editor()
		return

	match _frames:
		4:
			_editor.set_editing(true)
		6:
			_run_logic_tests()
			_setup_flipper_test()
		10:
			Input.action_press("flipper_left")
		34:
			_r["flipper_operates"] = absf(_flipper.rotation.y - _flipper_rest_y) > 0.25
			_r["flipper_pos_preserved"] = _flipper.position.distance_to(_flipper_moved_pos) < 0.01
			Input.action_release("flipper_left")
			_report()
			get_tree().quit()

func _run_logic_tests() -> void:
	var table: Node3D = _editor.table
	var cam: Camera3D = _editor.camera

	# 1. Raycast selection resolves the correct component.
	var bumper: Node3D = table.get_node_or_null("Bumper01")
	var screen := cam.unproject_position(bumper.global_position)
	var picked := _editor.pick_component(screen)
	_r["pick_resolves"] = picked == bumper

	# 2/3. Move + rotate change transform.
	_editor.select(bumper)
	var p0 := bumper.position
	_editor.nudge_translate(Vector3(1, 0, 0))
	_r["move_changes"] = not bumper.position.is_equal_approx(p0)
	var y0 := bumper.rotation.y
	_editor.nudge_yaw(deg_to_rad(30))
	_r["rotate_changes"] = absf(bumper.rotation.y - y0) > 0.01

	# 4. Snap rounds to expected values.
	_editor.position_snap = 0.5
	_editor.rotation_snap_deg = 15.0
	_editor.set_transform_field("px", 1.23)
	_r["pos_snap"] = is_equal_approx(bumper.position.x, 1.0)
	_editor.set_transform_field("ry", 12.0)
	_r["rot_snap"] = is_equal_approx(rad_to_deg(bumper.rotation.y), 15.0)

	# 5. Add asset creates the correct component.
	var n0 := table.get_child_count()
	var added := _editor.add_component("bumper", Vector3(0, 0.8, 0))
	_r["add_creates"] = added != null and TableRegistry.type_of(added) == "bumper" and table.get_child_count() == n0 + 1

	# 6. Duplicate + delete.
	var n1 := table.get_child_count()
	_editor.duplicate_selected()
	_r["duplicate"] = table.get_child_count() == n1 + 1
	_editor.delete_selected()
	_r["delete"] = table.get_child_count() == n1

	# 7. Undo/redo restore state (transform).
	_editor.select(bumper)
	var pu := bumper.position
	_editor.nudge_translate(Vector3(2, 0, 0))
	_editor.undo()
	_r["undo_restores"] = bumper.position.is_equal_approx(pu)
	_editor.redo()
	_r["redo_restores"] = is_equal_approx(bumper.position.x, pu.x + 2.0)
	_editor.undo()  # leave it back

	# 8. Inspector property applies + serializes.
	_editor.set_property(bumper, "radius", 1.6)
	_r["property_applies"] = is_equal_approx(bumper.radius, 1.6)
	var entry := TableLoader.entry_for(bumper)
	_r["property_serializes"] = is_equal_approx(float(entry["properties"]["radius"]), 1.6)

	# 13. Only safe data serialized.
	var allowed_keys := ["type", "id", "position", "rotation_deg", "scale", "properties"]
	var keys_ok := true
	for k in entry.keys():
		if not allowed_keys.has(k):
			keys_ok = false
	var props_ok := true
	for k in (entry["properties"] as Dictionary).keys():
		if not TableRegistry.props_of("bumper").has(k):
			props_ok = false
	_r["serialize_safe"] = keys_ok and props_ok

	# 9. Save -> Load round-trip.
	var path := "user://tables/probe_roundtrip.json"
	_editor.save(path)
	var count_before := _count_components(table)
	_editor.new_table()
	var count_blank := _count_components(table)
	_editor.load(path)
	var count_after := _count_components(table)
	var loaded_bumper: Node3D = table.get_node_or_null("Bumper01")
	_r["save_load_roundtrip"] = count_blank < count_before and count_after == count_before \
		and loaded_bumper != null and is_equal_approx(loaded_bumper.radius, 1.6)

	# 10. Play <-> Edit preserves layout.
	_editor.select(loaded_bumper)
	_editor.nudge_translate(Vector3(0, 0, 3))
	var moved := loaded_bumper.position
	_editor.set_editing(false)
	_editor.set_editing(true)
	_r["play_edit_preserves"] = loaded_bumper.position.is_equal_approx(moved)

func _setup_flipper_test() -> void:
	var table: Node3D = _editor.table
	_flipper = table.get_node_or_null("LeftFlipper")
	if _flipper == null:
		_r["flipper_operates"] = false
		_r["flipper_pos_preserved"] = false
		return
	_editor.select(_flipper)
	_editor.nudge_translate(Vector3(-1, 0, 0))
	_flipper_moved_pos = _flipper.position
	_editor.set_editing(false)  # enter play
	_flipper_rest_y = _flipper.rotation.y

func _count_components(table: Node) -> int:
	var n := 0
	for c in table.get_children():
		if TableRegistry.type_of(c) != "":
			n += 1
	return n

func _report() -> void:
	print("--- EDITOR v1 SMOKE ---")
	var ok := true
	var order := ["pick_resolves", "move_changes", "rotate_changes", "pos_snap", "rot_snap",
		"add_creates", "duplicate", "delete", "undo_restores", "redo_restores",
		"property_applies", "property_serializes", "serialize_safe", "save_load_roundtrip",
		"play_edit_preserves", "flipper_operates", "flipper_pos_preserved"]
	for k in order:
		var v: bool = _r.get(k, false)
		ok = ok and v
		print("  %-22s %s" % [k, str(v)])
	print("RESULT: %s" % ("PASS" if ok else "CHECK"))
