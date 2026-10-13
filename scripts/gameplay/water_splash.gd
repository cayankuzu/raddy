class_name WaterSplash
extends Area3D
## A water splash across the road (built by TrackFeatures): cars driving through are slowed by the
## water and throw spray (RallyCar.water_contacts), and the host soaks their windshield (Cabin).
## Areas see the frozen playback copies too, so every peer shows the spray.

## Height of the water surface.
var level := 0.0


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var car := body as RallyCar
	if car != null:
		car.water_contacts += 1
		car.water_level = level


func _on_body_exited(body: Node3D) -> void:
	var car := body as RallyCar
	if car != null:
		car.water_contacts = maxi(car.water_contacts - 1, 0)
