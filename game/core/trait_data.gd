class_name TraitData
extends Resource
## One unit trait built from the shared effect vocabulary (docs/proposal-traits-bases-factions.md).
## BattleSim interprets the kind; the fields below are its parameters (unused ones stay 0).
## Distances in px, times in seconds, percentages as ints.

enum Kind {
	TAUNT,              ## enemies within radius must attack this unit (nearest taunter wins)
	TELEPORT_BACKLINE,  ## after delay jumps behind the rearmost enemy ranged/special unit
	EXECUTE,            ## +power% damage to targets below threshold_pct HP
	STUN_PULSE,         ## every period: stun (duration) + power damage to the densest enemy group within cast_range
	AURA,               ## allies within radius get the buff_* bonuses (the strongest aura of each stat counts)
	BUILD,              ## every period: summons `summon` at own position, at most max_count alive
	KAMIKAZE,           ## runs into the densest enemy group and explodes: power damage + stacks of corrosion in radius
	DEATH_BLAST,        ## on death: power damage to enemies within radius
	MARK_ON_HIT,        ## every hit marks the target: it takes +power% damage for duration
}

## AURA targets.
enum Affects { ALL, FACTION, MELEE }

@export var kind: Kind
## Short name shown in the UI.
@export var label: String
@export var radius: int = 0
@export var cast_range: int = 0
@export var power: int = 0
@export var threshold_pct: int = 0
@export var delay: float = 0.0
@export var period: float = 0.0
@export var duration: float = 0.0
@export var stacks: int = 0
@export var max_count: int = 0
@export var summon: StringName

@export_group("Aura")
@export var affects: Affects = Affects.ALL
@export var buff_damage_pct: int = 0
@export var buff_attack_speed_pct: int = 0
@export var buff_move_pct: int = 0
@export var buff_armor: int = 0
## Full strength with no foreign card types on the board, half with one, none with more.
@export var scales_with_purity: bool = false

@export_group("Contract")
## Active only when the owner's board has at least min_factions and fewer than max_factions
## distinct factions (neutral units do not count). Used by neutral units for levelled effects.
@export var min_factions: int = 0
@export var max_factions: int = 99


func active_for(factions_on_board: int) -> bool:
	return factions_on_board >= min_factions and factions_on_board < max_factions
