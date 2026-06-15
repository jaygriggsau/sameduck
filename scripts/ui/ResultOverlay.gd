extends Control
## Post-battle overlay shown on top of the (frozen) arena: outcome, any newly
## unlocked unit, and navigation (retry / next / menu).

func _ready() -> void:
	UI.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UI.full_rect(dim)
	add_child(dim)

	var center := CenterContainer.new()
	UI.full_rect(center)
	add_child(center)

	var panel := UI.panel(Color(0.10, 0.12, 0.16, 0.96))
	center.add_child(panel)

	var col := UI.center_column(14)
	panel.add_child(col)

	var won := GameManager.last_result_won
	var title := UI.title("VICTORY!" if won else "DEFEAT")
	title.add_theme_color_override("font_color", Color("#7bd88f") if won else Color("#ff7b7b"))
	col.add_child(title)

	if GameManager.mode == GameManager.Mode.CAMPAIGN:
		var lvl := LevelDatabase.get_level(GameManager.current_level_id)
		col.add_child(_centered(UI.label(lvl.get("name", ""), 20, Color("#9fb4cf"))))

	if won and GameManager.newly_unlocked != "":
		var u := UnitDatabase.get_unit(GameManager.newly_unlocked)
		var unlock := UI.label("✦ Unlocked new unit: %s ✦" % u.name, 20, Color("#ffd34f"))
		col.add_child(_centered(unlock))

	col.add_child(_spacer(10))

	var retry := UI.button("Retry")
	retry.pressed.connect(GameManager.retry)
	col.add_child(retry)

	if won and GameManager.has_next_level():
		var next := UI.button("Next Battle")
		next.pressed.connect(GameManager.go_to_next_level)
		col.add_child(next)

	var menu := UI.button("Main Menu")
	menu.pressed.connect(GameManager.go_to_menu)
	col.add_child(menu)

func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
