extends Node
## Central registry of all unit types and their stats.
## Accessed globally as the `UnitDatabase` autoload singleton.

# Each unit is a dictionary of stats. Keys:
#   id              : String identifier
#   name            : Display name
#   cost            : Gold cost to deploy
#   max_health      : Hit points
#   move_speed      : Target horizontal speed (m/s)
#   mass            : Torso mass (affects knockback resistance)
#   attack_damage   : Damage per hit
#   attack_range    : Distance at which the unit can attack (m)
#   attack_cooldown : Seconds between attacks
#   knockback       : Impulse strength applied to victims
#   is_ranged       : If true, fires projectiles instead of melee
#   projectile_speed: Speed of fired projectile (ranged only)
#   aoe_radius      : Splash radius on impact (0 = single target)
#   scale           : Visual/physical size multiplier
#   accent          : Accent colour (Color) used for weapon/details
#   unlocked        : True if available from the start
#   description     : Short flavour / tip text

var _units: Dictionary = {}

func _ready() -> void:
	_register({
		"id": "peasant", "name": "Peasant", "cost": 50,
		"max_health": 60.0, "move_speed": 4.2, "mass": 2.6,
		"attack_damage": 12.0, "attack_range": 1.7, "attack_cooldown": 0.85,
		"knockback": 4.0, "is_ranged": false, "projectile_speed": 0.0,
		"aoe_radius": 0.0, "scale": 0.95, "accent": Color("#c8a06a"),
		"unlocked": true,
		"description": "Cheap cannon fodder. Wins through sheer numbers.",
	})
	_register({
		"id": "spearman", "name": "Spearman", "cost": 100,
		"max_health": 75.0, "move_speed": 3.7, "mass": 3.0,
		"attack_damage": 17.0, "attack_range": 2.8, "attack_cooldown": 1.0,
		"knockback": 6.0, "is_ranged": false, "projectile_speed": 0.0,
		"aoe_radius": 0.0, "scale": 1.0, "accent": Color("#b0bec5"),
		"unlocked": true,
		"description": "Long reach lets it poke enemies before they connect.",
	})
	_register({
		"id": "brawler", "name": "Brawler", "cost": 130,
		"max_health": 95.0, "move_speed": 5.4, "mass": 2.8,
		"attack_damage": 10.0, "attack_range": 1.6, "attack_cooldown": 0.38,
		"knockback": 5.0, "is_ranged": false, "projectile_speed": 0.0,
		"aoe_radius": 0.0, "scale": 0.95, "accent": Color("#ff8a65"),
		"unlocked": false,
		"description": "Fast attacker that staggers foes with rapid blows.",
	})
	_register({
		"id": "archer", "name": "Archer", "cost": 150,
		"max_health": 55.0, "move_speed": 3.9, "mass": 2.4,
		"attack_damage": 22.0, "attack_range": 16.0, "attack_cooldown": 1.5,
		"knockback": 3.0, "is_ranged": true, "projectile_speed": 26.0,
		"aoe_radius": 0.0, "scale": 0.95, "accent": Color("#aed581"),
		"unlocked": true,
		"description": "Fragile but deadly at range. Keep it behind a wall of melee.",
	})
	_register({
		"id": "knight", "name": "Knight", "cost": 280,
		"max_health": 240.0, "move_speed": 3.1, "mass": 5.5,
		"attack_damage": 24.0, "attack_range": 1.9, "attack_cooldown": 1.1,
		"knockback": 9.0, "is_ranged": false, "projectile_speed": 0.0,
		"aoe_radius": 0.0, "scale": 1.1, "accent": Color("#90a4ae"),
		"unlocked": false,
		"description": "Heavily armoured tank. Soaks damage and shrugs off knockback.",
	})
	_register({
		"id": "bomber", "name": "Bomber", "cost": 320,
		"max_health": 80.0, "move_speed": 3.4, "mass": 3.0,
		"attack_damage": 46.0, "attack_range": 12.0, "attack_cooldown": 2.3,
		"knockback": 14.0, "is_ranged": true, "projectile_speed": 18.0,
		"aoe_radius": 3.2, "scale": 1.0, "accent": Color("#ffd54f"),
		"unlocked": false,
		"description": "Lobs explosives that scatter whole clusters of enemies.",
	})
	_register({
		"id": "giant", "name": "Giant", "cost": 650,
		"max_health": 700.0, "move_speed": 2.4, "mass": 12.0,
		"attack_damage": 65.0, "attack_range": 2.6, "attack_cooldown": 1.7,
		"knockback": 30.0, "is_ranged": false, "projectile_speed": 0.0,
		"aoe_radius": 0.0, "scale": 1.9, "accent": Color("#a1887f"),
		"unlocked": false,
		"description": "A towering bruiser that flings whole squads into the air.",
	})

func _register(stats: Dictionary) -> void:
	_units[stats.id] = stats

func has_unit(id: String) -> bool:
	return _units.has(id)

func get_unit(id: String) -> Dictionary:
	return _units.get(id, {})

## Returns the ordered list of unit ids (cheapest first).
func get_all_ids() -> Array:
	var ids: Array = _units.keys()
	ids.sort_custom(func(a, b): return _units[a].cost < _units[b].cost)
	return ids

## Unit ids that should be available before any progression.
func get_default_unlocked() -> Array:
	var result: Array = []
	for id in _units:
		if _units[id].unlocked:
			result.append(id)
	return result
