class_name CrewHelmet
## An open-face rally helmet built in code, in the head bone's space of the crew's mannequin (y up, z ahead, x to its left): the one place
## a downloaded model would replace (`mesh()`). The shell in the team colour under a gloss clear coat (shaders/crew_helmet.gdshader: a
## white stripe over the top, a small flag of Turkey and the wearer's name on either side, what the coat mirrors of the cabin and of the
## sky through its windows), a tall crown, the nape tucked in under the head, the lower edge flared, the ear cups' bulges, two intakes over
## the brow and two exhausts behind; a rubber trim round every edge with the black liner and cheek pads inside it. The face open, in a
## black fireproof balaclava with a slot for the eyes (the shader's skin and eyes in it, dark under the brow but for a glint); an
## intercom's boom microphone from the left cheek to in front of the mouth, its cable from the back down to the HANS collar; a chin strap;
## the HANS device's posts on either side, their tethers down to its collar. No peak: the crew sits under a cage. One surface, one draw
## call. The tethers and the cable end on the hips (`skin`), which hold still in the seat as the HANS collar does, so they stay on it
## however the head turns; all the rest rides the head.

const SHADER := preload("res://shaders/crew_helmet.gdshader")
## What a part is to the shader: the shell (painted, lettered), plain (as its colour says), the liner, the balaclava over the face (the
## eye slot and the eyes in it), webbing, the microphone's foam.
enum Kind { SHELL, PLAIN, LINER, FACE, WEBBING, FOAM }
## What each part is made of: base colour (linear; alpha 1 where the team colour goes), metallic, roughness, clear coat, kind.
const PAINTED := [Color(1.0, 1.0, 1.0, 1.0), 0.0, 0.32, 1.0, Kind.SHELL]
const RUBBER := [Color(0.016, 0.016, 0.018, 0.0), 0.0, 0.5, 0.0, Kind.PLAIN]
const LINER := [Color(0.022, 0.022, 0.024, 0.0), 0.0, 0.95, 0.0, Kind.LINER]
const BALACLAVA := [Color(0.022, 0.022, 0.024, 0.0), 0.0, 0.9, 0.0, Kind.FACE]
const PLASTIC := [Color(0.012, 0.012, 0.014, 0.0), 0.0, 0.3, 0.6, Kind.PLAIN]
const MOUTH := [Color(0.003, 0.003, 0.004, 0.0), 0.0, 0.85, 0.0, Kind.PLAIN]
const ANODISED := [Color(0.3, 0.31, 0.33, 0.0), 1.0, 0.32, 0.0, Kind.PLAIN]
const WEBBING := [Color(0.014, 0.014, 0.016, 0.0), 0.0, 0.7, 0.0, Kind.WEBBING]
const CABLE := [Color(0.02, 0.02, 0.022, 0.0), 0.0, 0.42, 0.0, Kind.PLAIN]
const FOAM := [Color(0.012, 0.012, 0.013, 0.0), 0.0, 1.0, 0.0, Kind.FOAM]

## The shell, round its middle: half its size across, up, down, ahead and behind (the mannequin's head inside with about 3.5 cm for the
## liner all round); it narrows towards the brow by NARROW, its nape tucks in under the head by TUCK and its lower edge flares out
## (FLARE: how far, over how far up from the edge).
const MIDDLE := Vector3(0.0, 0.11, -0.012)
const HALF_ACROSS := 0.118
const HALF_UP := 0.186
const HALF_DOWN := 0.215
const HALF_AHEAD := 0.155
const HALF_BEHIND := 0.139
const NARROW := 0.1
const TUCK := 0.03
const FLARE := Vector2(0.003, 0.014)
## The ear cups' bulges on either side: their middle (up, ahead), radius and rise.
const EAR := Vector3(0.075, -0.005, 0.045)
const EAR_RISE := 0.004
## How low the shell comes (m up): behind, at the sides, ahead of them.
const RIM := Vector3(0.0, -0.03, -0.035)
## The face opening as seen from ahead: half its width, its middle's height and half its height (it reaches below the edge, so the face is
## open down to the chin), how square its corners are; the cheeks close in on the jaw, the opening half as wide as OPENING_JAW at the chin
## (JAW: from this high down to this); where it meets the lower edge the cheek's corner is rounded this much (m).
const OPENING := Vector3(0.078, 0.03, 0.145)
const OPENING_SQUARE := 4.0
const OPENING_JAW := 0.056
const JAW := Vector2(0.09, -0.02)
const CORNER := 0.012
## The grid round the shell (degrees) from its lowest ring up to the crown; the edge is cut out of it.
const STEP_AROUND := 3.0
const STEP_UP := 2.5
const LOWEST := -60.0
## The rubber trim round every edge: its radius and how far into the shell its middle lies; the liner inside it: how far in the pad's roll
## is and how far it stands into the opening, how deep the liner goes at the face and at the lower edge (towards the neck); the trim's
## points apart along the edge (m).
const TRIM := Vector2(0.0042, 0.0026)
const PAD := Vector2(0.012, 0.003)
const LINER_DEPTH := Vector2(0.046, 0.065)
const EDGE_STEP := 0.004
## The vents: where each middle is (degrees round from ahead, up), its length, width and height (m), mirrored either side of the stripe:
## two intakes over the brow, two exhausts behind.
const VENTS := [[23.0, 50.0, Vector3(0.042, 0.015, 0.006)], [161.0, 22.0, Vector3(0.034, 0.012, 0.005)]]

## The balaclava over the face: the mannequin's face, which it hides, as a height field (z over x and y: its back, depth and half width;
## the height it bulges most at, and up and down from there how far and how squarely it falls away; its half width at the chin, narrowing
## as the opening does), the fabric's thickness off it, and where the eyes are (across, up).
const FIT := Vector3(-0.035, 0.142, 0.091)
const FIT_MIDDLE := 0.1
const FIT_UP := Vector2(0.155, 4.0)
const FIT_DOWN := Vector2(0.1294, 6.0)
const FIT_JAW := 0.064
const FABRIC := 0.004
const EYE := Vector2(0.032, 0.134)
const FACE_STEP := 0.0032
const FACE_SPAN := Rect2(-0.084, -0.04, 0.168, 0.226)

## The intercom: the boom's mount on the left cheek (a way out from the shell's middle), the foam capsule's middle in front of the mouth,
## the boom's and the capsule's radius, the capsule's half length.
const MIC_MOUNT := Vector3(0.105, 0.02, 0.06)
const MIC_TIP := Vector3(0.0, 0.03, 0.136)
const MIC_BOOM := 0.0024
const MIC_FOAM := Vector2(0.0085, 0.012)
## The cable: from under the shell's edge behind on the left (degrees round) down to its plug on the HANS collar.
const CABLE_FROM := 148.0
const CABLE_TO := Vector3(0.088, -0.092, -0.15)
## The HANS device's posts on either side behind the ear (degrees round, m up) and the tethers' lower ends on its collar (the left one; the
## right is its mirror), as the crew member sits; the webbing's width.
const POST := Vector2(106.0, 0.02)
const TETHER_LOW := Vector3(0.06, -0.064, -0.152)
const TETHER_WIDTH := 0.02

static var _mesh: ArrayMesh


## The helmet's mesh, the same for every crew member (the team colour and the name are its material's, the bones its skin's).
static func mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		_edge(tool, _shell(tool))
		_face(tool)
		for vent: Array in VENTS:
			for side: float in [1.0, -1.0]:
				_vent(tool, Vector2(vent[0] * side, vent[1]), vent[2])
		_microphone(tool)
		_chin_strap(tool)
		for side: float in [1.0, -1.0]:
			_tether(tool, side)
		_cable(tool)
		tool.index()
		_mesh = CrewBody.thinned(tool.commit_to_arrays())
	return _mesh


## The helmet's material in `paint`: its name and flag are set on it (CrewBody.wear_name).
static func material(paint: Color) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter(&"paint", paint)
	out.set_shader_parameter(&"flag", TurkishFlag.texture())
	return out


## How a body's skeleton carries the helmet (its MeshInstance3D's skin): the helmet rides the head; the tethers' and the cable's lower ends
## ride the hips, which hold still in the seat as the HANS collar does, from where they are as the body sits (`pose`).
static func skin(pose: CrewPose) -> Skin:
	var out := Skin.new()
	out.add_named_bind(CrewPose.HEAD, Transform3D.IDENTITY)
	out.add_named_bind(CrewPose.HIPS, pose.global_of(CrewPose.HIPS).affine_inverse() * pose.global_of(CrewPose.HEAD))
	return out


## The shell's outside `around` degrees round from straight ahead (towards its left) and `up` degrees over its middle.
static func shell_point(around: float, up: float) -> Vector3:
	var a := deg_to_rad(around)
	var e := deg_to_rad(up)
	var way := Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e))
	var half := Vector3(HALF_ACROSS, HALF_UP if way.y > 0.0 else HALF_DOWN, HALF_AHEAD if way.z > 0.0 else HALF_BEHIND)
	var at := way / Vector3(way.x / half.x, way.y / half.y, way.z / half.z).length()
	at.x *= 1.0 - NARROW * smoothstep(0.0, HALF_AHEAD, at.z)
	at.z *= 1.0 - TUCK * smoothstep(0.0, HALF_DOWN * 0.45, -at.y) * smoothstep(0.0, 0.06, -at.z)
	at += MIDDLE
	var ear := Vector2(at.y - EAR.x, at.z - EAR.y).length() / EAR.z
	if ear < 1.0:
		at.x += signf(at.x) * EAR_RISE * pow(1.0 - ear * ear, 2.0) * smoothstep(0.05, 0.09, absf(at.x))
	var above := at.y - _rim(at)
	if above < FLARE.y:
		var out := Vector3(at.x, 0.0, at.z - MIDDLE.z).normalized()
		at += out * FLARE.x * pow(1.0 - maxf(above, 0.0) / FLARE.y, 2.0)
	return at


## The shell's outward normal at a place on its grid (around, up).
static func _shell_normal(place: Vector2) -> Vector3:
	var up := minf(place.y, 89.0)
	var d := 0.2
	var along := shell_point(place.x + d, up) - shell_point(place.x - d, up)
	var rising := shell_point(place.x, up + d) - shell_point(place.x, up - d)
	var normal := along.cross(rising).normalized()
	return normal if normal.dot(shell_point(place.x, up) - MIDDLE) > 0.0 else -normal


## Where on the grid (around, up) the shell is `height` m up at `around` degrees round.
static func _place_at(around: float, height: float) -> Vector2:
	var low := LOWEST
	var high := 89.0
	for i in 30:
		var middle := (low + high) * 0.5
		if shell_point(around, middle).y < height:
			low = middle
		else:
			high = middle
	return Vector2(around, (low + high) * 0.5)


## How low the shell comes where `at` is, round its middle.
static func _rim(at: Vector3) -> float:
	var ahead := cos(atan2(at.x, at.z - MIDDLE.z))
	return RIM.y + (RIM.x - RIM.y if ahead < 0.0 else RIM.z - RIM.y) * ahead * ahead


## How far `at` is inside the shell's edges (m, about; below 0 it is cut away): over its lower edge and outside the face's opening, the
## cheek's corner rounded where the two meet.
static func presence(at: Vector3) -> float:
	var edges := _edges(at)
	var h := maxf(CORNER - absf(edges.x - edges.y), 0.0) / CORNER
	return minf(edges.x, edges.y) - h * h * CORNER * 0.25


## How far `at` is over the lower edge and outside the face's opening (m, about).
static func _edges(at: Vector3) -> Vector2:
	var opening := 1.0
	if at.z > 0.0:
		var half := lerpf(OPENING.x, OPENING_JAW, smoothstep(JAW.x, JAW.y, at.y))
		var reach := pow(absf(at.x) / half, OPENING_SQUARE) + pow(absf(at.y - OPENING.y) / OPENING.z, OPENING_SQUARE)
		opening = (pow(reach, 1.0 / OPENING_SQUARE) - 1.0) * half
	return Vector2(at.y - _rim(at), opening)


## How much the edge at `at` is the lower edge rather than the face's opening (0 to 1).
static func _lowness(at: Vector3) -> float:
	var edges := _edges(at)
	return smoothstep(-CORNER, CORNER, edges.y - edges.x)


## The shell's outside on its grid, each triangle clipped where the edge crosses it (the crossing found on the shell itself, the same for
## the two triangles that share it). Returns the edge, a closed line of grid places (around, up) EDGE_STEP apart.
static func _shell(tool: SurfaceTool) -> Array[Vector2]:
	var steps := roundi(360.0 / STEP_AROUND)
	var rings := roundi((90.0 - LOWEST) / STEP_UP)
	var values := PackedFloat32Array()
	var normals: Array[Vector3] = []
	for i in steps:
		for j in rings + 1:
			var place := Vector2(-180.0 + i * STEP_AROUND, LOWEST + j * STEP_UP)
			values.append(presence(shell_point(place.x, place.y)))
			normals.append(_shell_normal(place))
	var crossings := {}  # grid edge -> the place on it where the edge crosses
	var links := {}  # grid edge -> the grid edges its crossing joins along the shell's edge
	for i in steps:
		for j in rings:
			var corners: Array[Vector2i] = [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
				var kept: Array[Vector2] = []
				var kept_normals: Array[Vector3] = []
				var cut: Array[int] = []
				for k in 3:
					var a: Vector2i = corners[triangle[k]]
					var b: Vector2i = corners[triangle[(k + 1) % 3]]
					var index_a := (a.x % steps) * (rings + 1) + a.y
					var index_b := (b.x % steps) * (rings + 1) + b.y
					if values[index_a] > 0.0:
						kept.append(Vector2(-180.0 + a.x * STEP_AROUND, LOWEST + a.y * STEP_UP))
						kept_normals.append(normals[index_a])
					if (values[index_a] > 0.0) != (values[index_b] > 0.0):
						var key := mini(index_a, index_b) * 100000 + maxi(index_a, index_b)
						if not crossings.has(key):
							var inside := a if values[index_a] > 0.0 else b
							var outside := b if inside == a else a
							crossings[key] = _crossing(Vector2(-180.0 + inside.x * STEP_AROUND, LOWEST + inside.y * STEP_UP),
								Vector2(-180.0 + outside.x * STEP_AROUND, LOWEST + outside.y * STEP_UP))
						kept.append(crossings[key])
						kept_normals.append(_shell_normal(crossings[key]))
						cut.append(key)
				if cut.size() == 2:
					links[cut[0]] = links.get(cut[0], []) + [cut[1]]
					links[cut[1]] = links.get(cut[1], []) + [cut[0]]
				for k in range(1, kept.size() - 1):
					var points: Array[Vector3] = [shell_point(kept[0].x, kept[0].y), shell_point(kept[k].x, kept[k].y),
						shell_point(kept[k + 1].x, kept[k + 1].y)]
					if (points[1] - points[0]).cross(points[2] - points[0]).length() > 1e-10:
						_triangle(tool, points, [kept_normals[0], kept_normals[k], kept_normals[k + 1]], PAINTED)
	return _resampled(_longest_loop(links, crossings))


## Where the edge crosses from `inside` to `outside` (grid places), found on the shell.
static func _crossing(inside: Vector2, outside: Vector2) -> Vector2:
	var low := 0.0
	var high := 1.0
	for i in 24:
		var middle := (low + high) * 0.5
		var place := inside.lerp(outside, middle)
		if presence(shell_point(place.x, place.y)) > 0.0:
			low = middle
		else:
			high = middle
	return inside.lerp(outside, (low + high) * 0.5)


## The longest closed line through the crossings, from one to the next along the shell's edge (grid places, round kept continuous).
static func _longest_loop(links: Dictionary, crossings: Dictionary) -> Array[Vector2]:
	var seen := {}
	var longest: Array[Vector2] = []
	for start: int in links:
		if seen.has(start):
			continue
		var loop: Array[Vector2] = []
		var previous := -1
		var at := start
		while not seen.has(at):
			seen[at] = true
			var place: Vector2 = crossings[at]
			if not loop.is_empty():
				place.x += 360.0 * roundf((loop[-1].x - place.x) / 360.0)
			loop.append(place)
			var next := -1
			for other: int in links[at]:
				if other != previous and not seen.has(other):
					next = other
					break
			if next < 0:
				break
			previous = at
			at = next
		if loop.size() > longest.size():
			longest = loop
	return longest


## A closed line of grid places as places EDGE_STEP apart along the shell.
static func _resampled(loop: Array[Vector2]) -> Array[Vector2]:
	var points: Array[Vector3] = []
	for place in loop:
		points.append(shell_point(place.x, place.y))
	var total := 0.0
	var walked := PackedFloat32Array([0.0])
	for i in loop.size():
		total += points[i].distance_to(points[(i + 1) % loop.size()])
		walked.append(total)
	var count := roundi(total / EDGE_STEP)
	var out: Array[Vector2] = []
	var i := 0
	for k in count:
		var distance := total * k / count
		while walked[i + 1] < distance:
			i += 1
		var t := (distance - walked[i]) / maxf(walked[i + 1] - walked[i], 1e-9)
		var next := loop[(i + 1) % loop.size()]
		next.x += 360.0 * roundf((loop[i].x - next.x) / 360.0)
		out.append(loop[i].lerp(next, t))
	return out


## Round every edge of the shell: the rubber trim over it and the liner going in from under it, a pad rolled at its lip, to the face behind
## the opening and to the neck under the lower edge.
static func _edge(tool: SurfaceTool, loop: Array[Vector2]) -> void:
	var count := loop.size()
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for place in loop:
		points.append(shell_point(place.x, place.y))
		normals.append(_shell_normal(place))
	var rings: Array[Array] = []
	for k in count:
		var at := points[k]
		var normal := normals[k]
		var along := (points[(k + 1) % count] - points[(k + count - 1) % count]).normalized()
		var out := normal.cross(along).normalized()
		if presence(at + out * 0.002) > presence(at - out * 0.002):
			out = -out
		# The liner goes in towards the face from the opening, towards the neck from the lower edge.
		var low := _lowness(at)
		var to_neck := -Vector3(at.x, 0.0, at.z - MIDDLE.z).normalized()
		var inward := (-normal).lerp(to_neck, low).normalized()
		var deep := at + inward * lerpf(LINER_DEPTH.x, LINER_DEPTH.y, low)
		var trim := at - normal * TRIM.y
		var ring: Array[Vector3] = []
		var ring_normals: Array[Vector3] = []
		for side in 10:
			var angle := TAU * side / 10.0
			var way := out * cos(angle) + normal * sin(angle)
			ring.append(trim + way * TRIM.x)
			ring_normals.append(way)
		var pad := at - normal * PAD.x + out * PAD.y
		var under := trim - normal * TRIM.x * 0.7
		ring.append_array([under, pad, deep])
		ring_normals.append_array([out, (out - normal * 0.3).normalized(), (out + inward * 0.2).normalized()])
		rings.append([ring, ring_normals])
	for k in count:
		var a: Array = rings[k]
		var b: Array = rings[(k + 1) % count]
		for side in 10:
			var next := (side + 1) % 10
			_quad(tool, [a[0][side], b[0][side], b[0][next], a[0][next]], [a[1][side], b[1][side], b[1][next], a[1][next]], RUBBER)
		# Under the trim, the pad's roll, deep in: how deep each lies.
		var depths := [0.0, 0.4, 1.0]
		for step in 2:
			var s := 10 + step
			_quad(tool, [a[0][s], b[0][s], b[0][s + 1], a[0][s + 1]], [a[1][s], b[1][s], b[1][s + 1], a[1][s + 1]], LINER, [0.0, 0.0, 0.0, 0.0],
				[depths[step], depths[step], depths[step + 1], depths[step + 1]])


## The balaclava over the face where the opening shows it (and behind the pads, where it does not).
static func _face(tool: SurfaceTool) -> void:
	var columns := roundi(FACE_SPAN.size.x / FACE_STEP)
	var rows := roundi(FACE_SPAN.size.y / FACE_STEP)
	var grid: Array[Vector3] = []
	var grid_normals: Array[Vector3] = []
	for i in columns + 1:
		for j in rows + 1:
			var x := FACE_SPAN.position.x + FACE_SPAN.size.x * i / columns
			var y := FACE_SPAN.position.y + FACE_SPAN.size.y * j / rows
			grid.append(face_point(x, y))
			var d := FACE_STEP * 0.5
			var across := face_point(x + d, y) - face_point(x - d, y)
			var up := face_point(x, y + d) - face_point(x, y - d)
			grid_normals.append(across.cross(up).normalized())
	for i in columns:
		for j in rows:
			var corners: Array[int] = [i * (rows + 1) + j, (i + 1) * (rows + 1) + j, (i + 1) * (rows + 1) + j + 1, i * (rows + 1) + j + 1]
			_quad(tool, [grid[corners[0]], grid[corners[1]], grid[corners[2]], grid[corners[3]]],
				[grid_normals[corners[0]], grid_normals[corners[1]], grid_normals[corners[2]], grid_normals[corners[3]]], BALACLAVA)


## The balaclava's surface over the face at `x` across and `y` up: the mannequin's face, the fabric off it, and under the fabric the brow,
## the nose, the cheeks, the lips, the chin, the eyes.
static func face_point(x: float, y: float) -> Vector3:
	var from_middle := y - FIT_MIDDLE
	var falling := pow(from_middle / FIT_UP.x, FIT_UP.y) if from_middle > 0.0 else pow(-from_middle / FIT_DOWN.x, FIT_DOWN.y)
	var half := lerpf(FIT.z, FIT_JAW, smoothstep(JAW.x, JAW.y, y))
	var fit := FIT.x + FIT.y * sqrt(maxf(1.0 - pow(x / half, 2.0) - falling, 0.0))
	return Vector3(x, y, fit + FABRIC + _relief(x, y))


## The shapes under the balaclava (m out from the face).
static func _relief(x: float, y: float) -> float:
	var side := absf(x)
	var down_nose := clampf((0.135 - y) / 0.072, 0.0, 1.0)
	var nose_width := lerpf(0.0065, 0.011, down_nose)
	var nose := lerpf(0.004, 0.019, pow(down_nose, 1.6)) * smoothstep(0.044, 0.064, y) * smoothstep(0.158, 0.14, y) \
		* exp(-x * x / (2.0 * nose_width * nose_width))
	var wings := 0.006 * exp(-(pow(side - 0.013, 2.0) / (2.0 * 0.0045 * 0.0045) + pow(y - 0.058, 2.0) / (2.0 * 0.006 * 0.006)))
	var brow := 0.006 * exp(-pow(y - 0.157, 2.0) / (2.0 * 0.0075 * 0.0075)) * smoothstep(0.075, 0.03, side)
	var cheeks := 0.006 * exp(-(pow(side - 0.045, 2.0) + pow(y - 0.098, 2.0)) / (2.0 * 0.014 * 0.014))
	var lips := 0.0035 * exp(-(pow(y - 0.03, 2.0) / (2.0 * 0.0045 * 0.0045) + x * x / (2.0 * 0.018 * 0.018)))
	var chin := 0.005 * exp(-(pow(y - 0.004, 2.0) / (2.0 * 0.011 * 0.011) + x * x / (2.0 * 0.017 * 0.017)))
	var eye := 0.0018 * maxf(1.0 - pow((side - EYE.x) / 0.012, 2.0) - pow((y - EYE.y) / 0.007, 2.0), 0.0)
	return nose + wings + brow + cheeks + lips + chin + eye


## A vent on the shell round `place` (around, up), `size` long (up the shell), wide and high: a scoop rising from its back to its open
## mouth, which faces down the shell (ahead over the brow, back behind).
static func _vent(tool: SurfaceTool, place: Vector2, size: Vector3) -> void:
	var middle := shell_point(place.x, place.y)
	var metres := Vector2((shell_point(place.x + 1.0, place.y) - middle).length(), (shell_point(place.x, place.y + 1.0) - middle).length())
	var span := Vector2(size.y * 0.5 / metres.x, size.x * 0.5 / metres.y)
	var columns := 8
	var rows := 10
	var grid: Array[Vector3] = []
	var lift := func(u: float, v: float) -> float:
		return size.z * (1.0 - pow(absf(v), 4.0)) * smoothstep(1.0, -0.6, u)
	for i in columns + 1:
		for j in rows + 1:
			var v := -1.0 + 2.0 * i / columns
			var u := -0.85 + 1.85 * j / rows
			var place_here := place + Vector2(v * span.x, u * span.y)
			grid.append(shell_point(place_here.x, place_here.y) + _shell_normal(place_here) * (lift.call(u, v) as float))
	var tool_normals: Array[Vector3] = []
	for i in columns + 1:
		for j in rows + 1:
			var at := grid[i * (rows + 1) + j]
			var across := grid[mini(i + 1, columns) * (rows + 1) + j] - grid[maxi(i - 1, 0) * (rows + 1) + j]
			var up := grid[i * (rows + 1) + mini(j + 1, rows)] - grid[i * (rows + 1) + maxi(j - 1, 0)]
			var normal := across.cross(up).normalized()
			tool_normals.append(normal if normal.dot(at - MIDDLE) > 0.0 else -normal)
	for i in columns:
		for j in rows:
			var c: Array[int] = [i * (rows + 1) + j, (i + 1) * (rows + 1) + j, (i + 1) * (rows + 1) + j + 1, i * (rows + 1) + j + 1]
			_quad(tool, [grid[c[0]], grid[c[1]], grid[c[2]], grid[c[3]]], [tool_normals[c[0]], tool_normals[c[1]], tool_normals[c[2]],
				tool_normals[c[3]]], PLASTIC)
	# The mouth: from the scoop's lip down to the shell.
	var mouth_way := (shell_point(place.x, place.y - span.y) - shell_point(place.x, place.y + span.y)).normalized()
	for i in columns:
		var a := place + Vector2((-1.0 + 2.0 * i / columns) * span.x, -0.85 * span.y)
		var b := place + Vector2((-1.0 + 2.0 * (i + 1) / columns) * span.x, -0.85 * span.y)
		_quad(tool, [grid[i * (rows + 1)], grid[(i + 1) * (rows + 1)], shell_point(b.x, b.y) + _shell_normal(b) * 0.0005,
			shell_point(a.x, a.y) + _shell_normal(a) * 0.0005], [mouth_way, mouth_way, mouth_way, mouth_way], MOUTH)


## The intercom's boom microphone: its mount on the left cheek, the boom forward round the cheek, the foam capsule in front of the mouth.
static func _microphone(tool: SurfaceTool) -> void:
	var way := MIC_MOUNT - MIDDLE
	var place := _place_at(rad_to_deg(atan2(way.x, way.z)), MIC_MOUNT.y)
	var mount := shell_point(place.x, place.y)
	var normal := _shell_normal(place)
	var ahead := (shell_point(place.x - 2.0, place.y) - shell_point(place.x + 2.0, place.y)).normalized()
	var frame := Basis(ahead.cross(normal).normalized(), normal, ahead)
	_box(tool, Transform3D(frame, mount + normal * 0.004), Vector3(0.012, 0.009, 0.018), PLASTIC)
	var path := _curve([mount + normal * 0.006 + ahead * 0.008, mount + normal * 0.012 + ahead * 0.03, Vector3(0.07, 0.025, 0.122),
		Vector3(0.035, 0.029, 0.134), MIC_TIP + Vector3(MIC_FOAM.y, 0.0, 0.0)], 6)
	_tube(tool, path, MIC_BOOM, CABLE, PackedFloat32Array())
	_capsule(tool, MIC_TIP, Vector3.RIGHT, MIC_FOAM.x, MIC_FOAM.y, FOAM)


## The chin strap: from inside each cheek's lower edge under the chin, buckled on the left.
static func _chin_strap(tool: SurfaceTool) -> void:
	var points: Array[Vector3] = []
	for side: float in [1.0, -1.0]:
		var place := _place_at(66.0 * side, RIM.z + 0.008)
		var start := shell_point(place.x, place.y) - _shell_normal(place) * 0.006
		var half: Array[Vector3] = [start, Vector3(0.074 * side, -0.036, 0.032), Vector3(0.04 * side, -0.046, 0.047), Vector3(0.0, -0.048, 0.051)]
		if side < 0.0:
			half.reverse()
			half.remove_at(0)
		points.append_array(half)
	var path := _curve(points, 4)
	var faces: Array[Vector3] = []
	for point in path:
		faces.append(Vector3(point.x, point.y + 0.02, point.z - 0.01).normalized())
	_webbing(tool, path, faces, 0.016, WEBBING, PackedFloat32Array())
	_box(tool, Transform3D(Basis(Vector3.UP, 0.9), Vector3(0.062, -0.042, 0.041)), Vector3(0.01, 0.005, 0.016), RUBBER)


## The HANS post on `side` (1 the left, -1 the right) and its tether down to the collar.
static func _tether(tool: SurfaceTool, side: float) -> void:
	var place := _place_at(POST.x * side, POST.y)
	var at := shell_point(place.x, place.y)
	var normal := _shell_normal(place)
	var frame := Basis(normal.cross(Vector3.UP).normalized(), normal, normal.cross(normal.cross(Vector3.UP)).normalized())
	_cylinder(tool, Transform3D(frame, at + normal * 0.0015), 0.011, 0.003, PLASTIC, true)
	_cylinder(tool, Transform3D(frame, at + normal * 0.007), 0.0055, 0.009, ANODISED, false)
	_cylinder(tool, Transform3D(frame, at + normal * 0.0125), 0.0075, 0.0025, ANODISED, true)
	var low := Vector3(TETHER_LOW.x * side, TETHER_LOW.y, TETHER_LOW.z)
	var off := _place_at(place.x + 24.0 * side, RIM.y + 0.006)
	var points: Array[Vector3] = [at + normal * 0.008, shell_point(off.x, off.y) + _shell_normal(off) * 0.006, low]
	var path := _curve([points[0], points[0].lerp(points[1], 0.5) + normal * 0.004, points[1], points[1].lerp(low, 0.5), low], 4)
	var follows := PackedFloat32Array()
	var faces: Array[Vector3] = []
	for k in path.size():
		follows.append(smoothstep(0.45, 1.0, float(k) / (path.size() - 1)))
		faces.append(Vector3(path[k].x, 0.0, path[k].z - MIDDLE.z * 0.5).normalized())
	_webbing(tool, path, faces, TETHER_WIDTH, WEBBING, follows)


## The intercom's cable from under the shell's edge behind on the left, down to its plug on the HANS collar.
static func _cable(tool: SurfaceTool) -> void:
	var place := _place_at(CABLE_FROM, RIM.x + 0.004)
	var at := shell_point(place.x, place.y)
	var normal := _shell_normal(place)
	var path := _curve([at - normal * 0.012 + Vector3.UP * 0.01, at - normal * 0.004 + Vector3.DOWN * 0.012, at + Vector3(0.006, -0.04, -0.012),
		CABLE_TO + Vector3(0.0, 0.03, 0.0), CABLE_TO], 5)
	var follows := PackedFloat32Array()
	for k in path.size():
		follows.append(smoothstep(0.25, 0.85, float(k) / (path.size() - 1)))
	_tube(tool, path, 0.0028, CABLE, follows)
	var along := (path[-1] - path[-2]).normalized()
	var side := along.cross(Vector3.FORWARD).normalized()
	var plug := Basis(side, along, side.cross(along))
	_cylinder(tool, Transform3D(plug, CABLE_TO + along * 0.012), 0.0065, 0.026, CABLE, true, 1.0)
	_cylinder(tool, Transform3D(plug, CABLE_TO + along * 0.026), 0.0068, 0.004, ANODISED, true, 1.0)


## A smooth curve through `points`, `steps` pieces from each to the next.
static func _curve(points: Array[Vector3], steps: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in points.size() - 1:
		for step in steps:
			out.append(points[i].cubic_interpolate(points[i + 1], points[maxi(i - 1, 0)], points[mini(i + 2, points.size() - 1)], float(step) / steps))
	out.append(points[-1])
	return out


## A tube of `radius` along `path`, closed at its ends; `follows` how much of each ring the hips carry (none if empty).
static func _tube(tool: SurfaceTool, path: Array[Vector3], radius: float, part: Array, follows: PackedFloat32Array) -> void:
	var sides := 8
	var tangent := (path[1] - path[0]).normalized()
	var normal := tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
	var rings: Array[Array] = []
	for i in path.size():
		var ahead := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		normal = (normal - ahead * normal.dot(ahead)).normalized()
		var binormal := ahead.cross(normal)
		var ring: Array[Vector3] = []
		for k in sides:
			var angle := TAU * k / sides
			ring.append(normal * cos(angle) + binormal * sin(angle))
		rings.append(ring)
	for i in path.size() - 1:
		var f := [0.0, 0.0] if follows.is_empty() else [follows[i], follows[i + 1]]
		for k in sides:
			var j := (k + 1) % sides
			var ways: Array[Vector3] = [rings[i][k], rings[i + 1][k], rings[i + 1][j], rings[i][j]]
			_quad(tool, [path[i] + ways[0] * radius, path[i + 1] + ways[1] * radius, path[i + 1] + ways[2] * radius, path[i] + ways[3] * radius],
				ways, part, [f[0], f[1], f[1], f[0]])
	for end: int in [0, path.size() - 1]:
		var facing := (path[end] - path[1 if end == 0 else end - 1]).normalized()
		var f := 0.0 if follows.is_empty() else follows[end]
		for k in sides:
			_triangle(tool, [path[end], path[end] + rings[end][k] * radius, path[end] + rings[end][(k + 1) % sides] * radius],
				[facing, facing, facing], part, [f, f, f])


## Webbing `width` wide along `path`, its face towards `faces` at each point, 2 mm thick; `follows` how much the hips carry it.
static func _webbing(tool: SurfaceTool, path: Array[Vector3], faces: Array[Vector3], width: float, part: Array, follows: PackedFloat32Array) -> void:
	for i in path.size() - 1:
		var ends: Array[Array] = []
		for k: int in [i, i + 1]:
			var along := (path[mini(k + 1, path.size() - 1)] - path[maxi(k - 1, 0)]).normalized()
			var face := (faces[k] - along * faces[k].dot(along)).normalized()
			ends.append([path[k], face, along.cross(face).normalized() * width * 0.5, 0.0 if follows.is_empty() else follows[k]])
		var f: Array = [ends[0][3], ends[1][3], ends[1][3], ends[0][3]]
		for lie: float in [1.0, -1.0]:
			var a: Vector3 = ends[0][0] - ends[0][1] * (0.001 - 0.001 * lie)
			var b: Vector3 = ends[1][0] - ends[1][1] * (0.001 - 0.001 * lie)
			_quad(tool, [a - ends[0][2], b - ends[1][2], b + ends[1][2], a + ends[0][2]],
				[ends[0][1] * lie, ends[1][1] * lie, ends[1][1] * lie, ends[0][1] * lie], part, f)
		for edge: float in [1.0, -1.0]:
			var out_a: Vector3 = ends[0][2] * edge
			var out_b: Vector3 = ends[1][2] * edge
			_quad(tool, [ends[0][0] + out_a, ends[1][0] + out_b, ends[1][0] + out_b - ends[1][1] * 0.002, ends[0][0] + out_a - ends[0][1] * 0.002],
				[out_a.normalized(), out_b.normalized(), out_b.normalized(), out_a.normalized()], part, f)


## A capsule of foam round `middle` along `way`: `radius`, `half` long to either side of its middle.
static func _capsule(tool: SurfaceTool, middle: Vector3, way: Vector3, radius: float, half: float, part: Array) -> void:
	var side := way.cross(Vector3.UP if absf(way.y) < 0.9 else Vector3.FORWARD).normalized()
	var other := way.cross(side)
	var rings := 12
	var sides := 12
	var points: Array[Array] = []
	for r in rings + 1:
		var a := PI * r / rings - PI * 0.5
		var row: Array = []
		for k in sides:
			var b := TAU * k / sides
			var normal := way * sin(a) + (side * cos(b) + other * sin(b)) * cos(a)
			row.append([middle + way * signf(sin(a)) * half * minf(absf(sin(a)) * 3.0, 1.0) + normal * radius, normal])
		points.append(row)
	for r in rings:
		for k in sides:
			var j := (k + 1) % sides
			_quad(tool, [points[r][k][0], points[r + 1][k][0], points[r + 1][j][0], points[r][j][0]],
				[points[r][k][1], points[r + 1][k][1], points[r + 1][j][1], points[r][j][1]], part)


## A cylinder of `radius` and `length` along `frame`'s y round its origin, its ends closed if `capped`; `follow` how much the hips carry it.
static func _cylinder(tool: SurfaceTool, frame: Transform3D, radius: float, length: float, part: Array, capped: bool, follow := 0.0) -> void:
	var sides := 16
	var f := [follow, follow, follow, follow]
	for k in sides:
		var a := TAU * k / sides
		var b := TAU * (k + 1) / sides
		var out_a := frame.basis * Vector3(cos(a), 0.0, sin(a))
		var out_b := frame.basis * Vector3(cos(b), 0.0, sin(b))
		var up := frame.basis.y.normalized() * length * 0.5
		_quad(tool, [frame.origin + out_a * radius - up, frame.origin + out_a * radius + up, frame.origin + out_b * radius + up,
			frame.origin + out_b * radius - up], [out_a, out_a, out_b, out_b], part, f)
		if capped:
			for cap: float in [-1.0, 1.0]:
				var facing := frame.basis.y.normalized() * cap
				_triangle(tool, [frame.origin + up * cap, frame.origin + out_a * radius + up * cap, frame.origin + out_b * radius + up * cap],
					[facing, facing, facing], part, [follow, follow, follow])


## A box of `size` round `frame`'s origin along its axes.
static func _box(tool: SurfaceTool, frame: Transform3D, size: Vector3, part: Array) -> void:
	var half := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var face := normal * half[axis]
			var facing := (frame.basis * normal).normalized()
			_quad(tool, [frame * (face - u - v), frame * (face + u - v), frame * (face + u + v), frame * (face - u + v)], [facing, facing, facing, facing], part)


## A quad with a normal at each corner, its front where they point; `follows` how much the hips carry each corner, `depths` how deep in the
## helmet each lies (0 at its edge, 1 against the head: the liner darkens with it).
static func _quad(tool: SurfaceTool, corners: Array, normals: Array, part: Array, follows := [0.0, 0.0, 0.0, 0.0], depths := [0.0, 0.0, 0.0, 0.0]) -> void:
	_triangle(tool, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]], part, [follows[0], follows[1], follows[2]],
		[depths[0], depths[1], depths[2]])
	_triangle(tool, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]], part, [follows[0], follows[2], follows[3]],
		[depths[0], depths[2], depths[3]])


## One triangle; front faces wind clockwise as seen from where their normals point. Each vertex carries what its part is made of (COLOR,
## UV2 metallic and roughness, UV the clear coat and how deep in the helmet it lies, CUSTOM0 where it is in the helmet and its kind) and its
## bones: the head's, and the hips' as much as `follows` says.
static func _triangle(tool: SurfaceTool, corners: Array, normals: Array, part: Array, follows := [0.0, 0.0, 0.0], depths := [0.0, 0.0, 0.0]) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	var order := [0, 2, 1] if (b - a).cross(c - a).dot(facing) > 0.0 else [0, 1, 2]
	for i: int in order:
		var at: Vector3 = corners[i]
		var follow: float = follows[i]
		tool.set_normal((normals[i] as Vector3).normalized())
		tool.set_color(part[0])
		tool.set_uv2(Vector2(part[1], part[2]))
		tool.set_uv(Vector2(part[3], depths[i]))
		tool.set_custom(0, Color(at.x, at.y, at.z, part[4]))
		tool.set_bones(PackedInt32Array([0, 1, 0, 0]))
		tool.set_weights(PackedFloat32Array([1.0 - follow, follow, 0.0, 0.0]))
		tool.add_vertex(at)
