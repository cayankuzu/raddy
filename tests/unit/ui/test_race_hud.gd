extends GutTest
## The race HUD's corners: who gets the rev counter, how it makes way for a door mirror, and the start's flag.


func test_only_the_driver_gets_the_rev_counter() -> void:
	assert_true(RaceHud.shows_cluster(true, RosterRules.Role.DRIVER))
	assert_false(RaceHud.shows_cluster(true, RosterRules.Role.NAVIGATOR), "his own door mirror would lie under it")
	assert_false(RaceHud.shows_cluster(false, RosterRules.Role.DRIVER), "nothing to show without a car")


func test_the_rev_counter_makes_way_for_the_mirror_under_it() -> void:
	var rect := Rect2(1000.0, 500.0, 250.0, 250.0)
	assert_eq(HudCluster.alpha_over(Vector2(1100.0, 600.0), rect), HudCluster.OVER_A_MIRROR, "the glass's middle is under it")
	assert_eq(HudCluster.alpha_over(rect.position - Vector2.ONE * (HudCluster.MIRROR_REACH * 0.5), rect), HudCluster.OVER_A_MIRROR, "or close enough for the glass to be")
	assert_eq(HudCluster.alpha_over(Vector2(800.0, 600.0), rect), 1.0, "clear of it: all there")


func test_the_flag_on_the_stage_bar_is_scaled_down_with_its_mipmaps() -> void:
	var bar := autofree(HudStageBar.new()) as HudStageBar
	assert_eq(bar.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	assert_true(TurkishFlag.texture().get_image().has_mipmaps())
