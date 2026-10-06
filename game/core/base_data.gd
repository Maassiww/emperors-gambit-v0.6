class_name BaseData
extends Resource
## A player's base: passive (whole army, strength set by deck purity) + battle ability (whole army).

enum Passive { NONE, DAMAGE_REDUCTION, RAGE_ON_ALLY_DEATH }
enum Ability { NONE, RALLY_BANNER, WAR_DRUMS }

@export var id: StringName
@export var display_name: String
## One-line description for the base picker.
@export var blurb: String
@export var faction: StringName
@export var passive: Passive
## At full purity. DAMAGE_REDUCTION: -% damage taken. RAGE_ON_ALLY_DEATH: max stacks
## (every ally death: +1 stack, each +rage_pct_per_stack% damage).
@export var passive_value: int = 0
@export var rage_pct_per_stack: int = 3
@export var ability: Ability
## RALLY_BANNER: attack speed bonus %. WAR_DRUMS: move speed bonus % (attack speed gets half).
@export var ability_power: int = 0
@export var ability_duration: float = 4.0
## RALLY_BANNER triggers when army HP drops below this % of its starting HP.
@export var ability_trigger_hp_pct: int = 70


## Passive strength (%) for this deck: depends on how many cards are outside the base's faction.
func purity_pct(deck: Array, cfg: GameConfig) -> int:
	var foreign := 0
	for id in deck:
		if GameDB.unit(id).faction != faction:
			foreign += 1
	return cfg.purity_pct_by_foreign[foreign] if foreign < cfg.purity_pct_by_foreign.size() else 0


## Short text of the passive at a given strength, e.g. "−7% obrażeń" (deck screen, HUD).
func passive_text(pct: int) -> String:
	match passive:
		Passive.DAMAGE_REDUCTION:
			return "armia −%d%% otrzymywanych obrażeń" % (passive_value * pct / 100)
		Passive.RAGE_ON_ALLY_DEATH:
			return "szał: +%s%% obrażeń za poległego (maks. %d)" % [
				String.num(rage_pct_per_stack * pct / 100.0, 1), passive_value]
	return ""
