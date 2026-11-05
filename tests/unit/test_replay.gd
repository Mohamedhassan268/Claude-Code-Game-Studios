extends RefCounted
## Checks that the game reads what Python wrote. The fixture comes from tools/make_test_replay.py, which uses Python's own zlib.

const FIXTURE := "res://tests/fixtures/tiny_replay.json"
const CLOSE := 0.01

var failures: PackedStringArray = []


func _replay() -> ReplayData:
	return ReplayData.load_file(FIXTURE)


func _near(name: String, have: float, want: float) -> void:
	if absf(have - want) > CLOSE:
		failures.append("%s: have %s, want %s" % [name, have, want])


func _same(name: String, have: Variant, want: Variant) -> void:
	if have != want:
		failures.append("%s: have %s, want %s" % [name, have, want])


func test_arrays_written_by_python_unpack_exactly() -> void:
	var replay := _replay()
	_same("size", replay.elevation.size(), 12)
	_near("first", replay.elevation[0], 0.0)
	_near("last", replay.elevation[11], 110.0)


func test_elevation_at_a_cell_centre_is_that_cell() -> void:
	# Cell (row 1, col 2) of a grid with stride 2 and full cells of 50 m: 25 m in, then 2 cells of 100 m across and 1 down.
	_near("centre", _replay().elevation_at(Vector2(1000.0 + 25.0 + 200.0, 2000.0 - 25.0 - 100.0)), 60.0)


func test_elevation_blends_between_cells() -> void:
	_near("blend", _replay().elevation_at(Vector2(1000.0 + 25.0 + 50.0, 2000.0 - 25.0)), 5.0)


func test_hazard_frame_holds_until_the_next_change() -> void:
	var replay := _replay()
	_near("step 0", replay.hazard_frame("pdc.active", 0)[0], 0.0)
	_near("step 1", replay.hazard_frame("pdc.active", 1)[0], 0.0)
	_near("step 2", replay.hazard_frame("pdc.active", 2)[0], 1.0)
	_near("step 3", replay.hazard_frame("pdc.active", 3)[0], 1.0)


func test_person_moves_along_the_recorded_path_in_order() -> void:
	var replay := _replay()
	_same("start", replay.person_position(0, 0.0), Vector2(0.0, 0.0))
	_same("quarter", replay.person_position(0, 0.25), Vector2(5.0, 0.0))
	_same("three quarters", replay.person_position(0, 0.75), Vector2(10.0, 5.0))


func test_a_dead_person_keeps_their_last_record() -> void:
	_same("last record", int(_replay().person_step(0, 99)["t"]), 1)


func test_playback_stops_at_the_end_and_pauses() -> void:
	var clock := Playback.new(4, 2.0)
	clock.advance(1.0)
	_near("half a step", clock.time_steps, 0.5)
	clock.set_speed(0)
	clock.advance(10.0)
	_near("paused", clock.time_steps, 0.5)
	clock.set_speed(3)
	clock.advance(100.0)
	_same("finished", clock.is_finished(), true)
	_same("last step", clock.step_index(), 3)


func test_mood_falls_with_the_lowest_need_and_with_stress() -> void:
	_near("calm", PersonView.mood_of({"needs": {"hunger": 0.8, "thirst": 0.4}, "stress": 0.0}), 0.4)
	_near("stressed", PersonView.mood_of({"needs": {"hunger": 0.8, "thirst": 0.4}, "stress": 1.0}), 0.2)
