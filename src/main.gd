extends Node3D
## Plays a replay. Command line, after a double dash: --replay=<file> --at=<step> --person=<number> --close --shot=<png>.

const SETTINGS_PATH := "res://assets/data/playback.json"
const CLICK_REACH_PIXELS := 40.0
const FRAMES_BEFORE_SHOT := 12
const CLOSE_VIEW_SHARE := 0.05
const WALKED_METRES := 1.0
const MINUTES_IN_HOUR := 60.0
const HOURS_IN_DAY := 24.0

var _replay: ReplayData
var _playback: Playback
var _island: IslandView
var _camera: CameraRig
var _hud: Hud
var _people: Array[PersonView] = []
var _selected := 0
var _arguments := {}


func _ready() -> void:
	_arguments = _read_arguments()
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	_replay = ReplayData.load_file(_arguments.get("replay", settings["default_replay"]))
	if _replay == null:
		get_tree().quit(1)
		return
	_playback = Playback.new(int(_replay.scenario["steps"]), float(settings["seconds_per_step"]))
	_island = IslandView.new()
	add_child(_island)
	_island.build(_replay, float(settings["vertical_exaggeration"]))
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.frame(_island.map_centre(), _island.map_size())
	for index in _replay.people.size():
		var person := PersonView.new()
		person.name = "Person %d" % index
		add_child(person)
		_people.append(person)
	_hud = Hud.new()
	add_child(_hud)
	_hud.show_scenario(_replay.scenario["title"], _replay.provenance["evidence_label"])
	_hud.speed_chosen.connect(_playback.set_speed)
	_hud.next_person_chosen.connect(_next_person)
	_hud.time_chosen.connect(_playback.seek)
	_selected = clampi(int(_arguments.get("person", "0")), 0, _people.size() - 1)
	_follow_selected()
	if _arguments.has("close"):
		_camera.distance = _island.map_size() * CLOSE_VIEW_SHARE
	if _arguments.has("at"):
		_playback.seek(float(_arguments["at"]))
	if _arguments.has("shot"):
		_playback.set_speed(0)
		_take_shot.call_deferred(_arguments["shot"])


func _process(delta: float) -> void:
	if _replay == null:
		return
	_playback.advance(delta)
	var step := _playback.step_index()
	_island.show_moment(step, _hour_of_day(step))
	_show_people(step)
	_show_selected(step)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_playback.set_speed(0 if _playback.speed > 0 else 1)
			KEY_1, KEY_2, KEY_3:
				_playback.set_speed(event.keycode - KEY_0)
			KEY_TAB:
				_next_person()
			KEY_F:
				_follow_selected()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_near(event.position)


func _show_people(step: int) -> void:
	for index in _people.size():
		var at := _replay.person_position(index, _playback.time_steps)
		var record := _replay.person_step(index, step)
		var path: Array = record["path_m"]
		var has_moved := Vector2(path[0][0], path[0][1]).distance_to(Vector2(path[-1][0], path[-1][1])) > WALKED_METRES
		_people[index].show_state(_island.ground_at(at), record, index == _selected, has_moved and _playback.speed > 0, _camera.distance)


func _show_selected(step: int) -> void:
	var record := _replay.person_step(_selected, step)
	var person: Dictionary = _replay.people[_selected]
	var position_now := _people[_selected].global_position
	if _camera.follow != null:
		_camera.follow = position_now
	var on_screen := not _camera.camera.is_position_behind(position_now)
	_hud.show_person(person, record, "Day %d, %02d:%02d" % [int(record["day"]), int(record["hour"]), int(record["minute"])], _camera.camera.unproject_position(position_now), on_screen)
	_hud.show_clock(_playback.time_steps, _playback.steps, _playback.speed)
	_hud.show_ending(_ending_text(), _playback.is_finished())


func _ending_text() -> String:
	var lines := PackedStringArray([_replay.scenario["title"]])
	for person: Dictionary in _replay.people:
		var outcome: String = person["outcome"]
		lines.append("%s: %s%s" % [person["name"], outcome, "" if person["cause"] == null else " (%s)" % person["cause"]])
	lines.append("Evidence: %s" % _replay.provenance["evidence_label"])
	return "\n".join(lines)


func _hour_of_day(step: int) -> float:
	var minutes := step * float(_replay.scenario["step_minutes"]) + (_playback.time_steps - step) * float(_replay.scenario["step_minutes"])
	return fposmod(float(_replay.scenario["t0_local_hour"]) + minutes / MINUTES_IN_HOUR, HOURS_IN_DAY)


func _next_person() -> void:
	_selected = (_selected + 1) % _people.size()
	_follow_selected()


func _follow_selected() -> void:
	_camera.follow = _island.ground_at(_replay.person_position(_selected, _playback.time_steps))


func _select_near(screen_point: Vector2) -> void:
	for index in _people.size():
		if _camera.camera.unproject_position(_people[index].global_position).distance_to(screen_point) < CLICK_REACH_PIXELS:
			_selected = index
			_follow_selected()
			return


func _read_arguments() -> Dictionary:
	var found := {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		found[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return found


func _take_shot(path: String) -> void:
	_camera.target = _island.ground_at(_replay.person_position(_selected, _playback.time_steps))
	for _frame in FRAMES_BEFORE_SHOT:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved %s" % path)
	get_tree().quit()
