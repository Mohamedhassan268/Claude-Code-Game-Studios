class_name Playback
extends RefCounted
## The game clock, measured in simulation steps, with a pause and three speeds.

const MOST_SPEED := 3

var steps: int
var seconds_per_step: float
var speed := 1
var time_steps := 0.0


## Starts at the first step, at normal speed.
func _init(step_count: int, seconds_for_one_step: float) -> void:
	steps = step_count
	seconds_per_step = seconds_for_one_step


## Moves the clock on by real seconds. Stops at the end of the run.
func advance(delta: float) -> void:
	seek(time_steps + delta * speed / seconds_per_step)


## Jumps to a time, kept inside the run.
func seek(to_steps: float) -> void:
	time_steps = clampf(to_steps, 0.0, float(steps))


## Sets the speed: 0 is paused, and 1 to 3 are the speeds.
func set_speed(multiplier: int) -> void:
	speed = clampi(multiplier, 0, MOST_SPEED)


## The step being played. The last step stays current at the very end.
func step_index() -> int:
	return mini(int(floor(time_steps)), steps - 1)


## Whether the run has finished playing.
func is_finished() -> bool:
	return time_steps >= steps
