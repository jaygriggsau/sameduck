extends Node
## Entry point. Owns the scene tree and rebuilds the 3D Arena and UI overlays
## in response to GameManager state changes.

const MainMenu = preload("res://scripts/ui/MainMenu.gd")
const LevelSelect = preload("res://scripts/ui/LevelSelect.gd")
const PlacementHUD = preload("res://scripts/ui/PlacementHUD.gd")
const BattleHUD = preload("res://scripts/ui/BattleHUD.gd")
const ResultOverlay = preload("res://scripts/ui/ResultOverlay.gd")

var _ui_layer: CanvasLayer
var _world_root: Node3D
var _arena: Arena = null

func _ready() -> void:
	_world_root = Node3D.new()
	_world_root.name = "World"
	add_child(_world_root)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	add_child(_ui_layer)

	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)

func _on_state_changed(s: int) -> void:
	match s:
		GameManager.State.MAIN_MENU:
			_clear_arena()
			_set_ui(MainMenu.new())
		GameManager.State.LEVEL_SELECT:
			_clear_arena()
			_set_ui(LevelSelect.new())
		GameManager.State.PLACEMENT:
			_build_arena()
			var hud := PlacementHUD.new()
			hud.arena = _arena
			_set_ui(hud)
		GameManager.State.BATTLE:
			if _arena != null:
				_arena.start_battle()
			var bh := BattleHUD.new()
			bh.arena = _arena
			_set_ui(bh)
		GameManager.State.RESULT:
			# Keep the arena visible behind the result overlay.
			_set_ui(ResultOverlay.new())

func _set_ui(node: Control) -> void:
	for c in _ui_layer.get_children():
		c.queue_free()
	_ui_layer.add_child(node)

func _build_arena() -> void:
	_clear_arena()
	_arena = Arena.new()
	_world_root.add_child(_arena)
	if GameManager.mode == GameManager.Mode.CAMPAIGN:
		var lvl := LevelDatabase.get_level(GameManager.current_level_id)
		_arena.setup_campaign(lvl)
	else:
		_arena.setup_sandbox()

func _clear_arena() -> void:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
