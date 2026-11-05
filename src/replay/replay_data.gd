class_name ReplayData
extends RefCounted
## A finished run exported by stranded_game.export. Holds no game rules: everything here comes from the Python simulation.

const SUPPORTED_SCHEMA := 1

var scenario: Dictionary
var provenance: Dictionary
var grid: Dictionary
var sites: Dictionary
var series: Dictionary
var people: Array
var elevation: PackedFloat32Array
var land: PackedFloat32Array
var hazards: Dictionary = {}  # Field name to {"changes": PackedInt32Array, "frames": Array[PackedFloat32Array]}.


## Reads a replay file. Returns null and reports why if it can't be used.
static func load_file(path: String) -> ReplayData:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Can't read the replay at %s. Export one with: python -m stranded_game.export <scenario> --out <file>" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("The replay at %s isn't valid JSON." % path)
		return null
	return from_dictionary(parsed)


## Builds a replay from parsed JSON. Returns null if its schema isn't supported.
static func from_dictionary(raw: Dictionary) -> ReplayData:
	if int(raw.get("schema", 0)) != SUPPORTED_SCHEMA:
		push_error("This game reads replay schema %d, and the file has %s." % [SUPPORTED_SCHEMA, raw.get("schema", "none")])
		return null
	var replay := ReplayData.new()
	replay.scenario = raw["scenario"]
	replay.provenance = raw["provenance"]
	replay.grid = raw["grid"]
	replay.sites = raw["sites"]
	replay.series = raw["series"]
	replay.people = raw["people"]
	replay.elevation = decode_array(raw["terrain"]["elevation"])
	replay.land = decode_array(raw["terrain"]["land"])
	for field: String in raw["hazards"]:
		var stored: Dictionary = raw["hazards"][field]
		var frames: Array[PackedFloat32Array] = []
		for spec: Dictionary in stored["frames"]:
			frames.append(decode_array(spec))
		replay.hazards[field] = {"changes": PackedInt32Array(stored["changes"]), "frames": frames}
	return replay


## Unpacks one array: base64, then zlib, then little-endian 32-bit floats in row order.
static func decode_array(spec: Dictionary) -> PackedFloat32Array:
	var compressed := Marshalls.base64_to_raw(spec["zlib_b64"])
	var size := int(spec["rows"]) * int(spec["cols"]) * 4
	return compressed.decompress(size, FileAccess.COMPRESSION_DEFLATE).to_float32_array()


## The frame of a hazard field that applies at a step. Frames are stored only when they change.
func hazard_frame(field: String, step: int) -> PackedFloat32Array:
	var stored: Dictionary = hazards[field]
	var changes: PackedInt32Array = stored["changes"]
	var latest := changes.bsearch(step, false) - 1
	return stored["frames"][clampi(latest, 0, changes.size() - 1)]


## Ground height in metres at a map position, blending the four nearest cells.
func elevation_at(position_m: Vector2) -> float:
	var cell := _to_cell(position_m)
	var nx := int(grid["nx"])
	var ny := int(grid["ny"])
	var col := clampi(int(floor(cell.x)), 0, nx - 2)
	var row := clampi(int(floor(cell.y)), 0, ny - 2)
	var across := clampf(cell.x - col, 0.0, 1.0)
	var down := clampf(cell.y - row, 0.0, 1.0)
	var top := lerpf(elevation[row * nx + col], elevation[row * nx + col + 1], across)
	var bottom := lerpf(elevation[(row + 1) * nx + col], elevation[(row + 1) * nx + col + 1], across)
	return lerpf(top, bottom, down)


## The record of a person at a step. A person who has died keeps their last record.
func person_step(person: int, step: int) -> Dictionary:
	var steps: Array = people[person]["steps"]
	return steps[clampi(step, 0, steps.size() - 1)]


## Where a person is at a time measured in steps, moving evenly along that step's recorded path.
func person_position(person: int, time_steps: float) -> Vector2:
	var steps: Array = people[person]["steps"]
	var step := clampi(int(floor(time_steps)), 0, steps.size() - 1)
	var path: Array = steps[step]["path_m"]
	var along := clampf(time_steps - step, 0.0, 1.0) * (path.size() - 1)
	var index := clampi(int(floor(along)), 0, path.size() - 2)
	var from := Vector2(path[index][0], path[index][1])
	var to := Vector2(path[index + 1][0], path[index + 1][1])
	return from.lerp(to, along - index)


## How far a map position is through the downsampled grid, in cells. Cell centres sit half a full cell from the grid's corner.
func _to_cell(position_m: Vector2) -> Vector2:
	var dx := float(grid["dx_m"])
	var half_full_cell := 0.5 * dx / float(grid["stride"])
	return Vector2(position_m.x - float(grid["x0_m"]) - half_full_cell, float(grid["y0_m"]) - position_m.y - half_full_cell) / dx
