extends Control
## Minimal in-battle HUD: live army counts and a surrender button.
## Set `arena` before adding to the tree.

var arena: Arena
var _counts_label: Label

func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := UI.panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = 10
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)

	_counts_label = UI.label("", 22)
	row.add_child(_counts_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var menu := UI.button("Surrender", 140, 36)
	menu.pressed.connect(GameManager.go_to_menu)
	row.add_child(menu)

	if arena != null:
		arena.counts_changed.connect(_on_counts)
		_on_counts(arena._count_team("team_a"), arena._count_team("team_b"))

func _on_counts(a: int, b: int) -> void:
	_counts_label.text = "BLUE %d   vs   %d RED" % [a, b]
	_counts_label.add_theme_color_override("font_color", Color("#cfe0ff"))
