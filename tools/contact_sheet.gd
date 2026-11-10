extends SceneTree
## A contact sheet of stage shots (tools\stage_shots.ps1 -Sheet): the shots of one stage and weather, a row per place and a column
## per time of day, each under its name, so the times can be judged side by side. Reads --dir=<the stage's folder> --weather=N and
## writes --out=<png>. Runs windowed (2D needs a renderer); the sheet is a SubViewport of its own size, not the window's.
## No class names here: a -s script compiles before the autoloads exist.

const THUMB := Vector2i(400, 225)
const CAPTION := 22
const TIMES := ["day", "golden hour", "dusk", "night"]
const WEATHERS := ["clear", "rain", "fog", "snow", "dust storm"]

var _viewport: SubViewport
var _out := ""
var _frames := 3


func _initialize() -> void:
	var dir := ""
	var weather := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--weather="):
			weather = int(arg.get_slice("=", 1))
	var columns: Array[String] = []
	for time in TIMES.size():
		if DirAccess.dir_exists_absolute(dir.path_join("w%dt%d" % [weather, time])):
			columns.append("w%dt%d" % [weather, time])
	var rows := PackedStringArray()
	for column in columns:
		for file in DirAccess.get_files_at(dir.path_join(column)):
			if file.ends_with(".png") and not rows.has(file):
				rows.append(file)
	rows.sort()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(maxi(columns.size(), 1) * THUMB.x, maxi(rows.size(), 1) * (THUMB.y + CAPTION))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(_viewport)
	var ground := ColorRect.new()
	ground.color = Color(0.07, 0.07, 0.07)
	ground.size = _viewport.size
	_viewport.add_child(ground)
	for c in columns.size():
		for r in rows.size():
			var at := Vector2(c * THUMB.x, r * (THUMB.y + CAPTION))
			var path := dir.path_join(columns[c]).path_join(rows[r])
			if FileAccess.file_exists(path):
				var shot := TextureRect.new()
				shot.texture = ImageTexture.create_from_image(Image.load_from_file(path))
				shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				shot.stretch_mode = TextureRect.STRETCH_SCALE
				shot.position = at + Vector2(0.0, CAPTION)
				shot.size = Vector2(THUMB) - Vector2(4.0, 4.0)
				_viewport.add_child(shot)
			var caption := Label.new()
			caption.text = "%s · %s · %s" % [rows[r].get_basename(), WEATHERS[weather], TIMES[int(columns[c].get_slice("t", 1))]]
			caption.position = at + Vector2(4.0, 0.0)
			caption.add_theme_font_size_override(&"font_size", 15)
			caption.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.3))
			_viewport.add_child(caption)


func _process(_delta: float) -> bool:
	_frames -= 1
	if _frames > 0:
		return false
	_viewport.get_texture().get_image().save_png(_out)
	print("SHEET ", _out)
	return true
