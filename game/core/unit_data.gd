class_name UnitData
extends Resource
## Static definition of one unit card.
## Designer units: px, px/s and seconds. BattleSim converts them to ticks.

enum UnitClass { MELEE, RANGED, SPECIAL }
enum Role { HEAVY, LIGHT, RAPID, SLOW, FLYER, SUPPORT }

@export var id: StringName
@export var display_name: String
@export var faction: StringName
@export var unit_class: UnitClass
@export var role: Role
## Units gained by a basic "+X" draft pick.
@export var count_per_pick: int = 1
@export var hp: int = 100
@export var armor: int = 0
## Damage per attack, or heal per cast for SUPPORT.
@export var damage: int = 10
@export var attack_interval: float = 1.0
@export var attack_range: int = 30
@export var speed: int = 50
@export var armor_pierce: bool = false
@export var splash_radius: int = 0
## Body radius in px: used for spacing in battle and for drawing.
@export var size: int = 10
## Ignores the front and goes for ranged/special units first (specials only, for now).
@export var targets_backline: bool = false
## Evolved form this unit turns into (empty = none).
@export var evolves_to: StringName
## True for evolved forms: never drafted directly, only reached by evolution.
@export var is_evolution: bool = false


func is_flying() -> bool:
	return role == Role.FLYER


## Formation row, front to back: heavy melee, light melee, rapid ranged, slow ranged, special.
func formation_row() -> int:
	match role:
		Role.HEAVY:
			return 0
		Role.LIGHT:
			return 1
		Role.RAPID:
			return 2
		Role.SLOW:
			return 3
	return 4


func is_healer() -> bool:
	return role == Role.SUPPORT


func can_hit_air() -> bool:
	return unit_class != UnitClass.MELEE or is_flying()


## Rough per-unit strength, used by the bot and for balance reports.
func power() -> float:
	var effective_hp := hp * (1.0 + armor * 0.08)
	var dps := damage / attack_interval
	return sqrt(effective_hp * dps)
