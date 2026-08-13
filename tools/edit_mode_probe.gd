extends Node

## Headless smoke test for Developer Edit Mode (PAR-41). Drives the real EditMode
## via synthetic key events and checks add / duplicate / move / delete / save /
## enter-exit. Attached only when launched with `-- edittest`.
##
## Run: godot --headless --path <project> -- edittest

var _spike: Node
var _table: Node
var _edit: Node
var _frames := 0
var _count0 := 0
var _x0 := 0.0
var _results: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while EditMode pauses the tree

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _edit == null:
		_spike = get_parent()
		_table = _spike.get_node_or_null("Table")
		_edit = _spike.get_node_or_null("Debug/EditMode")
		return

	match _frames:
		4:
			_edit.toggle()  # enter
			_results["entered_paused"] = get_tree().paused and _edit.is_active()
			_count0 = _table.get_child_count()
		8:
			_send(KEY_2)  # add bumper
		12:
			_results["add"] = _table.get_child_count() == _count0 + 1
			_send(KEY_INSERT)  # duplicate
		16:
			_results["duplicate"] = _table.get_child_count() == _count0 + 2
			var n: Node3D = _edit._selected_node()
			_x0 = n.position.x if n != null else 0.0
			_send(KEY_RIGHT)  # move +x
		20:
			var n: Node3D = _edit._selected_node()
			_results["move"] = n != null and n.position.x > _x0
			_send(KEY_DELETE)
		24:
			_results["delete"] = _table.get_child_count() == _count0 + 1
			_send(KEY_S, true)  # ctrl+s save
		28:
			_results["save"] = FileAccess.file_exists("user://tables/dev_layout.json")
			_send(KEY_L, true)  # ctrl+l load saved layout
		34:
			_results["load"] = _table.get_child_count() == _count0 + 1
			_edit.toggle()  # exit
		38:
			_results["exited_unpaused"] = not get_tree().paused and not _edit.is_active()
			_report()
			get_tree().quit()

func _send(keycode: int, ctrl: bool = false, shift: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	_edit._input(e)

func _report() -> void:
	print("--- EDIT MODE SMOKE ---")
	var ok := true
	for k in ["entered_paused", "add", "duplicate", "move", "delete", "save", "load", "exited_unpaused"]:
		var pass_k: bool = _results.get(k, false)
		ok = ok and pass_k
		print("  %-18s %s" % [k, str(pass_k)])
	print("RESULT: %s" % ("PASS" if ok else "CHECK"))
