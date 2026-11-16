class_name CarLivery
extends Node3D
## A rally car's livery, on every peer from the roster (RaceSession: show_crew). On the paint, so the road covers them as it covers the
## paint (shaders/car_body.gdshader, the paint's own skins: no draw call of its own): a panel with the crew's number on each front door
## and the rally plate on the bonnet's front. Cut from white vinyl on the glass (shaders/car_sticker.gdshader: one mesh from the glass's
## own triangles, one draw call): the crew's names, each after a small flag of Turkey, on the rear side windows, and the number at the
## top of the rear window, where a car behind reads it. Behind each wheel a mud flap, the first thing the road covers (one mesh, a CarDirt
## skin). All of it is drawn here: the event's name from the strings, the number and the names; no maker's logo anywhere.

const STICKER_SHADER := preload("res://shaders/car_sticker.gdshader")
## The picture every part is drawn into, and how many of its pixels make a metre on the car; a crew member's name for the suit and the
## helmet (name_picture: as long against its height as the chest's box, CrewBody.NAME_SIZE).
const PICTURE := Vector2i(1024, 512)
const PER_METRE := 880.0
const NAME_PICTURE := Vector2i(576, 96)
## The capitals with marks over or under them (_with_marks).
const MARKED := "ÇĞİÖŞÜ"
## Each part: where its middle lies on the car (car space: a door panel along and up either flank (z, y); the plate across and along the
## bonnet (x, z); the names along and up either rear side window (z, y); the number across and up the rear window (x, y)), how big it is
## there (metres) and where it starts in the picture (pixels).
const DOOR := {"at": Vector2(-0.16, 0.11), "size": Vector2(0.62, 0.3), "pixel": Vector2i(0, 0)}
const PLATE := {"at": Vector2(0.0, -1.68), "size": Vector2(0.42, 0.2), "pixel": Vector2i(560, 0)}
const NAMES := {"at": Vector2(0.83, 0.52), "size": Vector2(0.4, 0.13), "pixel": Vector2i(0, 280)}
const REAR := {"at": Vector2(-0.24, 0.6), "size": Vector2(0.38, 0.22), "pixel": Vector2i(560, 196)}
## Where the glass under the stickers is (car space): a rear side window, its middle further out than this to either side and within
## these lengths along the car; the rear window, behind this.
const SIDE_GLASS_OUT := 0.5
const SIDE_GLASS_ALONG := Vector2(0.45, 1.3)
const REAR_GLASS_BEHIND := 1.3
## The vinyl sits this far outside the glass (m).
const VINYL_LIFT := 0.002
## The mud flaps: behind the front wheels and the rear ones (z), from the body down to a hand's width over the road (y, top and bottom),
## across from the tyre's inside to the body's flank (x), this thick.
const FLAPS: Array[Dictionary] = [{"z": -0.78, "y": Vector2(-0.3, -0.5), "x": Vector2(0.56, 0.79)},
	{"z": 1.63, "y": Vector2(-0.26, -0.5), "x": Vector2(0.55, 0.8)}]
const FLAP_THICKNESS := 0.012
const FLAP_PRINT := Vector2i(128, 96)
## The colours of the print: the panel's white, the lettering's black.
const WHITE := Color(0.93, 0.93, 0.9)
const BLACK := Color(0.045, 0.045, 0.05)

## The number and the names shown now, and the picture they make.
var number := ""
var names := PackedStringArray()
var picture: ImageTexture

var _car: RallyCar
var _paints: Array[ShaderMaterial] = []
## The team's colour the picture was drawn in.
var _paint := Color.TRANSPARENT
var _stickers: MeshInstance3D
var _sticker_material := ShaderMaterial.new()
var _flaps: MeshInstance3D

static var _flap_print: ImageTexture


## Puts the parts on the car: `model` is the car's model scene, `dirt` its CarDirt (the paint's skins, the flaps' own), `car_space` turns a
## node into the car body's space.
func build(model: Node3D, dirt: CarDirt, car_space: Callable) -> void:
	_car = dirt.car
	_paints = dirt.paints
	for skin in _paints:
		skin.set_shader_parameter(&"door_box", _box(DOOR))
		skin.set_shader_parameter(&"door_uv", _uv(DOOR))
		skin.set_shader_parameter(&"plate_box", _box(PLATE))
		skin.set_shader_parameter(&"plate_uv", _uv(PLATE))
	var glass: Array[Array] = []
	for glass_name in CarModel.FIXED_GLASS:
		for node in model.find_child(glass_name, true, false).find_children("*", "MeshInstance3D", true, false):
			glass.append([(node as MeshInstance3D).mesh, car_space.call(node)])
	_sticker_material.shader = STICKER_SHADER
	_stickers = MeshInstance3D.new()
	_stickers.name = "Stickers"
	_stickers.mesh = sticker_mesh(glass)
	_stickers.material_override = _sticker_material
	_stickers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stickers.visible = false
	add_child(_stickers)
	_flaps = MeshInstance3D.new()
	_flaps.name = "MudFlaps"
	_flaps.mesh = flap_mesh()
	_flaps.set_surface_override_material(0, dirt.skin_of(_flaps.mesh.surface_get_material(0) as StandardMaterial3D, Transform3D.IDENTITY))
	# They hang in the shadow of the body and the wheels.
	_flaps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flaps)


## The crew this car carries now: its `number` and the names lettered for the rear side windows (LiveryRules). Drawn again only when it
## changed.
func show_crew(crew_number: String, crew_names: PackedStringArray) -> void:
	if crew_number == number and crew_names == names and picture != null:
		return
	number = crew_number
	names = crew_names
	_draw()


## The team's colour may have changed: it is on the door panels' stripe and round the plate.
func repaint() -> void:
	if picture != null and _car.paint_color != _paint:
		_draw()


func _draw() -> void:
	_paint = _car.paint_color
	var image := draw_picture(number, names, _paint)
	if picture == null or picture.get_size() != Vector2(image.get_size()):
		picture = ImageTexture.create_from_image(image)
	else:
		picture.update(image)
	for skin in _paints:
		skin.set_shader_parameter(&"livery_map", picture)
		skin.set_shader_parameter(&"livery", not number.is_empty())
	_sticker_material.set_shader_parameter(&"picture", picture)
	_stickers.visible = not number.is_empty()


## A crew member's name (LiveryRules.seat_name) as it is embroidered on the suit and carried on the helmet: white letters on nothing (the
## alpha is the ink), as large as NAME_PICTURE holds them, every name the same height unless it is too long for the width.
static func name_picture(lettered: String) -> Image:
	var image := Image.create(NAME_PICTURE.x, NAME_PICTURE.y, false, Image.FORMAT_RGBA8)
	_print(image, lettered, UiTheme.hud_font(700, 100), Rect2i(Vector2i.ZERO, NAME_PICTURE).grow(-4))
	image.generate_mipmaps()
	return image


## A part's box on the car (from, to: the two lengths of `at`).
static func _box(part: Dictionary) -> Vector4:
	var at: Vector2 = part.at
	var size: Vector2 = part.size
	var half := size * 0.5
	return Vector4(at.x - half.x, at.y - half.y, at.x + half.x, at.y + half.y)


## A part's corners in the picture (u, v from; u, v to).
static func _uv(part: Dictionary) -> Vector4:
	var pixel: Vector2i = part.pixel
	var size: Vector2 = part.size
	var from := Vector2(pixel) / Vector2(PICTURE)
	var to := (Vector2(pixel) + size * PER_METRE) / Vector2(PICTURE)
	return Vector4(from.x, from.y, to.x, to.y)


static func _rect(part: Dictionary) -> Rect2i:
	var size: Vector2 = part.size
	return Rect2i(part.pixel, Vector2i(size * PER_METRE))


# --- the picture ---

## Every part drawn for the crew `crew_number` with `crew_names`, the team's `paint` on the door panels' stripe and round the plate.
static func draw_picture(crew_number: String, crew_names: PackedStringArray, paint: Color) -> Image:
	var image := Image.create(PICTURE.x, PICTURE.y, false, Image.FORMAT_RGBA8)
	if crew_number.is_empty():
		image.generate_mipmaps()
		return image
	var event := TranslationServer.translate("LIVERY_EVENT")
	var bold := UiTheme.hud_font(800, 100)
	var tall := UiTheme.hud_font(800, 75)
	# The door panel: white, the event on a black band over a stripe of the team's colour, the number under it.
	var door := _rect(DOOR)
	_rounded(image, door, roundi(door.size.y * 0.06), WHITE)
	var band := Rect2i(door.position, Vector2i(door.size.x, roundi(door.size.y * 0.27)))
	_rounded(image, band, roundi(door.size.y * 0.06), BLACK, true)
	image.fill_rect(Rect2i(band.position.x, band.end.y, band.size.x, roundi(door.size.y * 0.07)), paint)
	_print(image, event, bold, band.grow_individual(-24, -14, -24, -12))
	var field := Rect2i(door.position.x, band.end.y + roundi(door.size.y * 0.07), door.size.x, door.end.y - band.end.y - roundi(door.size.y * 0.07))
	_print(image, crew_number, tall, field.grow(-roundi(field.size.y * 0.12)), true, 0, 0.5, true)
	# The plate: white in a frame of the team's colour, the event over the number.
	var plate := _rect(PLATE)
	_rounded(image, plate, roundi(plate.size.y * 0.1), paint)
	var inner := plate.grow(-roundi(plate.size.y * 0.06))
	_rounded(image, inner, roundi(plate.size.y * 0.07), WHITE)
	var top := Rect2i(inner.position, Vector2i(inner.size.x, roundi(inner.size.y * 0.34)))
	_print(image, event, bold, top.grow_individual(-16, -8, -16, -4), true)
	_print(image, crew_number, tall, Rect2i(inner.position.x, top.end.y, inner.size.x, inner.end.y - top.end.y).grow(-10), true, 0, 0.5, true)
	# The names: a line each, a flag before the name, white with a black rim.
	var lines := _rect(NAMES)
	var line_height := lines.size.y / 2
	var flag_height := roundi(line_height * 0.62)
	var flag := TurkishFlag.image(flag_height * 3)
	flag.resize(roundi(flag_height * TurkishFlag.LENGTH), flag_height, Image.INTERPOLATE_LANCZOS)
	flag.convert(Image.FORMAT_RGBA8)
	for i in mini(crew_names.size(), 2):
		var line := Rect2i(lines.position.x, lines.position.y + line_height * i, lines.size.x, line_height)
		var flag_at := Vector2i(line.position.x + 6, line.position.y + (line_height - flag_height) / 2)
		image.fill_rect(Rect2i(flag_at - Vector2i(2, 2), flag.get_size() + Vector2i(4, 4)), WHITE)
		image.blit_rect(flag, Rect2i(Vector2i.ZERO, flag.get_size()), flag_at)
		var text_left := flag_at.x + flag.get_width() + roundi(line_height * 0.3)
		_print(image, crew_names[i], bold, Rect2i(text_left, line.position.y + 6, line.end.x - text_left - 4, line_height - 12), false, 3, 0.0)
	# The rear window's number: white with a black rim.
	_print(image, crew_number, tall, _rect(REAR).grow(-4), false, 5, 0.5, true)
	image.generate_mipmaps()
	return image


## A rectangle with round corners (`radius` px) filled with `color`; only the top two round with `top_only`.
static func _rounded(image: Image, rect: Rect2i, radius: int, color: Color, top_only := false) -> void:
	image.fill_rect(rect.grow_individual(0, -radius, 0, 0 if top_only else -radius), color)
	image.fill_rect(rect.grow_individual(-radius, 0, -radius, 0), color)
	var rows: Array[int] = [rect.position.y + radius]
	if not top_only:
		rows.append(rect.end.y - radius - 1)
	for row in rows:
		for column: int in [rect.position.x + radius, rect.end.x - radius - 1]:
			var way := Vector2i(signi(column - rect.get_center().x), signi(row - rect.get_center().y))
			for dy in radius + 1:
				for dx in radius + 1:
					if dx * dx + dy * dy <= radius * radius:
						image.set_pixel(column + way.x * dx, row + way.y * dy, color)


## `text` lettered into `image` as large as fits in `box` (pixels), centred up and down and placed across by `align` (0 left, 1 right): white,
## or black (`dark`), with a black rim `rim` pixels wide round white letters. Sized by the font's line with room for the capitals' marks
## (`_with_marks`: every name the same size whatever its letters, none cut) or, `tight`, by the ink itself (a number as big as its box).
static func _print(image: Image, text: String, font: Font, box: Rect2i, dark := false, rim := 0, align := 0.5, tight := false) -> void:
	var room := box.size - Vector2i.ONE * rim * 2
	if text.is_empty() or room.x <= 0 or room.y <= 0:
		return
	var probe := _letters(text, font, 100)
	var ink := Rect2((probe[0] as Image).get_used_rect())
	var line: Rect2 = ink if tight else _with_marks(probe[1], font, 100)
	var size := floori(minf(room.y * 100.0 / maxf(line.size.y, 1.0), room.x * 100.0 / maxf(maxf(line.size.x, ink.size.x), 1.0)))
	if size < 4:
		return
	var lettered := _letters(text, font, size)
	var layer: Image = lettered[0]
	var placed: Rect2 = Rect2(layer.get_used_rect()) if tight else _with_marks(lettered[1], font, size)
	var at := box.position + Vector2i(roundi(rim + (room.x - placed.size.x) * align - placed.position.x),
		roundi(rim + (room.y - placed.size.y) * 0.5 - placed.position.y))
	var whole := Rect2i(Vector2i.ZERO, layer.get_size())
	var black := layer.duplicate() as Image
	black.adjust_bcs(0.0, 1.0, 1.0)
	if rim > 0:
		for step in 16:
			var way := Vector2.from_angle(TAU * step / 16.0)
			for reach: float in [rim, rim * 0.5]:
				image.blend_rect(black, whole, at + Vector2i((way * reach).round()))
	image.blend_rect(black if dark else layer, whole, at)


## A line's box (_letters' at `size`) stretched up and down over the marks of the capitals that carry them (MARKED): the font's ascent
## leaves the dots and the breve over Ğ, İ, Ö, Ü out.
static func _with_marks(line: Rect2, font: Font, size: int) -> Rect2:
	var marks := Rect2((_letters(MARKED, font, size)[0] as Image).get_used_rect())
	var top := minf(line.position.y, marks.position.y)
	return Rect2(line.position.x, top, line.size.x, maxf(line.end.y, marks.end.y) - top)


## `text` in white at `size`, and where the line's box lies in the picture (from the pen's start, its ascent and descent): [Image, Rect2].
## Room is left round it for what reaches past the box (a dot, a cedilla, a slanted stroke). The glyphs come from the font's own cache
## (the TextServer's, which works headless too).
static func _letters(text: String, font: Font, size: int) -> Array:
	var server := TextServerManager.get_primary_interface()
	var line := server.create_shaped_text()
	server.shaped_text_add_string(line, text, font.get_rids(), size, font.get_opentype_features())
	var ascent := server.shaped_text_get_ascent(line)
	var margin := ceilf(size * 0.25)
	var box := Rect2(margin, margin, server.shaped_text_get_width(line), ascent + server.shaped_text_get_descent(line))
	var layer := Image.create(ceili(box.end.x + margin), ceili(box.end.y + margin), false, Image.FORMAT_RGBA8)
	var pages := {}
	var pen := margin
	for glyph: Dictionary in server.shaped_text_get_glyphs(line):
		var rid: RID = glyph.font_rid
		var glyph_size := Vector2i(int(glyph.font_size), 0)
		var index: int = glyph.index
		var page := server.font_get_glyph_texture_idx(rid, glyph_size, index)
		if page >= 0:
			var key := [rid, glyph_size, page]
			if not pages.has(key):
				pages[key] = server.font_get_texture_image(rid, glyph_size, page)
			var uv := server.font_get_glyph_uv_rect(rid, glyph_size, index)
			var piece := (pages[key] as Image).get_region(Rect2i(uv.position, uv.size))
			piece.convert(Image.FORMAT_RGBA8)
			var at := Vector2(pen, margin + ascent) + (glyph.offset as Vector2) + server.font_get_glyph_offset(rid, glyph_size, index)
			layer.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(at.round()))
		pen += float(glyph.advance)
	server.free_rid(line)
	return [layer, box]


# --- the stickers ---

## The glass's own triangles (`glass`: [mesh, its car-space transform] each) under the parts that go on the glass, a hair outside it, as
## one mesh in car space: the names on either rear side window, the number on the rear window. A triangle's picture is its part's
## (CUSTOM0: the part's corners in the picture), so the rest of the glass stays clear.
static func sticker_mesh(glass: Array[Array]) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for pane: Array in glass:
		var faces := (pane[0] as Mesh).get_faces()
		var to_car: Transform3D = pane[1]
		for f in range(0, faces.size(), 3):
			var corners: Array[Vector3] = [to_car * faces[f], to_car * faces[f + 1], to_car * faces[f + 2]]
			var middle := (corners[0] + corners[1] + corners[2]) / 3.0
			var names := absf(middle.x) > SIDE_GLASS_OUT and middle.z > SIDE_GLASS_ALONG.x and middle.z < SIDE_GLASS_ALONG.y
			if not names and middle.z <= REAR_GLASS_BEHIND:
				continue
			var out := Vector3(signf(middle.x), 0.0, 0.0) if names else Vector3.BACK
			var part := NAMES if names else REAR
			var normal := (corners[1] - corners[0]).cross(corners[2] - corners[0]).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
				corners.reverse()
			var box := _box(part)
			var uv := _uv(part)
			for corner in corners:
				# Read from outside: on the left flank front to back, on the right back to front; on the rear window left to right.
				var across := (corner.z - box.x) / (box.z - box.x) if names else (corner.x - box.x) / (box.z - box.x)
				if names and out.x > 0.0:
					across = 1.0 - across
				var down := (box.w - corner.y) / (box.w - box.y)
				tool.set_custom(0, Color(uv.x, uv.y, uv.z, uv.w))
				tool.set_normal(normal)
				tool.set_uv(Vector2(lerpf(uv.x, uv.z, across), lerpf(uv.y, uv.w, down)))
				tool.add_vertex(corner + normal * VINYL_LIFT)
	return tool.commit()


# --- the mud flaps ---

## A flap behind each wheel (car space): a slab hanging under the body, its back printed (FLAP_PRINT), its material for CarDirt.
static func flap_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flap in FLAPS:
		var span: Vector2 = flap.x
		var height: Vector2 = flap.y
		for side: float in [-1.0, 1.0]:
			var x := Vector2(span.x * side, span.y * side) if side > 0.0 else Vector2(span.y * side, span.x * side)
			_slab(tool, Vector3(x.x, height.y, float(flap.z) - FLAP_THICKNESS * 0.5), Vector3(x.y, height.x, float(flap.z) + FLAP_THICKNESS * 0.5))
	tool.generate_normals()
	tool.generate_tangents()
	var material := StandardMaterial3D.new()
	material.resource_name = CarDirt.FLAPS
	material.albedo_texture = flap_print()
	material.roughness = 0.88
	tool.set_material(material)
	return tool.commit()


## A box from `low` to `high` (car space), its back (+Z) showing the whole print, every other face its black edge.
static func _slab(tool: SurfaceTool, low: Vector3, high: Vector3) -> void:
	var printed: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var edge: Array[Vector2] = [Vector2(0.02, 0.02), Vector2(0.02, 0.02), Vector2(0.02, 0.02), Vector2(0.02, 0.02)]
	var faces := [
		[Vector3(low.x, high.y, high.z), Vector3(high.x, high.y, high.z), Vector3(high.x, low.y, high.z), Vector3(low.x, low.y, high.z)],
		[Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z), Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z)],
		[Vector3(low.x, high.y, low.z), Vector3(low.x, high.y, high.z), Vector3(low.x, low.y, high.z), Vector3(low.x, low.y, low.z)],
		[Vector3(high.x, high.y, high.z), Vector3(high.x, high.y, low.z), Vector3(high.x, low.y, low.z), Vector3(high.x, low.y, high.z)],
		[Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z), Vector3(high.x, low.y, low.z), Vector3(low.x, low.y, low.z)],
	]
	for f in faces.size():
		var quad: Array = faces[f]
		var uvs := printed if f == 0 else edge
		for i: int in [0, 1, 2, 0, 2, 3]:
			tool.set_uv(uvs[i])
			tool.add_vertex(quad[i])


## The flaps' print, the same on every car: black rubber, the game's name across its lower part in white.
static func flap_print() -> ImageTexture:
	if _flap_print == null:
		var image := Image.create(FLAP_PRINT.x, FLAP_PRINT.y, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.03, 0.03, 0.032))
		_print(image, TranslationServer.translate("GAME_TITLE"), UiTheme.hud_font(800, 100),
			Rect2i(10, FLAP_PRINT.y * 58 / 100, FLAP_PRINT.x - 20, FLAP_PRINT.y * 28 / 100))
		image.generate_mipmaps()
		_flap_print = ImageTexture.create_from_image(image)
	return _flap_print
