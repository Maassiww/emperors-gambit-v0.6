class_name GameConfig
extends Resource
## All tunable match rules in one place (data/config.tres).

enum DrawMode { ALWAYS_WINNER, DRAW_SUDDEN_DEATH }

@export_group("Match")
@export var start_hp: int = 3
@export var moves_per_round: int = 3
@export var deck_size: int = 5
@export var offers_per_move: int = 3
@export var draw_mode: DrawMode = DrawMode.ALWAYS_WINNER
## DRAW_SUDDEN_DEATH only: after this many rounds higher HP wins, equal HP -> sudden death.
@export var max_rounds: int = 5

@export_group("Favor")
@export var favor_max: int = 100
@export var favor_per_hold: int = 20
## Winner gets this scaled by the fraction of army HP that survived.
@export var favor_win_max: int = 30
@export var favor_loss: int = 10
## Chance that an offer is tier 1+ = favor * this (favor 100 -> 80%).
@export var tier1_chance_per_favor: float = 0.008
## Chance that a tier 1+ offer becomes tier 2 (evolution) = (favor - threshold) * this.
@export var tier2_favor_threshold: int = 40
@export var tier2_chance_per_favor: float = 0.015
## Favor spent when picking an offer of tier 0 / 1 / 2.
@export var tier_cost: Array[int] = [0, 15, 30]
## Tier 1 "+X" offers give this many times the base amount.
@export var tier1_amount_mult: int = 2
@export var multiply_offer_chance: float = 0.3
## "2x" offers add at most this many basic picks worth of units.
@export var multiply_cap_picks: int = 3

@export_group("Evolution")
@export var evolution_bonus_pct: int = 25
@export var max_level: int = 3

@export_group("Battle")
@export var ticks_per_second: int = 20
@export var battle_max_seconds: float = 20.0
@export var arena_width: int = 720
@export var arena_height: int = 900
## Distance of each row from the center line, px: melee, ranged, special.
@export var row_distance: Array[int] = [70, 170, 270]
@export var row_line_spacing: int = 32
@export var units_per_line: int = 12
