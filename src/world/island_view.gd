class_name IslandView
extends Node3D
## Draws a replay's real terrain, sea, sites and hazards. Where a hazard is always comes from the replay.

const UNITS_PER_METRE := 0.01
const SEA_FLOOR_M := -30.0
const SEA_SIZE_UNITS := 4000.0
const SITE_SIZE_UNITS := 2.0
const ASH_FULL_KG_M2 := 100.0
const NOON_HOUR := 12.0
const HOURS_IN_DAY := 24.0
const SAND_TOP_M := 25.0
const FOREST_TOP_M := 600.0
const ROCK_TOP_M := 1100.0
const SAND := Color(0.82, 0.75, 0.55)
const GRASS := Color(0.45, 0.66, 0.30)
const FOREST := Color(0.20, 0.42, 0.20)
const ROCK := Color(0.46, 0.41, 0.36)
const SUMMIT := Color(0.62, 0.59, 0.56)
const SITE_COLOURS := {"assembly": Color(0.95, 0.80, 0.25), "water": Color(0.25, 0.65, 0.95), "food": Color(0.40, 0.85, 0.35), "wood": Color(0.60, 0.40, 0.20)}
const TERRAIN_SHADER := preload("res://src/world/terrain.gdshader")

var replay: ReplayData
var vertical_exaggeration := 1.0
var _terrain_material: ShaderMaterial
var _sun: DirectionalLight3D
var _environment: Environment
var _column: MeshInstance3D
var _last_hazard_step := -1


## Builds everything for a replay. Call once.
func build(with_replay: ReplayData, exaggeration: float) -> void:
	replay = with_replay
	vertical_exaggeration = exaggeration
	_build_terrain()
	_build_sea()
	_build_sites()
	_build_column()
	_build_light()


## Turns a map position in metres, at a height in metres, into a position in the 3D world.
func to_world(position_m: Vector2, height_m: float) -> Vector3:
	return Vector3((position_m.x - float(replay.grid["x0_m"])) * UNITS_PER_METRE, height_m * UNITS_PER_METRE * vertical_exaggeration, (float(replay.grid["y0_m"]) - position_m.y) * UNITS_PER_METRE)


## A point on the ground at a map position.
func ground_at(position_m: Vector2) -> Vector3:
	return to_world(position_m, maxf(replay.elevation_at(position_m), 0.0))


## The middle of the map, on the ground.
func map_centre() -> Vector3:
	var half := Vector2(float(replay.grid["nx"]), float(replay.grid["ny"])) * float(replay.grid["dx_m"]) * 0.5
	return ground_at(Vector2(float(replay.grid["x0_m"]) + half.x, float(replay.grid["y0_m"]) - half.y))


## The longest side of the map, in world units.
func map_size() -> float:
	return maxf(float(replay.grid["nx"]), float(replay.grid["ny"])) * float(replay.grid["dx_m"]) * UNITS_PER_METRE


## Updates sunlight, hazards and the eruption column for a moment in the run.
func show_moment(step: int, hour_of_day: float) -> void:
	_show_light(hour_of_day)
	if step == _last_hazard_step:
		return
	_last_hazard_step = step
	_show_hazards(step)
	_show_column(step)


func _build_terrain() -> void:
	var nx := int(replay.grid["nx"])
	var ny := int(replay.grid["ny"])
	var dx := float(replay.grid["dx_m"])
	var surface := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	surface.resize(nx * ny)
	normals.resize(nx * ny)
	colours.resize(nx * ny)
	uvs.resize(nx * ny)
	var half_full_cell := 0.5 * dx / float(replay.grid["stride"])
	for row in ny:
		for col in nx:
			var at := row * nx + col
			var is_land := replay.land[at] > 0.0
			var height := replay.elevation[at] if is_land else SEA_FLOOR_M
			var position_m := Vector2(float(replay.grid["x0_m"]) + half_full_cell + col * dx, float(replay.grid["y0_m"]) - half_full_cell - row * dx)
			surface[at] = to_world(position_m, height)
			colours[at] = _ground_colour(height, is_land)
			uvs[at] = Vector2((col + 0.5) / nx, (row + 0.5) / ny)
	for row in ny:
		for col in nx:
			normals[row * nx + col] = _normal_at(surface, nx, ny, row, col)
	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (ny - 1) * 6)
	var next := 0
	for row in ny - 1:
		for col in nx - 1:
			var corner := row * nx + col
			for offset: int in [0, 1, nx, 1, nx + 1, nx]:
				indices[next] = corner + offset
				next += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = surface
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	mesh.surface_set_material(0, _terrain_material)
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	add_child(terrain)


func _normal_at(surface: PackedVector3Array, nx: int, ny: int, row: int, col: int) -> Vector3:
	var west := surface[row * nx + maxi(col - 1, 0)]
	var east := surface[row * nx + mini(col + 1, nx - 1)]
	var north := surface[maxi(row - 1, 0) * nx + col]
	var south := surface[mini(row + 1, ny - 1) * nx + col]
	return (south - north).cross(east - west).normalized()


func _ground_colour(height: float, is_land: bool) -> Color:
	if not is_land:
		return SAND.darkened(0.45)
	if height < SAND_TOP_M:
		return SAND.lerp(GRASS, height / SAND_TOP_M)
	if height < FOREST_TOP_M:
		return GRASS.lerp(FOREST, (height - SAND_TOP_M) / (FOREST_TOP_M - SAND_TOP_M))
	if height < ROCK_TOP_M:
		return FOREST.lerp(ROCK, (height - FOREST_TOP_M) / (ROCK_TOP_M - FOREST_TOP_M))
	return ROCK.lerp(SUMMIT, clampf((height - ROCK_TOP_M) / (FOREST_TOP_M - SAND_TOP_M), 0.0, 1.0))


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * SEA_SIZE_UNITS
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.07, 0.36, 0.50, 0.86)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.25
	water.metallic = 0.2
	plane.material = water
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = map_centre() * Vector3(1.0, 0.0, 1.0)
	add_child(sea)


func _build_sites() -> void:
	for site: String in SITE_COLOURS:
		for point: Array in replay.sites.get(site, []):
			var marker := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.top_radius = SITE_SIZE_UNITS * 0.5
			shape.bottom_radius = SITE_SIZE_UNITS * 0.5
			shape.height = SITE_SIZE_UNITS * 0.5
			var paint := StandardMaterial3D.new()
			paint.albedo_color = SITE_COLOURS[site]
			shape.material = paint
			marker.mesh = shape
			marker.name = "Site %s" % site
			marker.position = ground_at(Vector2(point[0], point[1]))
			add_child(marker)


func _build_column() -> void:
	_column = MeshInstance3D.new()
	_column.name = "Eruption column"
	var shape := CylinderMesh.new()
	shape.bottom_radius = 1.0
	shape.top_radius = 8.0
	shape.height = 1.0
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color(0.25, 0.23, 0.22, 0.8)
	ash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shape.material = ash
	_column.mesh = shape
	_column.visible = false
	add_child(_column)


func _build_light() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	add_child(_sun)
	var sky_material := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var holder := WorldEnvironment.new()
	holder.environment = _environment
	add_child(holder)


func _show_light(hour_of_day: float) -> void:
	var height := cos((hour_of_day - NOON_HOUR) / HOURS_IN_DAY * TAU)
	_sun.rotation = Vector3(-deg_to_rad(10.0 + 70.0 * maxf(height, 0.0)), deg_to_rad(40.0 + hour_of_day * 8.0), 0.0)
	_sun.light_energy = clampf(height * 1.4 + 0.15, 0.05, 1.3)
	_environment.ambient_light_energy = clampf(height * 0.7 + 0.45, 0.2, 1.0)
	_environment.background_energy_multiplier = clampf(height * 0.8 + 0.5, 0.08, 1.0)


func _show_hazards(step: int) -> void:
	_terrain_material.set_shader_parameter("ash_map", _hazard_texture("tephra.deposit_load", step, ASH_FULL_KG_M2))
	_terrain_material.set_shader_parameter("flow_map", _hazard_texture("pdc.active", step, 1.0))


func _hazard_texture(field: String, step: int, full_value: float) -> ImageTexture:
	var nx := int(replay.grid["nx"])
	var ny := int(replay.grid["ny"])
	var strength := PackedByteArray()
	strength.resize(nx * ny)
	if replay.hazards.has(field):
		var frame := replay.hazard_frame(field, step)
		for at in frame.size():
			strength[at] = int(clampf(frame[at] / full_value, 0.0, 1.0) * 255.0)
	return ImageTexture.create_from_image(Image.create_from_data(nx, ny, false, Image.FORMAT_R8, strength))


func _show_column(step: int) -> void:
	var heights: Array = replay.series.get("eruption.column_height", [])
	var vents: Array = replay.sites.get("vent", [])
	if heights.is_empty() or vents.is_empty():
		return
	var height_m := float(heights[clampi(step, 0, heights.size() - 1)])
	_column.visible = height_m > 0.0
	if not _column.visible:
		return
	var vent := ground_at(Vector2(vents[0][0], vents[0][1]))
	var height_units := height_m * UNITS_PER_METRE * vertical_exaggeration
	_column.position = vent + Vector3.UP * height_units * 0.5
	_column.scale = Vector3(1.0, height_units, 1.0)
