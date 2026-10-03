class_name Match
extends RefCounted
## Full match state machine: draft moves (with Gambit holds), battles, HP, favor, fog of war.
## Pure logic: the UI, the bot and (later) the PvP server all drive it through the same API.

enum Phase { DRAFT, BATTLE, FINISHED }

const HOLD := -1


class PlayerState:
	var deck: Array[StringName] = []
	var base: BaseData
	var army := Army.new()
	var hp: int
	var favor := 0
	var moves_done := 0
	var holds_this_round := 0
	var offers: Array[DraftOffer] = []
	var rng := RandomNumberGenerator.new()
	var picks_this_round: Array[String] = []


var cfg: GameConfig
var players: Array[PlayerState] = []
var round_number := 1
var phase := Phase.DRAFT
var winner := -1
var sudden_death := false
var last_result: BattleSim.Result
## Per round: {round, picks: [[..],[..]], armies: [str, str], winner, outcome, draw, hp: [a, b]}
var history: Array[Dictionary] = []

## What each player knows about the other: army and favor as of the last reveal.
var _known_army: Array[Army] = [Army.new(), Army.new()]
var _known_favor: Array[int] = [0, 0]
var _battle_rng := RandomNumberGenerator.new()


func _init(decks: Array, base_ids: Array[StringName], seed_value: int, config: GameConfig = null) -> void:
	GameDB.ensure_loaded()
	cfg = config if config != null else GameDB.config
	_battle_rng.seed = seed_value
	for p in 2:
		var ps := PlayerState.new()
		ps.deck.assign(decks[p])
		ps.base = GameDB.base(base_ids[p])
		ps.hp = cfg.start_hp
		# Separate draft streams: a player's offers never depend on the opponent's timing.
		ps.rng.seed = seed_value * 2654435761 + p + 1
		players.append(ps)
		_refresh_offers(p)


func offers(p: int) -> Array[DraftOffer]:
	return players[p].offers


func moves_left(p: int) -> int:
	return cfg.moves_per_round - players[p].moves_done


## choice = index into offers(p), or HOLD (Gambit: skip the move, gain favor).
func submit(p: int, choice: int) -> bool:
	var ps := players[p]
	if phase != Phase.DRAFT or ps.moves_done >= cfg.moves_per_round:
		return false
	if choice == HOLD:
		ps.favor = mini(cfg.favor_max, ps.favor + cfg.favor_per_hold)
		ps.holds_this_round += 1
		ps.picks_this_round.append("GAMBIT (wstrzymanie)")
	elif choice >= 0 and choice < ps.offers.size():
		var offer := ps.offers[choice]
		offer.apply(ps.army)
		ps.favor = maxi(0, ps.favor - offer.favor_cost(cfg))
		ps.picks_this_round.append(offer.label())
	else:
		return false
	ps.moves_done += 1
	if ps.moves_done < cfg.moves_per_round:
		_refresh_offers(p)
	else:
		ps.offers.clear()
	if players[0].moves_done >= cfg.moves_per_round and players[1].moves_done >= cfg.moves_per_round:
		phase = Phase.BATTLE
	return true


## Reveal: the fog lifts and the battle starts. The UI steps it; the bot/server can just run() it.
func create_battle() -> BattleSim:
	assert(phase == Phase.BATTLE)
	var armies: Array[Army] = [players[0].army, players[1].army]
	var bases: Array[BaseData] = [players[0].base, players[1].base]
	return BattleSim.new(armies, bases, cfg, _battle_rng)


func play_battle() -> BattleSim.Result:
	var result := create_battle().run()
	finish_round(result)
	return result


func finish_round(result: BattleSim.Result) -> void:
	assert(phase == Phase.BATTLE)
	last_result = result
	var is_draw := cfg.draw_mode == GameConfig.DrawMode.DRAW_SUDDEN_DEATH \
		and result.outcome in [BattleSim.Outcome.DAMAGE, BattleSim.Outcome.COIN]
	if not is_draw:
		var w := result.winner
		var l := 1 - w
		players[l].hp -= 1
		players[w].favor = mini(cfg.favor_max, players[w].favor + roundi(cfg.favor_win_max * result.hp_fraction(w)))
		players[l].favor = mini(cfg.favor_max, players[l].favor + cfg.favor_loss)
	history.append({
		"round": round_number,
		"picks": [players[0].picks_this_round.duplicate(), players[1].picks_this_round.duplicate()],
		"armies": [players[0].army.describe(), players[1].army.describe()],
		"winner": -1 if is_draw else result.winner,
		"outcome": result.outcome,
		"seconds": float(result.ticks) / cfg.ticks_per_second,
		"hp": [players[0].hp, players[1].hp],
		"favor": [players[0].favor, players[1].favor],
	})
	for p in 2:
		_known_army[p] = players[p].army.copy()
		_known_favor[p] = players[p].favor
	_check_match_end(is_draw, result)
	if phase == Phase.FINISHED:
		return
	round_number += 1
	phase = Phase.DRAFT
	for p in 2:
		var ps := players[p]
		ps.moves_done = 0
		ps.holds_this_round = 0
		ps.picks_this_round.clear()
		_refresh_offers(p)


## Fog of war: everything player p is allowed to see. The opponent's current draft is hidden.
func view_for(p: int) -> Dictionary:
	var me := players[p]
	var opp := players[1 - p]
	return {
		"round": round_number,
		"phase": phase,
		"sudden_death": sudden_death,
		"me": {
			"hp": me.hp,
			"favor": me.favor,
			"army": me.army.copy(),
			"deck": me.deck.duplicate(),
			"base": me.base.id,
			"moves_left": moves_left(p),
			"offers": me.offers.duplicate(),
		},
		"opponent": {
			"hp": opp.hp,
			"favor": _known_favor[1 - p],
			"army": _known_army[1 - p].copy(),
			"deck": opp.deck.duplicate(),
			"base": opp.base.id,
		},
	}


func _check_match_end(is_draw: bool, result: BattleSim.Result) -> void:
	for p in 2:
		if players[p].hp <= 0:
			_finish(1 - p)
			return
	if cfg.draw_mode != GameConfig.DrawMode.DRAW_SUDDEN_DEATH:
		return
	if sudden_death and not is_draw:
		_finish(result.winner)
	elif not sudden_death and round_number >= cfg.max_rounds:
		if players[0].hp != players[1].hp:
			_finish(0 if players[0].hp > players[1].hp else 1)
		else:
			sudden_death = true


func _finish(p: int) -> void:
	winner = p
	phase = Phase.FINISHED


func _refresh_offers(p: int) -> void:
	var ps := players[p]
	ps.offers = DraftOffer.generate(ps.deck, ps.army, ps.favor, cfg, ps.rng)
