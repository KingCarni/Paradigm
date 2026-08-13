class_name Drain
extends Area3D

## The bottom drain. When the ball falls between the flippers into this trigger,
## it emits GameEvents.ball_drained(ball). The table's active-ball service listens
## and decides what to do next (respawn, for the spike). The drain itself owns no
## lifecycle or scoring logic — it only reports the semantic event.

@export var size: Vector3 = Vector3(6.0, 2.0, 1.5)

func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.name = "Collision"
	add_child(col)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is PinballBall:
		GameEvents.ball_drained.emit(body)
