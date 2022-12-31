@tool
class_name Clearing
extends GeometryInstance3D


var _initializationFinished := false
var _mesh: ArrayMesh
var _fnl := FastNoiseLite.new()


@export_category("Debug")
@export var recalculateFloor: bool = false:
	get:
		return recalculateFloor
	set(_value):
		recalculateMesh()
		recalculateFloor = false

@export var recalculatePineTrees: bool = false:
	get:
		return recalculatePineTrees
	set(_value):
		recalculatePines()
		recalculatePineTrees = false


@export_category("Seeds")
@export_range(0, 9999, 1) var seed1 := 1416:
	get:
		return seed1
	set(value):
		seed1 = value
		recalculateMesh()

@export_range(0, 9999, 1) var seed2 := 4711:
	get:
		return seed2
	set(value):
		seed2 = value
		recalculateMesh()


@export_category("Size")
@export_range(2, 128, 2, "suffix:m") var width := 92:
	get:
		return width
	set(value):
		width = value
		recalculateMesh()

@export_range(2.0, 64, 2, "suffix:m") var depth := 46:
	get:
		return depth
	set(value):
		depth = value
		recalculateMesh()


@export_category("Materials")
@export var groundMaterial: Material = null:
	get:
		return groundMaterial
	set(value):
		groundMaterial = value
		recalculateMesh()

@export var trunkMaterial: Material = null:
	get:
		return trunkMaterial
	set(value):
		trunkMaterial = value
		recalculatePines()

@export var branchMaterial: Material = null:
	get:
		return branchMaterial
	set(value):
		branchMaterial = value
		recalculatePines()


func _init() -> void:
	_fnl.noise_type = FastNoiseLite.TYPE_VALUE
	_fnl.fractal_type = FastNoiseLite.FRACTAL_FBM
	_fnl.fractal_octaves = 2
	_fnl.fractal_lacunarity = 2
	_fnl.fractal_gain = 0.5
	_fnl.fractal_weighted_strength = 0
	_fnl.frequency = 1.5


func _enter_tree() -> void:
	_initializationFinished = true
	recalculateMesh()
	recalculatePines()


func recalculateMesh() -> void:
	if not _initializationFinished:
		return
	_mesh = ArrayMesh.new()

	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv1s := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()

	var halfWidth = floori(width * 0.5)
	var halfDepth = floori(depth * 0.5)
	for z in depth * 4:
		for x in width * 4:
			var x12 := float(x) * 0.25 - halfWidth
			var x34 := float(x + 1) * 0.25 - halfWidth
			var z14 := float(z + 1) * 0.25 - halfDepth
			var z23 := float(z) * 0.25 - halfDepth

			var y1 := getYAt(x12, z14)
			var y2 := getYAt(x12, z23)
			var y3 := getYAt(x34, z23)
			var y4 := getYAt(x34, z14)

			var p1 = Vector3(x12, y1, z14)
			var p2 = Vector3(x12, y2, z23)
			var p3 = Vector3(x34, y3, z23)
			var p4 = Vector3(x34, y4, z14)

			addTriangle(
				verts, normals, uv1s, uv2s, indices,
				p1, p2, p3,
			)
			addTriangle(
				verts, normals, uv1s, uv2s, indices,
				p1, p3, p4,
			)

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uv1s
	surface_array[Mesh.ARRAY_TEX_UV2] = uv2s
	surface_array[Mesh.ARRAY_INDEX] = indices

	var newSurfaceId = _mesh.get_surface_count()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	_mesh.surface_set_material(newSurfaceId, groundMaterial)

	set_base(_mesh.get_rid())


func addTriangle(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uv1s: PackedVector2Array,
	uv2s: PackedVector2Array,
	indices: PackedInt32Array,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
) -> void:
	var index = verts.size()

	verts.append(p1)
	verts.append(p2)
	verts.append(p3)

	var normal = (p3 - p1).cross(p2 - p1).normalized()
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)

	uv1s.append(Vector2(p1.x, p1.z))
	uv1s.append(Vector2(p2.x, p2.z))
	uv1s.append(Vector2(p3.x, p3.z))

	var widthFactor = 1.0 / width
	var depthFactor = 1.0 / depth
	uv2s.append(Vector2(p1.x * widthFactor + 0.5, p1.z * depthFactor + 0.5))
	uv2s.append(Vector2(p2.x * widthFactor + 0.5, p2.z * depthFactor + 0.5))
	uv2s.append(Vector2(p3.x * widthFactor + 0.5, p3.z * depthFactor + 0.5))

	indices.append(index)
	indices.append(index + 1)
	indices.append(index + 2)


func getYAt(x: float, z: float) -> float:
	_fnl.seed = seed1
	var y := _fnl.get_noise_2d(x * 0.03125, z * 0.03125) * 4.0

	_fnl.seed = seed2
	y += _fnl.get_noise_2d(x * 0.25, z * 0.25) * 0.4

	return y


func recalculatePines() -> void:
	var nodes := get_children()
	for node in nodes:
		remove_child(node)
		node.queue_free()

	for z in range(-20, -4, 2):
		for x in range(-52, 52, 3):
			_fnl.seed = seed2

			var pine = PineTree.new()
			var n1 := _fnl.get_noise_2d(x, z)
			var n2 := _fnl.get_noise_2d(z, x)
			var px = float(x) + n1
			var pz = float(z) + n2
			var py = getYAt(px, pz)

			pine.position = Vector3(px, py, pz)
			_fnl.seed = seed1
			var pineBaseSeed = floori(_fnl.get_noise_2d(px, pz) * 5000.0) + 5000

			pine.seed1 = (pineBaseSeed + 1581) % 10000
			pine.seed2 = (pineBaseSeed + 1416) % 10000
			pine.seed3 = (pineBaseSeed + 4421) % 10000

			pine.trunkMaterial = trunkMaterial
			pine.branchMaterial = branchMaterial

			add_child(pine)
