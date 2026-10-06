class_name UnitData
extends Resource
## Static definition of one unit card.
## Designer units: px, px/s and seconds. BattleSim converts them to ticks.

enum UnitClass { MELEE, RANGED, SPECIAL }
enum Role { HEAVY, LIGHT, RAPID, SLOW, FLYER, SUPPORT, SPECIAL }

const NEUTRAL := &"neutral"
const ROLE_NAMES := ["ciężkie melee", "lekkie melee", "szybki range", "ciężki range", "special · latający",
	"special · wsparcie", "special"]

@export var id: StringName
@export var display_name: String
## Faction id, or NEUTRAL for colorless units.
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
## Cannot hit flyers even though it is not melee (e.g. a running bomb).
@export var ground_only: bool = false
@export var traits: Array[TraitData] = []
## Exact rules in a few short sentences (deck screen).
@export var blurb: String
## At-a-glance role tags for the in-match card, e.g. "Tank · Prowokacja · Tarcza".
@export var tags: String
## Letter drawn on the placeholder sprite of specials and summons.
@export var glyph: String
## Bot/report estimate of what the traits are worth on top of raw stats.
@export var power_bonus: float = 1.0
## Evolved form this unit turns into (empty = none).
@export var evolves_to: StringName
## True for evolved forms: never drafted directly, only reached by evolution.
@export var is_evolution: bool = false
## True for units created during battle (turrets): never drafted.
@export var is_summon: bool = false


func is_flying() -> bool:
	return role == Role.FLYER


func is_special() -> bool:
	return unit_class == UnitClass.SPECIAL


func is_card() -> bool:
	return not is_evolution and not is_summon


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
	return (unit_class != UnitClass.MELEE or is_flying()) and not ground_only


func get_trait(kind: TraitData.Kind) -> TraitData:
	for t in traits:
		if t.kind == kind:
			return t
	return null


## Damage multiplier of an armor value (percent of damage that gets through).
static func armor_pass_pct(armor_value: int, cfg: GameConfig) -> int:
	return 100 - clampi(armor_value * cfg.armor_pct_per_point, 0, cfg.armor_max_reduction_pct)


## Rough per-unit strength, used by the bot and for balance reports.
func power() -> float:
	var effective_hp := hp * 100.0 / armor_pass_pct(armor, GameDB.config)
	var dps := damage / attack_interval
	return sqrt(effective_hp * dps) * power_bonus
