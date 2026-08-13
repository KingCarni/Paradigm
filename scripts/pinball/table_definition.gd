class_name TableDefinition
extends RefCounted

## In-memory, JSON-serializable description of a pinball table layout.
##
## Pure DATA: table id/name, table-level settings, and a list of component entries
## (type, stable id, position, rotation, scale, component-specific properties). It
## never stores executable scripts or runtime state. On-disk form is human-readable
## JSON, so layouts are inspectable and version-controllable. Reusable Godot scenes
## remain the runtime implementation (see TableLoader / TableRegistry).

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var id: String = "untitled"
var name: String = "Untitled Table"
## Table-level settings (e.g. {"tuning": "res://data/pinball/table_tuning.tres"}).
var settings: Dictionary = {}
## Each entry: {type, id, position:[x,y,z], rotation_deg:[x,y,z], scale:[x,y,z], properties:{}}.
var components: Array = []

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"id": id,
		"name": name,
		"settings": settings,
		"components": components,
	}

static func from_dict(d: Dictionary) -> TableDefinition:
	var def := TableDefinition.new()
	def.schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	if def.schema_version > SCHEMA_VERSION:
		push_warning("[TableDefinition] file schema_version %d is newer than supported %d; loading best-effort."
			% [def.schema_version, SCHEMA_VERSION])
	def.id = str(d.get("id", "untitled"))
	def.name = str(d.get("name", def.id))
	def.settings = d.get("settings", {})
	def.components = d.get("components", [])
	return def

func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")

static func from_json(text: String) -> TableDefinition:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[TableDefinition] invalid JSON (expected an object).")
		return null
	return from_dict(parsed)

func save_to(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[TableDefinition] cannot write " + path)
		return FileAccess.get_open_error()
	f.store_string(to_json())
	f.close()
	return OK

static func load_from(path: String) -> TableDefinition:
	if not FileAccess.file_exists(path):
		push_error("[TableDefinition] file not found: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	return from_json(text)
