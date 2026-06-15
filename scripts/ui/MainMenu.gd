extends Control
## Title screen: Campaign, Sandbox, reset progress, quit.

func _ready() -> void:
	UI.full_rect(self)
	add_child(UI.backdrop(Color(0.07, 0.09, 0.13, 1.0)))

	var center := CenterContainer.new()
	UI.full_rect(center)
	add_child(center)

	var col := UI.center_column(16)
	center.add_child(col)

	col.add_child(UI.title("SAMEDUCK"))
	var subtitle := UI.label("Battle Simulator", 22, Color("#9fb4cf"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	col.add_child(_spacer(20))

	var campaign := UI.button("Campaign")
	campaign.pressed.connect(GameManager.open_level_select)
	col.add_child(campaign)

	var sandbox := UI.button("Sandbox")
	sandbox.pressed.connect(GameManager.start_sandbox)
	col.add_child(sandbox)

	var reset := UI.button("Reset Progress")
	reset.pressed.connect(_on_reset)
	col.add_child(reset)

	var quit := UI.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)

	col.add_child(_spacer(16))
	var hint := UI.label("Camera: WASD/arrows pan · Q/E rotate · mouse wheel zoom", 14, Color("#6f819b"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

func _on_reset() -> void:
	SaveManager.reset_progress()

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
