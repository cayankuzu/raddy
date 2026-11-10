class_name ShockGun
## The shock gun as a crew member holds it up (CrewRig, in the right hand while aiming), built in code: a black polymer body, a grip in dark
## rubber and the dart cartridge at the front in safety yellow, no maker's mark. In the hand bone's space: +Y along the barrel, +Z up, +X
## to the right (the grip goes down through the fist).

## The boxes it is made of: middle, size, a tilt about X (degrees) and the colour. The grip stands in the fist, a little to the palm's side
## (-X of the right hand), the barrel over it.
const PARTS: Array[Array] = [
	[Vector3(-0.018, 0.105, 0.045), Vector3(0.028, 0.15, 0.036), 0.0, Color(0.03, 0.03, 0.032)],
	[Vector3(-0.018, 0.1975, 0.0455), Vector3(0.032, 0.035, 0.041), 0.0, Color(0.85, 0.62, 0.04)],
	[Vector3(-0.02, 0.07, -0.008), Vector3(0.026, 0.04, 0.1), -16.0, Color(0.06, 0.06, 0.065)],
	[Vector3(-0.018, 0.128, 0.015), Vector3(0.006, 0.022, 0.03), 0.0, Color(0.03, 0.03, 0.032)],
]
## Where the darts leave it.
const MUZZLE := Vector3(-0.018, 0.215, 0.045)

static var _mesh: ArrayMesh


static func mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in PARTS:
			_box(tool, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(part[2])), part[0]), part[1], part[3])
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.45
		tool.set_material(material)
		_mesh = tool.commit()
	return _mesh


## A box of `size` placed by `at`, its faces flat-shaded.
static func _box(tool: SurfaceTool, at: Transform3D, size: Vector3, colour: Color) -> void:
	var half := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var centre := normal * half[axis]
			var corners: Array[Vector3] = [centre - u - v, centre + u - v, centre + u + v, centre - u + v]
			if side < 0.0:
				corners.reverse()
			for index: int in [0, 2, 1, 0, 3, 2]:
				tool.set_normal(at.basis * normal)
				tool.set_color(colour)
				tool.add_vertex(at * corners[index])
