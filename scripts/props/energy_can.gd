class_name EnergyCan
extends RigidBody3D
## A thrown energy-drink can. The host simulates it (BodyNetSync with authority 1); other peers
## play back its snapshots. RaceSession spawns and despawns it.

## A can has to arrive at least this fast (relative, m/s) to mark a window.
const WINDOW_HIT_MIN_SPEED := 6.0


func _ready() -> void:
	continuous_cd = true  # small and fast: do not pass through car panels or posts
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


## The host (who simulates cans) tells a car's cabin when a can hits a side window (spec §10.3).
func _on_body_entered(body: Node) -> void:
	if Net.is_active() and not multiplayer.is_server():
		return
	var car := body as RallyCar
	if car == null:
		return
	var local := car.to_local(global_position)
	if local.y < 0.45 or absf(local.x) < 0.55 or absf(local.z) > 1.0:
		return
	var relative_speed := (linear_velocity - car.linear_velocity).length()
	if relative_speed < WINDOW_HIT_MIN_SPEED:
		return
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null:
		cabin.window_hit(Cabin.Side.RIGHT if local.x > 0.0 else Cabin.Side.LEFT, relative_speed)
