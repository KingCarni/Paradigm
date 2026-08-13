extends Node

## Shared semantic events. Keep this list deliberate; do not use it as a dumping ground.

signal ball_spawned(ball: Node3D)
signal ball_drained(ball: Node3D)
signal component_hit(component: Node3D, ball: Node3D, context: Dictionary)
signal component_completed(component: Node3D, context: Dictionary)
signal encounter_started(encounter_id: StringName)
signal encounter_completed(encounter_id: StringName)
signal upgrade_acquired(upgrade_id: StringName)
