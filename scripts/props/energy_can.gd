class_name EnergyCan
extends RigidBody3D
## A thrown energy-drink can. The host simulates it (BodyNetSync with authority 1); other peers
## play back its snapshots. RaceSession spawns and despawns it.

func _ready() -> void:
	continuous_cd = true  # small and fast: do not pass through car panels or posts
