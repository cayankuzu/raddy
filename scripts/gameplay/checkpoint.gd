class_name Checkpoint
extends Area3D
## A gate across the road. Reports cars that drive through it; the race layer (host) decides
## whether the pass counts (spec §15: checkpoints validate order, alternatives stay legal).

signal passed(index: int, car: RallyCar)

var index := 0


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is RallyCar:
		passed.emit(index, body)
