class_name Hud
extends CanvasLayer
## The Sims-style screen: needs, thought bubble, speeds, timeline and evidence label. It shows a replay's values and never computes its own.

signal speed_chosen(multiplier: int)
signal next_person_chosen
signal time_chosen(time_steps: float)

const NEEDS_SHOWN := ["hunger", "thirst", "warmth", "energy", "safety", "morale"]
const PANEL := Color(0.05, 0.17, 0.22, 0.93)
const PANEL_EDGE := Color(0.30, 0.72, 0.80, 0.7)
const BUBBLE := Color(0.98, 0.98, 0.95, 0.96)
const INK_ON_BUBBLE := Color(0.08, 0.14, 0.18)
const CHOSEN := Color(0.10, 0.55, 0.65)
const OTHER_OPTION := Color(0.62, 0.70, 0.72)
const GOOD := Color(0.30, 0.82, 0.45)
const MIDDLING := Color(0.95, 0.75, 0.22)
const BAD := Color(0.90, 0.25, 0.22)
const MARGIN := 18
const BUBBLE_WIDTH := 340.0
const BUBBLE_ABOVE_PERSON := 170.0
const ACTION_NAMES := {"forage": "Forage", "drink": "Drink", "build_shelter": "Build shelter", "rest": "Rest", "explore": "Explore", "craft": "Craft", "hide": "Evacuate or hide"}
const MIND_NAMES := {"quantum": "Quantum mind", "classical": "Classical mind", "classical_mixture": "Classical control"}

var _name_label: Label
var _clock_label: Label
var _action_label: Label
var _event_label: Label
var _stress_bar: ProgressBar
var _need_bars := {}
var _timeline: HSlider
var _speed_buttons: Array[Button] = []
var _bubble: PanelContainer
var _reason_label: Label
var _option_rows: VBoxContainer
var _ending: PanelContainer
var _ending_label: Label
var _setting_timeline := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_person_card(root)
	_build_needs(root)
	_build_action_card(root)
	_build_timeline(root)
	_build_bubble(root)
	_build_ending(root)


## Shows the evidence label and scenario title, which stay on screen for the whole run.
func show_scenario(title: String, evidence_label: String) -> void:
	var banner := _panel(PANEL)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := _label("%s   |   Evidence: %s" % [title, evidence_label], 15)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(text)
	get_child(0).add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)


## Shows one person's record. The bubble follows their position on screen.
func show_person(person: Dictionary, record: Dictionary, clock_text: String, bubble_at: Vector2, bubble_visible: bool) -> void:
	_name_label.text = "%s\n%s" % [person["name"], MIND_NAMES.get(person["mind"], person["mind"])]
	_clock_label.text = clock_text
	var action_name: String = ACTION_NAMES.get(record["action"], record["action"])
	_action_label.text = "Now: %s" % action_name if record["alive"] else "Died: %s" % str(person["cause"])
	_event_label.text = "" if record["event"] == "none" else "Noticed: %s" % String(record["event"]).replace("_", " ")
	_stress_bar.value = float(record["stress"])
	for need: String in NEEDS_SHOWN:
		_show_need(_need_bars[need], float(record["needs"][need]))
	_reason_label.text = record["reason"]
	_show_options(record["probs"], record["action"])
	_bubble.visible = bubble_visible and record["alive"]
	var screen := get_viewport().get_visible_rect().size
	_bubble.reset_size()
	_bubble.position = Vector2(clampf(bubble_at.x - BUBBLE_WIDTH * 0.5, MARGIN, screen.x - BUBBLE_WIDTH - MARGIN), clampf(bubble_at.y - BUBBLE_ABOVE_PERSON - _bubble.size.y * 0.5, 64.0, screen.y - _bubble.size.y - MARGIN))


## Moves the timeline to a time, and shows which speed is in use.
func show_clock(time_steps: float, steps: int, speed: int) -> void:
	_setting_timeline = true
	_timeline.max_value = steps
	_timeline.value = time_steps
	_setting_timeline = false
	for index in _speed_buttons.size():
		_speed_buttons[index].button_pressed = index == speed


## Shows or hides the end-of-run summary.
func show_ending(text: String, is_visible_now: bool) -> void:
	_ending.visible = is_visible_now
	_ending_label.text = text


func _build_person_card(root: Control) -> void:
	var card := _panel(PANEL)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	_name_label = _label("", 18)
	column.add_child(_name_label)
	_clock_label = _label("", 15)
	column.add_child(_clock_label)
	var speeds := HBoxContainer.new()
	column.add_child(speeds)
	for choice: Array in [[0, "Pause"], [1, "Play"], [2, "Fast"], [3, "Faster"]]:
		speeds.add_child(_speed_button(choice[0], choice[1]))
	var next := Button.new()
	next.text = "Next person (Tab)"
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(func() -> void: next_person_chosen.emit())
	column.add_child(next)


func _speed_button(multiplier: int, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: speed_chosen.emit(multiplier))
	_speed_buttons.append(button)
	return button


func _build_needs(root: Control) -> void:
	var card := _panel(PANEL)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(card)
	var table := GridContainer.new()
	table.columns = 2
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 8)
	card.add_child(table)
	for need: String in NEEDS_SHOWN:
		table.add_child(_label(need.capitalize(), 15))
		_need_bars[need] = _bar()
		table.add_child(_need_bars[need])
	table.add_child(_label("Stress", 15))
	_stress_bar = _bar()
	_paint_bar(_stress_bar, BAD)
	table.add_child(_stress_bar)


func _build_action_card(root: Control) -> void:
	var card := _panel(PANEL)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	root.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	_action_label = _label("", 17)
	column.add_child(_action_label)
	_event_label = _label("", 14)
	_event_label.add_theme_color_override("font_color", MIDDLING)
	column.add_child(_event_label)


func _build_timeline(root: Control) -> void:
	_timeline = HSlider.new()
	_timeline.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
	_timeline.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timeline.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_timeline.custom_minimum_size = Vector2(520.0, 24.0)
	_timeline.step = 0.01
	_timeline.focus_mode = Control.FOCUS_NONE
	_timeline.value_changed.connect(func(value: float) -> void:
		if not _setting_timeline:
			time_chosen.emit(value))
	root.add_child(_timeline)


func _build_bubble(root: Control) -> void:
	_bubble = _panel(BUBBLE)
	_bubble.custom_minimum_size.x = BUBBLE_WIDTH
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_bubble.add_child(column)
	_reason_label = _label("", 14, INK_ON_BUBBLE)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.custom_minimum_size.x = BUBBLE_WIDTH - 2.0 * MARGIN
	column.add_child(_reason_label)
	_option_rows = VBoxContainer.new()
	_option_rows.add_theme_constant_override("separation", 2)
	column.add_child(_option_rows)


func _build_ending(root: Control) -> void:
	_ending = _panel(PANEL)
	_ending.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ending.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ending.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ending.visible = false
	root.add_child(_ending)
	_ending_label = _label("", 18)
	_ending.add_child(_ending_label)


func _show_need(bar: ProgressBar, value: float) -> void:
	bar.value = value
	_paint_bar(bar, GOOD if value > 0.6 else MIDDLING if value > 0.3 else BAD)


func _show_options(probs: Dictionary, chosen: String) -> void:
	for row in _option_rows.get_children():
		_option_rows.remove_child(row)
		row.queue_free()
	var names: Array = probs.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return float(probs[a]) > float(probs[b]))
	for option: String in names:
		var row := HBoxContainer.new()
		var title := _label(ACTION_NAMES.get(option, option), 12, INK_ON_BUBBLE)
		title.custom_minimum_size.x = 118.0
		row.add_child(title)
		var bar := _bar()
		bar.custom_minimum_size = Vector2(150.0, 11.0)
		bar.value = float(probs[option])
		_paint_bar(bar, CHOSEN if option == chosen else OTHER_OPTION)
		row.add_child(bar)
		row.add_child(_label("%d%%" % roundi(float(probs[option]) * 100.0), 12, INK_ON_BUBBLE))
		_option_rows.add_child(row)


func _panel(colour: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12.0)
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, size: int, colour: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(170.0, 16.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	back.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _paint_bar(bar: ProgressBar, colour: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
