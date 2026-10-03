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


func is_flying() -> bool:
	return role == Role.FLYER


func is_flanker() -> bool:
	return role == Role.LIGHT


func is_healer() -> bool:
	return role == Role.SUPPORT


func can_hit_air() -> bool:
	return unit_class != UnitClass.MELEE or is_flying()


## Rough per-unit strength, used by the bot and for balance reports.
func power(level: int = 1, evolution_bonus_pct: int = 25) -> float:
	var mult := 1.0 + evolution_bonus_pct / 100.0 * (level - 1)
	var effective_hp := hp * mult * (1.0 + armor * 0.08)
	var dps := damage * mult / attack_interval
	return sqrt(effective_hp * dps)
