class_name PhysicsTestCase
extends GutTest
## Base for tests that step real physics. Waits go through wait_ticks(), which also marks
## known, self-recovering engine warnings as handled so they alone cannot fail a test.
## Every other engine error still fails the test, including ones raised in before_each
## (checked in after_each; subclasses that override after_each must call super()).

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
		_mark_if_known(error)


## GUT only starts tracking errors for a test after before_each returns, so errors raised while
## spawning and settling would otherwise never fail anything. This runs after the test even when
## a script error aborted before_each half way.
func after_each() -> void:
	_fail_on_setup_errors()


func _fail_on_setup_errors() -> void:
	var tracker = gut.error_tracker
	var setup_errors: Array = tracker.errors.items.get(GutUtils.NO_TEST, [])
	for error in setup_errors:
		_mark_if_known(error)
		if not error.handled and tracker._is_error_failable(error):
			fail_test("Engine error outside the test body: %s" % error.code)
	setup_errors.clear()


func _mark_if_known(error) -> void:
	for text in KNOWN_ENGINE_WARNINGS:
		if error.contains_text(text):
			error.handled = true
