extends Node
## Global game state machine. Holds the current high-level state and the
## context for the active battle (level / sandbox). Emits signals that the
## Main scene listens to in order to build the appropriate scene & UI.
## Accessed as the `GameManager` autoload.

enum State { MAIN_MENU, LEVEL_SELECT, PLACEMENT, BATTLE, RESULT }
enum Mode { CAMPAIGN, SANDBOX }
enum Team { A, B }  # A = player (blue), B = enemy (red)

signal state_changed(new_state: State)
signal battle_ended(player_won: bool)

var state: State = State.MAIN_MENU
var mode: Mode = Mode.CAMPAIGN
var current_level_id: String = ""
var last_result_won: bool = false
var newly_unlocked: String = ""  # set on victory if a unit was unlocked

func _ready() -> void:
	# Allow an automated headless smoke-test via: --autobattle
	if "--autobattle" in OS.get_cmdline_user_args():
		call_deferred("_run_autobattle")

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)

func go_to_menu() -> void:
	_set_state(State.MAIN_MENU)

func open_level_select() -> void:
	_set_state(State.LEVEL_SELECT)

## Begin a campaign battle for the given level id (enters placement phase).
func start_level(level_id: String) -> void:
	mode = Mode.CAMPAIGN
	current_level_id = level_id
	_set_state(State.PLACEMENT)

## Begin a free-form sandbox session (enters placement phase).
func start_sandbox() -> void:
	mode = Mode.SANDBOX
	current_level_id = ""
	_set_state(State.PLACEMENT)

## Transition from placement into the live battle simulation.
func begin_battle() -> void:
	if state == State.PLACEMENT:
		_set_state(State.BATTLE)

## Called by the Arena when one side has been wiped out.
func report_battle_result(player_won: bool) -> void:
	if state != State.BATTLE:
		return
	last_result_won = player_won
	newly_unlocked = ""
	if mode == Mode.CAMPAIGN and player_won and current_level_id != "":
		SaveManager.complete_level(current_level_id)
		var lvl := LevelDatabase.get_level(current_level_id)
		if lvl.has("reward") and lvl.reward != "":
			if SaveManager.unlock_unit(lvl.reward):
				newly_unlocked = lvl.reward
	_set_state(State.RESULT)
	battle_ended.emit(player_won)

## Replay the current placement/battle from scratch.
func retry() -> void:
	if mode == Mode.CAMPAIGN and current_level_id != "":
		start_level(current_level_id)
	else:
		start_sandbox()

func has_next_level() -> bool:
	return mode == Mode.CAMPAIGN and LevelDatabase.get_next_level_id(current_level_id) != ""

func go_to_next_level() -> void:
	var next_id := LevelDatabase.get_next_level_id(current_level_id)
	if next_id != "":
		start_level(next_id)

# --- Headless self-test ---------------------------------------------------
# Drives a full sandbox battle with no UI so the simulation can be validated
# headless: spawns two armies, starts the fight, prints the outcome and quits.
func _run_autobattle() -> void:
	print("[autobattle] starting sandbox smoke test")
	start_sandbox()
	await get_tree().create_timer(0.2).timeout
	var arena = get_tree().get_first_node_in_group("arena")
	if arena == null:
		print("[autobattle] ERROR: no arena found")
		get_tree().quit(1)
		return
	for i in 5:
		arena._spawn_unit("peasant", Team.A, Vector3(randf_range(-6, 6), 0, randf_range(3, 8)))
		arena._spawn_unit("archer", Team.B, Vector3(randf_range(-6, 6), 0, -randf_range(3, 8)))
	await get_tree().process_frame
	battle_ended.connect(func(won):
		print("[autobattle] battle ended, player_won=", won)
		await get_tree().create_timer(0.3).timeout
		get_tree().quit())
	begin_battle()
	await get_tree().create_timer(60.0).timeout
	print("[autobattle] ERROR: battle did not resolve (timeout)")
	get_tree().quit(1)
