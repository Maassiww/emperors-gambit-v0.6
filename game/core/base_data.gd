class_name BaseData
extends Resource
## A player's base: faction passive (own-faction units only) + battle ability (whole army).

enum Passive { NONE, ARMOR_BONUS, RAGE_ON_ALLY_DEATH }
enum Ability { NONE, RALLY_BANNER, WAR_DRUMS }

@export var id: StringName
@export var display_name: String
## One-line description for the base picker.
@export var blurb: String
@export var faction: StringName
@export var passive: Passive
## ARMOR_BONUS: +armor. RAGE_ON_ALLY_DEATH: max stacks (each +rage_pct_per_stack damage).
@export var passive_value: int = 0
@export var rage_pct_per_stack: int = 3
@export var ability: Ability
## RALLY_BANNER: attack speed bonus %. WAR_DRUMS: move speed bonus % (attack speed gets half).
@export var ability_power: int = 0
@export var ability_duration: float = 4.0
## RALLY_BANNER triggers when army HP drops below this % of its starting HP.
@export var ability_trigger_hp_pct: int = 70
