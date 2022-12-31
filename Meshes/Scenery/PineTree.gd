@tool
class_name PineTree
extends GeometryInstance3D


var _initializationFinished := false
var _mesh: ArrayMesh
var _fnl := FastNoiseLite.new()


@export_category("Debug")
@export var doRecalculation: bool = false:
	get:
		return doRecalculation
	set(_value):
		recalculateMesh()
		doRecalculation = false


@export_category("Details")
@export_range(3, 64, 1) var trunkDetail := 12:
	get:
		return trunkDetail
	set(value):
		trunkDetail = value
		recalculateMesh()

@export_range(2, 8, 1) var branchDetail := 4:
	get:
		return branchDetail
	set(value):
		branchDetail = value
		recalculateMesh()


@export_category("Seeds")
@export_range(0, 9999, 1) var seed1 := 1581:
	get:
		return seed1
	set(value):
		seed1 = value
		recalculateMesh()

@export_range(0, 9999, 1) var seed2 := 1416:
	get:
		return seed2
	set(value):
		seed2 = value
		recalculateMesh()

@export_range(0, 9999, 1) var seed3 := 4421:
	get:
		return seed3
	set(value):
		seed3 = value
		recalculateMesh()
	
@export_category("Materials")
@export var trunkMaterial: Material = null:
	get:
		return trunkMaterial
	set(value):
		trunkMaterial = value
		recalculateMesh()

@export var branchMaterial: Material = null:
	get:
		return branchMaterial
	set(value):
		branchMaterial = value
		recalculateMesh()


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


func recalculateMesh() -> void:
	if not _initializationFinished:
		return
	_mesh = ArrayMesh.new()

	_fnl.seed = seed1
	var heightModifier := _fnl.get_noise_3dv(global_position) * 2.0
	var treeHeight := 5.0 + heightModifier

	addTrunk(0.3, 0.05, treeHeight * 0.8)

	_fnl.seed = seed2
	var ownHeightModifier := _fnl.get_noise_3dv(global_position) * 0.2
	var ringAmount := floori(treeHeight) * 2 - 2
	var baseBranchOwnHeight := 0.9 + ownHeightModifier
	var topBranchOwnHeight = (0.9 + ownHeightModifier) * 1.4

	for i in ringAmount:
		var branchRadius := 0.2 * (ringAmount - float(i))
		var branchFloorHeight := 2.0 + int(i) * 0.5
		var branchOwnHeight := baseBranchOwnHeight + (topBranchOwnHeight - baseBranchOwnHeight) * (branchFloorHeight - 2.0) / (treeHeight - 2.0)

		_fnl.seed = seed3
		var branchRings := 8 + floori(_fnl.get_noise_1d(float(i) * 16.0) * 4.2)
		var angleOffset := _fnl.get_noise_1d(float(i))

		addBranchRing(branchRadius, branchOwnHeight, branchFloorHeight, branchRings, angleOffset)

	set_base(_mesh.get_rid())


func addTrunk(
	rootRadius: float,
	topRadius: float,
	height: float,
) -> void:
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv1s := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in trunkDetail:
		var angle = i * TAU / trunkDetail
		var nextAngle = (i + 1) * TAU / trunkDetail

		var p1 = Vector3(cos(nextAngle) * rootRadius, 0.0, sin(nextAngle) * rootRadius)
		var p2 = Vector3(cos(nextAngle) * topRadius, height, sin(nextAngle) * topRadius)
		var p3 = Vector3(cos(angle) * topRadius, height, sin(angle) * topRadius)
		var p4 = Vector3(cos(angle) * rootRadius, 0.0, sin(angle) * rootRadius)

		addTrunkTriangle(
			verts, normals, uv1s, indices,
			p1, p2, p3,
			nextAngle, nextAngle, angle,
		)
		addTrunkTriangle(
			verts, normals, uv1s, indices,
			p1, p3, p4,
			nextAngle, angle, angle,
		)

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uv1s
	surface_array[Mesh.ARRAY_INDEX] = indices

	var newSurfaceId = _mesh.get_surface_count()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	_mesh.surface_set_material(newSurfaceId, trunkMaterial)


func addTrunkTriangle(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uv1s: PackedVector2Array,
	indices: PackedInt32Array,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	r1: float,
	r2: float,
	r3: float,
) -> void:
	var index = verts.size()

	verts.append(p1)
	verts.append(p2)
	verts.append(p3)

	var normal = (p3 - p1).cross(p2 - p1).normalized()
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)

	uv1s.append(Vector2(1.0 - r1 / TAU, 1.0 - p1.y))
	uv1s.append(Vector2(1.0 - r2 / TAU, 1.0 - p2.y))
	uv1s.append(Vector2(1.0 - r3 / TAU, 1.0 - p3.y))

	indices.append(index)
	indices.append(index + 1)
	indices.append(index + 2)


func addBranchRing(
	radius: float,
	height: float,
	top: float,
	branchAmount: int,
	angleOffset: float,
) -> void:
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var pTop := Vector3(0.0, top, 0.0)

	for i in branchAmount:
		var angle = i * TAU / branchAmount

		addBranch(
			verts,
			normals,
			indices,
			angle + angleOffset,
			radius,
			height,
			pTop,
		)

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_INDEX] = indices

	var newSurfaceId = _mesh.get_surface_count()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	_mesh.surface_set_material(newSurfaceId, branchMaterial)


func addBranch(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	angle: float,
	radius: float,
	height: float,
	pTop: Vector3,
) -> void:

	var pTip := Vector3(cos(angle) * radius, pTop.y - height, sin(angle) * radius)
	var vec := pTip - pTop
	var branchWidth = radius * 0.5

	for i in branchDetail:
		if i == 0:
			continue

		var index := verts.size()

		var factor = i / float(branchDetail)
		var nextFactor = (i + 1) / float(branchDetail)
		var p1 = pTop + vec * factor
		var p2 = pTop + vec * nextFactor

		var verticalOffset = factor - pow(factor, 2.0)
		var nextVerticalOffset = nextFactor - pow(nextFactor, 2.0)

		p1.y -= verticalOffset
		p2.y -= nextVerticalOffset

		var topProjectedP1 = Vector2(p1.x, p1.z)
		var topProjectedP2 = Vector2(p2.x, p2.z)
		var topProjectedVec = topProjectedP2 - topProjectedP1
		var topProjectedVecRotated = topProjectedVec.rotated(TAU / 4.0).normalized()

		var subBranchWidth = branchWidth * (1.0 - factor)
		var p3 = p1 + Vector3(topProjectedVecRotated.x, 0, topProjectedVecRotated.y) * subBranchWidth
		var p4 = p1 - Vector3(topProjectedVecRotated.x, 0, topProjectedVecRotated.y) * subBranchWidth

		var normal = (p4 - p2).cross(p3 - p2).normalized()

		verts.append(p2)
		verts.append(p3)
		verts.append(p4)

		normals.append(normal)
		normals.append(normal)
		normals.append(normal)

		indices.append(index)
		indices.append(index + 1)
		indices.append(index + 2)
