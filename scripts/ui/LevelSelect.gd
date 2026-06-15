extends Control
## Campaign level select. Lists levels with lock/complete status; locked
## levels (previous not yet beaten) cannot be played.

func _ready() -> void:
	UI.full_rect(self)
	add_child(UI.backdrop(Color(0.07, 0.09, 0.13, 1.0)))

	var margin := MarginContainer.new()
	UI.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(UI.title("Campaign"))
	col.add_child(UI.label("Beat each battle to unlock the next — and new units.", 16, Color("#9fb4cf")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for lvl in LevelDatabase.get_levels():
		list.add_child(_level_row(lvl))

	var back := UI.button("Back")
	back.pressed.connect(GameManager.go_to_menu)
	col.add_child(back)

func _level_row(lvl: Dictionary) -> Control:
	var unlocked := SaveManager.is_level_unlocked(lvl.id)
	var completed := SaveManager.is_level_completed(lvl.id)

	var panel := UI.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var status := "✓ Cleared" if completed else ("Locked" if not unlocked else "Available")
	var status_col := Color("#7bd88f") if completed else (Color("#8693a8") if not unlocked else Color("#ffd34f"))
	info.add_child(UI.label("%s   [%s]" % [lvl.name, status], 22, status_col))
	info.add_child(UI.label(lvl.description, 15, Color("#b8c4d6")))

	var reward: String = lvl.get("reward", "")
	var reward_txt := "Budget: %d gold" % lvl.budget
	if reward != "" and UnitDatabase.has_unit(reward):
		reward_txt += "   ·   Reward: unlock %s" % UnitDatabase.get_unit(reward).name
	info.add_child(UI.label(reward_txt, 14, Color("#8aa0bf")))

	var play := UI.button("Play", 130, 48)
	play.disabled = not unlocked
	play.pressed.connect(func(): GameManager.start_level(lvl.id))
	row.add_child(play)

	return panel
