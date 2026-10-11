class_name PhysicsTestCase
extends GutTest
## Base for tests that step real physics. Waits go through wait_ticks(), which also marks
## known, self-recovering engine warnings as handled so they alone cannot fail a test.
## Every other engine error still fails the test.

## Godot 4.7.2's Jolt job pool occasionally runs dry, logs this once and recovers by waiting
## (godotengine/godot#110724, open as of 2026-10).
const KNOWN_ENGINE_WARNINGS: Array[String] = [
	"Jolt Physics job system exceeded the maximum number of jobs",
]


## Waits exactly `ticks` physics steps. (GUT's wait_physics_frames(n) resumes one step later
## than n when called back to back, which doubles the length of tick-by-tick loops.)
func wait_ticks(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame
	for error in get_errors():
		for text in KNOWN_ENGINE_WARNINGS:
			if error.contains_text(text):
				error.handled = true
