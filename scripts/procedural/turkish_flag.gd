class_name TurkishFlag
## The flag of Turkey, the only flag in the game, by the geometry of its law, drawn in code so nothing
## is shipped. All in units of the flag's height G: x from the hoist along the centre line, y across
## it. The crescent is a circle cut by a smaller one, the star points at the hoist, and the length is
## 1.5 G. color_at() says what lies at a point, image() paints a whole flag from it.

const RED := Color("E30A17")
const WHITE := Color.WHITE
const LENGTH := 1.5
const CRESCENT_X := 0.5
const CRESCENT_RADIUS := 0.25
const CUT_X := 0.5625
const CUT_RADIUS := 0.2
const STAR_X := 0.8208
const STAR_RADIUS := 0.125
## A regular five-pointed star's waist over its radius, and its first fold (36 degrees).
const STAR_WAIST := 0.381966
const STAR_FOLD := Vector2(0.809017, -0.587785)
## Height of the image everything in the world uses: stays crisp from a flag's length away.
const TEXTURE_HEIGHT := 512

static var _texture: ImageTexture


## The signed distance from `p` to the white figure, negative inside.
static func figure_distance(p: Vector2) -> float:
	var crescent := maxf(p.distance_to(Vector2(CRESCENT_X, 0.0)) - CRESCENT_RADIUS, CUT_RADIUS - p.distance_to(Vector2(CUT_X, 0.0)))
	return minf(crescent, _star_distance(p - Vector2(STAR_X, 0.0)))


## The colour at `p`, with an edge `pixel` wide blending the two.
static func color_at(p: Vector2, pixel := 0.001) -> Color:
	return RED.lerp(WHITE, clampf(0.5 - figure_distance(p) / pixel, 0.0, 1.0))


## A whole flag `height` pixels high, its hoist on the left. Only the figure's box is worked out, one half
## of it, since the flag is the same above and below its centre line.
static func image(height: int) -> Image:
	var flag := Image.create(roundi(height * LENGTH), height, false, Image.FORMAT_RGB8)
	flag.fill(RED)
	var pixel := 1.0 / height
	var left := floori((CRESCENT_X - CRESCENT_RADIUS) * height) - 1
	var right := ceili((STAR_X + STAR_RADIUS) * height) + 1
	var top := floori((0.5 - CRESCENT_RADIUS) * height) - 1
	for y in range(top, height / 2):
		var mirrored := height - 1 - y
		for x in range(left, right):
			var color := color_at(Vector2(x + 0.5, y + 0.5 - height * 0.5) * pixel, pixel)
			if color != RED:
				flag.set_pixel(x, y, color)
				flag.set_pixel(x, mirrored, color)
	return flag


## The flag on every cloth, made once.
static func texture() -> ImageTexture:
	if _texture == null:
		var flag := image(TEXTURE_HEIGHT)
		flag.generate_mipmaps()
		_texture = ImageTexture.create_from_image(flag)
	return _texture


## The signed distance from a star round the origin with one point along -x: folded into the wedge
## of one point, then the distance to the point's edge.
static func _star_distance(p: Vector2) -> float:
	var q := Vector2(absf(p.y), -p.x)
	var fold_b := Vector2(-STAR_FOLD.x, STAR_FOLD.y)
	q -= STAR_FOLD * 2.0 * maxf(STAR_FOLD.dot(q), 0.0)
	q -= fold_b * 2.0 * maxf(fold_b.dot(q), 0.0)
	q.x = absf(q.x)
	q.y -= STAR_RADIUS
	var edge := Vector2(-STAR_FOLD.y, STAR_FOLD.x) * STAR_WAIST - Vector2(0.0, 1.0)
	var along := clampf(q.dot(edge) / edge.dot(edge), 0.0, STAR_RADIUS)
	return (q - edge * along).length() * signf(q.y * edge.x - q.x * edge.y)
