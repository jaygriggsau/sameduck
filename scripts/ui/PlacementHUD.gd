extends Control
## Deployment-phase HUD: budget/team info, the unit palette, and battle
## controls. Set `arena` before adding to the tree.

var arena: Arena

var _budget_label: Label
var _palette_buttons: Dictionary = {}  # unit_id -> Button
var _selected_id: String = ""
var _team_button: Button
var _info_label: Label

func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks reach the 3D arena

	_build_top_bar()
	_build_palette()
	_build_bottom_bar()

	if arena != null:
		arena.budget_changed.connect(_on_budget_changed)
		_on_budget_changed(arena.budget_remaining)

	# Auto-select the first available unit.
	var ids := _available_unit_ids()
	if not ids.is_empty():
		_select_unit(ids[0])

func _available_unit_ids() -> Array:
	var result: Array = []
	for id in UnitDatabase.get_all_ids():
		if SaveManager.is_unit_unlocked(id):
			result.append(id)
	return result

# --- Top bar (budget / team) ---------------------------------------------
func _build_top_bar() -> void:
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

	_budget_label = UI.label("", 22, Color("#ffd34f"))
	row.add_child(_budget_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	if arena != null and arena.mode == GameManager.Mode.SANDBOX:
		_team_button = UI.button("Placing: BLUE", 200, 36)
		_team_button.pressed.connect(_toggle_team)
		row.add_child(_team_button)

	_info_label = UI.label("Left-click deploy · Right-click remove", 15, Color("#9fb4cf"))
	row.add_child(_info_label)

# --- Unit palette ---------------------------------------------------------
func _build_palette() -> void:
	var panel := UI.panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 10
	panel.offset_top = 60
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(UI.label("UNITS", 16, Color("#9fb4cf")))

	for id in _available_unit_ids():
		var stats := UnitDatabase.get_unit(id)
		var b := UI.button("%s — %dg" % [stats.name, stats.cost], 200, 40)
		b.tooltip_text = stats.description
		b.pressed.connect(_select_unit.bind(id))
		_palette_buttons[id] = b
		col.add_child(b)

# --- Bottom controls ------------------------------------------------------
func _build_bottom_bar() -> void:
	var panel := UI.panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_bottom = -10

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var start := UI.button("⚔  START BATTLE", 240, 48)
	start.pressed.connect(_on_start)
	row.add_child(start)

	var clear := UI.button("Clear", 120, 48)
	clear.pressed.connect(_on_clear)
	row.add_child(clear)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var menu := UI.button("Menu", 120, 48)
	menu.pressed.connect(GameManager.go_to_menu)
	row.add_child(menu)

	add_child(panel)

# --- Logic ----------------------------------------------------------------
func _select_unit(id: String) -> void:
	_selected_id = id
	if arena != null:
		arena.set_selected_unit(id)
	for bid in _palette_buttons:
		var b: Button = _palette_buttons[bid]
		b.add_theme_color_override("font_color", UI.ACCENT if bid == id else Color.WHITE)

func _toggle_team() -> void:
	if arena == null:
		return
	if arena.sandbox_team == GameManager.Team.A:
		arena.set_sandbox_team(GameManager.Team.B)
		_team_button.text = "Placing: RED"
		_team_button.add_theme_color_override("font_color", Color("#ff7b7b"))
	else:
		arena.set_sandbox_team(GameManager.Team.A)
		_team_button.text = "Placing: BLUE"
		_team_button.add_theme_color_override("font_color", Color("#7bb0ff"))

func _on_budget_changed(remaining: int) -> void:
	if arena != null and arena.mode == GameManager.Mode.SANDBOX:
		_budget_label.text = "SANDBOX — unlimited"
	else:
		_budget_label.text = "Gold: %d" % remaining
	# Grey out unaffordable units in campaign.
	for id in _palette_buttons:
		var b: Button = _palette_buttons[id]
		var cost: int = UnitDatabase.get_unit(id).cost
		var affordable := (arena == null or arena.mode == GameManager.Mode.SANDBOX or cost <= remaining)
		b.modulate = Color.WHITE if affordable else Color(0.5, 0.5, 0.5)

func _on_clear() -> void:
	if arena == null:
		return
	for n in arena.get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null:
			continue
		# In campaign, only clear the player's own units (and refund).
		if arena.mode == GameManager.Mode.CAMPAIGN and u.team != GameManager.Team.A:
			continue
		if arena.mode == GameManager.Mode.CAMPAIGN:
			arena.budget_remaining += int(u.stats.get("cost", 0))
		u.queue_free()
	if arena.mode == GameManager.Mode.CAMPAIGN:
		arena.budget_changed.emit(arena.budget_remaining)

func _on_start() -> void:
	if arena == null:
		return
	if not arena.has_units(GameManager.Team.A):
		_flash("Deploy at least one unit first!")
		return
	if not arena.has_units(GameManager.Team.B):
		_flash("Add enemy (RED) units before starting!")
		return
	GameManager.begin_battle()

func _flash(msg: String) -> void:
	_info_label.text = msg
	_info_label.add_theme_color_override("font_color", Color("#ff7b7b"))
