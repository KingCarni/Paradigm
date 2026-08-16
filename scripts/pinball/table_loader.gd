class_name TableLoader
extends RefCounted

## Builds a playable table by instantiating reusable component scenes from a
## [TableDefinition] into a container node, and serializes a live container back
## into a definition. Deliberately NOT a god-object: it only translates between
## layout data and component scene instances. The editor reuses spawn()/entry_for()
## for add / duplicate / undo.

## Build [container]'s children from [def]. Clears existing children first.
## Returns {"built": int, "errors": Array[String]}.
static func build(def: TableDefinition, container: Node) -> Dictionary:
	var result := {"built": 0, "errors": []}
	if def == null or container == null:
		result["errors"].append("null definition or container")
		return result

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	for entry in def.components:
		if not (entry is Dictionary):
			result["errors"].append("component entry is not an object")
			continue
		var node := spawn(entry, container)
		if node == null:
			var msg := "unknown/invalid component '%s' (id=%s) — skipped" % [str(entry.get("type", "")), str(entry.get("id", "?"))]
			push_warning("[TableLoader] " + msg)
			result["errors"].append(msg)
			continue
		result["built"] += 1

	return result

## Instantiate a single component entry into [container]. Returns the node or null
## if the type is unknown. Applies transform + properties.
static func spawn(entry: Dictionary, container: Node) -> Node3D:
	var type := str(entry.get("type", ""))
	if not TableRegistry.is_known(type):
		return null
	var node := TableRegistry.instantiate(type)
	if node == null:
		return null
	node.name = str(entry.get("id", type))
	node.transform = _entry_transform(entry)
	node.set_meta("component_id", node.name)
	container.add_child(node)
	# Apply properties after _ready so setters rebuild geometry.
	TableRegistry.apply_props(node, type, entry.get("properties", {}))
	return node

## Serialize a single live component node into an entry dictionary ({} if the node
## is not an editable component).
static func entry_for(node: Node) -> Dictionary:
	var type := TableRegistry.type_of(node)
	if type == "":
		return {}
	var n3 := node as Node3D
	return {
		"type": type,
		"id": node.name,
		"position": _v3_to_arr(n3.position),
		"rotation_deg": _v3_to_arr(_degrees(n3.rotation)),
		"scale": _v3_to_arr(n3.scale),
		"properties": TableRegistry.read_props(node, type),
	}

## Serialize [container]'s editable component children into a [TableDefinition].
static func serialize(container: Node, id: String, table_name: String, settings: Dictionary) -> TableDefinition:
	var def := TableDefinition.new()
	def.id = id
	def.name = table_name
	def.settings = settings
	for child in container.get_children():
		var entry := entry_for(child)
		if not entry.is_empty():
			def.components.append(entry)
	return def

static func _entry_transform(entry: Dictionary) -> Transform3D:
	var pos := _arr_to_v3(entry.get("position", [0, 0, 0]), Vector3.ZERO)
	var rot_deg := _arr_to_v3(entry.get("rotation_deg", [0, 0, 0]), Vector3.ZERO)
	var scl := _arr_to_v3(entry.get("scale", [1, 1, 1]), Vector3.ONE)
	var basis := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	basis = basis.scaled(scl)
	return Transform3D(basis, pos)

static func _v3_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _arr_to_v3(a: Variant, fallback: Vector3) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(a[0], a[1], a[2])
	return fallback

static func _degrees(radians: Vector3) -> Vector3:
	return Vector3(rad_to_deg(radians.x), rad_to_deg(radians.y), rad_to_deg(radians.z))
