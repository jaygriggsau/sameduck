extends Node
## Handles persistence of player progression: unlocked units and completed
## levels. Stored as JSON in the user data directory. Accessed as the
## `SaveManager` autoload.

const SAVE_PATH := "user://savegame.json"

var unlocked_units: Array = []
var completed_levels: Array = []

func _ready() -> void:
	load_game()

func _default_state() -> void:
	unlocked_units = UnitDatabase.get_default_unlocked().duplicate()
	completed_levels = []

func load_game() -> void:
	_default_state()
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("unlocked_units"):
		for id in data.unlocked_units:
			if UnitDatabase.has_unit(id) and not unlocked_units.has(id):
				unlocked_units.append(id)
	if data.has("completed_levels"):
		completed_levels = data.completed_levels.duplicate()

func save_game() -> void:
	var data := {
		"unlocked_units": unlocked_units,
		"completed_levels": completed_levels,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: could not open save file for writing.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func is_unit_unlocked(id: String) -> bool:
	return unlocked_units.has(id)

## Returns true if this call newly unlocked the unit.
func unlock_unit(id: String) -> bool:
	if id == "" or not UnitDatabase.has_unit(id) or unlocked_units.has(id):
		return false
	unlocked_units.append(id)
	save_game()
	return true

func is_level_completed(id: String) -> bool:
	return completed_levels.has(id)

func complete_level(id: String) -> void:
	if id != "" and not completed_levels.has(id):
		completed_levels.append(id)
		save_game()

## A level is playable if it is the first, or the previous one is completed.
func is_level_unlocked(id: String) -> bool:
	var idx := LevelDatabase.get_level_index(id)
	if idx <= 0:
		return true
	var prev = LevelDatabase.get_levels()[idx - 1]
	return is_level_completed(prev.id)

func reset_progress() -> void:
	_default_state()
	save_game()
