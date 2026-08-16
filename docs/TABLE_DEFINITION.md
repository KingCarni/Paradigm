# Table Definition Format

A **table definition** is a human-readable JSON description of a pinball table
layout. It is pure data (no executable scripts, no runtime state), so layouts are
inspectable and version-controllable. Reusable Godot component scenes remain the
runtime implementation — a table definition only describes *which* components exist,
*where*, and *how they are configured*.

- In-memory type: `TableDefinition` (`scripts/pinball/table_definition.gd`).
- Loader/serializer: `TableLoader` (`scripts/pinball/table_loader.gd`).
- Type ↔ scene ↔ property registry: `TableRegistry` (`scripts/pinball/table_registry.gd`).
- Default/sample: `data/pinball/tables/default_table.json` (the physics spike).
- Saved dev layouts: `user://tables/*.json` (from Edit Mode).

## Top-level schema

```json
{
  "schema_version": 1,
  "id": "physics_spike_default",
  "name": "Physics Spike (default)",
  "settings": { "tuning": "res://data/pinball/table_tuning.tres" },
  "components": [ /* component entries */ ]
}
```

| Field | Meaning |
|---|---|
| `schema_version` | Integer. Current is `1`. A newer version loads best-effort with a warning; unknown fields are ignored. |
| `id` | Stable table identifier. |
| `name` | Human-readable table name. |
| `settings` | Table-level settings dictionary. Currently a `tuning` resource path; future: bounds, gravity/incline profile, evolution anchors. |
| `components` | Array of component entries (below). |

## Component entry

```json
{
  "type": "bumper",
  "id": "Bumper01",
  "position": [-2.5, 0.8, -5.0],
  "rotation_deg": [0.0, 0.0, 0.0],
  "scale": [1.0, 1.0, 1.0],
  "properties": { "radius": 1.0, "height": 1.6 }
}
```

| Field | Meaning |
|---|---|
| `type` | Component type (see table below). Unknown types are skipped with a diagnostic. |
| `id` | Stable component ID (also the node name at runtime). |
| `position` | `[x, y, z]` local to the table container. |
| `rotation_deg` | `[x, y, z]` Euler degrees (YXZ order). |
| `scale` | `[x, y, z]`. |
| `properties` | Type-specific config (see registry). Vectors are `[x,y,z]`, colors `[r,g,b,a]`. |

## Supported component types

| `type` | Scene | `properties` keys |
|---|---|---|
| `wall` | `wall.tscn` | `size`, `wall_color`, `friction`, `bounce` |
| `bumper` | `bumper.tscn` | `radius`, `height`, `impulse_override` (−1 = global tuning) |
| `slingshot` | `slingshot.tscn` | `length`, `thickness`, `height`, `impulse_override` (−1 = global) |
| `ramp` | `ramp.tscn` | `ramp_length`, `ramp_width`, `ramp_thickness`, `ramp_pitch_degrees`, `side_wall_height` |
| `drain` | `drain.tscn` | `size` |
| `plunger` | `plunger.tscn` | `trigger_size`, `min_charge` |
| `flipper` | `flipper.tscn` | `side` (0=left,1=right), `action_name`, `rest_droop_degrees`, `bat_length` |
| `ball_spawn` | (bare `Marker3D`) | — |

`TableRegistry` is the single source of truth for this mapping; add a new component
type by extending `SCENES` + `PROPS` (+ `type_of` + `PALETTE`) there.

## Loading / saving

- `TableLoader.build(def, container)` clears the container and instantiates each
  component scene, applying transform + properties. Unknown types fail safely.
- `TableLoader.serialize(container, id, name, settings)` walks live editable
  components back into a `TableDefinition`.
- `TableDefinition.save_to(path)` / `load_from(path)` handle JSON I/O.
- The running spike can build from the definition with `-- loadtable`, and
  regenerate `default_table.json` from the authored scene with `-- exporttable`.

## Guarantees / constraints

- Human-readable JSON, source-control friendly.
- No executable scripts or unsafe runtime state are serialized.
- Unknown component types / newer schema versions fail safely rather than corrupt.
- The loader is not a god-object: it only translates data ↔ component scenes and
  knows nothing about scoring, combat, upgrades or run progression.
- Structure intentionally leaves room for a future player-facing create/share
  feature, but no sharing/online/moderation is implemented.
