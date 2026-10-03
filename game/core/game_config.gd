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
## Seconds per draft move before the first option is picked automatically.
@export var move_time_seconds: float = 15.0
## Deck building: at most this many special cards in a deck.
@export var max_specials_in_deck: int = 2

@export_group("Hand")
## Cards drawn from the deck for each move (all of them if the deck is smaller).
@export var hand_size: int = 3

@export_group("Favor")
## Favor carries over between rounds and is spent only by playing a highlighted card.
@export var favor_max: int = 100
@export var favor_per_hold: int = 20
## Winner gets this scaled by the fraction of army HP that survived.
@export var favor_win_max: int = 30
@export var favor_loss: int = 10
## At most one card per hand is special. With favor >= bless_cost one card is blessed
## (x units) with chance favor / favor_max. At full favor one card is an evolution instead.
@export var bless_cost: int = 50
@export var bless_unit_mult: int = 2

@export_group("Battle")
@export var ticks_per_second: int = 20
## Each armor point blocks this % of damage, up to armor_max_reduction_pct.
@export var armor_pct_per_point: int = 6
@export var armor_max_reduction_pct: int = 60
## Corrosion: -1 armor per stack.
@export var corrosion_max_stacks: int = 3
## After a stun ends the unit cannot be stunned again for this long (no stun chains).
@export var stun_immunity_seconds: float = 2.0
## Healing received by units with Taunt (stops taunt + heal walls).
@export var taunt_heal_pct: int = 50
## After this, overtime: all damage grows every second so the battle always ends.
@export var overtime_after_seconds: float = 20.0
@export var overtime_damage_pct_per_second: int = 25
## Safety cap; reached only if healing outpaces overtime. Decided by army HP.
@export var battle_max_seconds: float = 90.0
@export var arena_width: int = 720
@export var arena_height: int = 880
## Formation: first row this far from the center line, rows stacked behind it.
@export var first_row_distance: int = 60
@export var row_line_spacing: int = 28
@export var row_gap: int = 16
@export var units_per_line: int = 12
