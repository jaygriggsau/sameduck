extends Node
## Campaign level definitions. Accessed as the `LevelDatabase` autoload.
##
## Each level is a dictionary:
##   id           : unique String
##   name         : display name
##   budget       : gold the player may spend deploying their army
##   enemies      : Array of { "unit": id, "count": int } describing the
##                  enemy army that is auto-deployed on the far side
##   reward       : unit id unlocked on victory ("" = no unlock)
##   description  : flavour / hint

var _levels: Array = []

func _ready() -> void:
	_levels = [
		{
			"id": "lvl_01", "name": "First Blood", "budget": 250,
			"enemies": [{"unit": "peasant", "count": 4}],
			"reward": "brawler",
			"description": "A loose mob of peasants. Outnumber them.",
		},
		{
			"id": "lvl_02", "name": "Pointy Sticks", "budget": 400,
			"enemies": [{"unit": "peasant", "count": 3}, {"unit": "spearman", "count": 2}],
			"reward": "knight",
			"description": "Spears outrange your fists. Bring your own reach.",
		},
		{
			"id": "lvl_03", "name": "Arrow Storm", "budget": 600,
			"enemies": [{"unit": "spearman", "count": 3}, {"unit": "archer", "count": 3}],
			"reward": "bomber",
			"description": "Archers shred from afar. Close the distance fast.",
		},
		{
			"id": "lvl_04", "name": "The Iron Wall", "budget": 900,
			"enemies": [{"unit": "knight", "count": 3}, {"unit": "archer", "count": 4}],
			"reward": "giant",
			"description": "Armoured knights anchor a deadly firing line.",
		},
		{
			"id": "lvl_05", "name": "Boom Town", "budget": 1300,
			"enemies": [{"unit": "knight", "count": 4}, {"unit": "bomber", "count": 3}, {"unit": "spearman", "count": 4}],
			"reward": "",
			"description": "Explosives will scatter your ranks. Spread out.",
		},
		{
			"id": "lvl_06", "name": "The Colossus", "budget": 2000,
			"enemies": [{"unit": "giant", "count": 1}, {"unit": "knight", "count": 4}, {"unit": "archer", "count": 6}],
			"reward": "",
			"description": "A giant leads the final host. Bring everything.",
		},
	]

func get_levels() -> Array:
	return _levels

func count() -> int:
	return _levels.size()

func get_level(id: String) -> Dictionary:
	for lvl in _levels:
		if lvl.id == id:
			return lvl
	return {}

func get_level_index(id: String) -> int:
	for i in _levels.size():
		if _levels[i].id == id:
			return i
	return -1

func get_next_level_id(id: String) -> String:
	var idx := get_level_index(id)
	if idx >= 0 and idx + 1 < _levels.size():
		return _levels[idx + 1].id
	return ""
