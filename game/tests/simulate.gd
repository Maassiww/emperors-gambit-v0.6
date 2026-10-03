extends SceneTree
## Bot vs bot balance report + one readable match log.
## godot --headless --path game --script res://tests/simulate.gd -- [matches=500] [seed=1] [log] [arch] [noreport]
## arch: also a round robin of Bot.PRESETS (matches / 30 per pairing and seat).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 500
	var seed_value := int(args[1]) if args.size() > 1 else 1
	GameDB.ensure_loaded()
	if "log" in args:
		_print_match_log(seed_value)
	if not "noreport" in args:
		_report(n, seed_value)
	if "arch" in args:
		_archetypes(maxi(1, n / 30), seed_value)
	quit(0)


func _random_setup(rng: RandomNumberGenerator) -> Dictionary:
	var bases := GameDB.base_ids_sorted()
	var decks := []
	var base_ids: Array[StringName] = []
	for p in 2:
		decks.append(Bot.random_deck(rng))
		base_ids.append(bases[rng.randi_range(0, bases.size() - 1)])
	return {"decks": decks, "bases": base_ids}


## "czysta", "czysta+N", "mix", "mix+N" (N = neutral card in deck).
static func deck_kind(deck: Array) -> String:
	var factions := {}
	var neutral := false
	for id in deck:
		var f := GameDB.unit(id).faction
		if f == UnitData.NEUTRAL:
			neutral = true
		else:
			factions[f] = true
	return ("czysta" if factions.size() <= 1 else "mix") + ("+N" if neutral else "")


func _play(m: Match, bots: Array) -> void:
	while m.phase != Match.Phase.FINISHED:
		while m.phase == Match.Phase.DRAFT:
			for p in 2:
				if m.moves_left(p) > 0:
					m.submit(p, bots[p].choose(m.view_for(p)))
		m.play_battle()


func _report(n: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base_games := {}
	var base_wins := {}
	var unit_games := {}
	var unit_wins := {}
	var rounds_sum := 0
	var seconds_sum := 0.0
	var battles := 0
	var timeouts := 0
	var holds := 0
	var evolutions := 0
	var kind_games := {}
	var kind_wins := {}
	for i in n:
		var setup := _random_setup(rng)
		var m := Match.new(setup.decks, setup.bases, seed_value * 100000 + i)
		_play(m, [Bot.new(i * 2 + 1), Bot.new(i * 2 + 2)])
		rounds_sum += m.round_number
		for h in m.history:
			battles += 1
			seconds_sum += h.seconds
			if h.outcome != BattleSim.Outcome.ELIMINATION:
				timeouts += 1
			for p in 2:
				for pick in h.picks[p]:
					if pick.begins_with("GAMBIT"):
						holds += 1
					elif pick.begins_with("Ewolucja"):
						evolutions += 1
		for p in 2:
			var won := 1 if m.winner == p else 0
			var b: StringName = setup.bases[p]
			if setup.bases[0] == setup.bases[1]:
				continue
			base_games[b] = base_games.get(b, 0) + 1
			base_wins[b] = base_wins.get(b, 0) + won
		for p in 2:
			var won := 1 if m.winner == p else 0
			var k := deck_kind(setup.decks[p])
			if k != deck_kind(setup.decks[1 - p]):
				kind_games[k] = kind_games.get(k, 0) + 1
				kind_wins[k] = kind_wins.get(k, 0) + won
			for id in setup.decks[p]:
				unit_games[id] = unit_games.get(id, 0) + 1
				unit_wins[id] = unit_wins.get(id, 0) + won
	print("=== RAPORT BALANSU: %d meczow bot vs bot ===" % n)
	print("Srednio rund na mecz: %.2f | srednia walka: %.1f s | walki bez eliminacji (czas): %d%%" % [
		float(rounds_sum) / n, seconds_sum / battles, roundi(100.0 * timeouts / battles)])
	print("Gambity na mecz: %.2f | ewolucje na mecz: %.2f" % [float(holds) / n, float(evolutions) / n])
	print("Bazy (tylko mecze rozne bazy):")
	for b in GameDB.base_ids_sorted():
		if base_games.get(b, 0) > 0:
			print("  %-20s %5.1f%% wygranych" % [GameDB.base(b).display_name, 100.0 * base_wins[b] / base_games[b]])
	print("Typ decku (tylko mecze roznych typow):")
	for k in ["czysta", "czysta+N", "mix", "mix+N"]:
		if kind_games.get(k, 0) > 0:
			print("  %-10s %5.1f%% (%d gier)" % [k, 100.0 * kind_wins[k] / kind_games[k], kind_games[k]])
	print("Jednostki (winrate gdy w decku):")
	for id in GameDB.card_ids_sorted():
		if unit_games.get(id, 0) > 0:
			var u := GameDB.unit(id)
			print("  %-14s %-7s %5.1f%% (%d)" % [u.display_name, u.faction, 100.0 * unit_wins[id] / unit_games[id], unit_games[id]])


## Round robin between Bot.PRESETS, both seats.
func _archetypes(n: int, seed_value: int) -> void:
	var presets := Bot.PRESETS
	var wins := {}
	var games := {}
	var i := 0
	for a in presets.size():
		for b in presets.size():
			if a == b:
				continue
			for k in n:
				var bases: Array[StringName] = [presets[a].base, presets[b].base]
				var m := Match.new([presets[a].deck, presets[b].deck], bases, seed_value * 100000 + i)
				_play(m, [Bot.new(i * 2 + 1), Bot.new(i * 2 + 2)])
				i += 1
				for p in 2:
					var name: String = presets[[a, b][p]].name
					games[name] = games.get(name, 0) + 1
					wins[name] = wins.get(name, 0) + (1 if m.winner == p else 0)
	print("Archetypy (kazdy z kazdym, %d meczow na pare i strone):" % n)
	for p in presets:
		print("  %-18s %5.1f%%" % [p.name, 100.0 * wins[p.name] / games[p.name]])


func _print_match_log(seed_value: int) -> void:
	var decks := [
		[&"bastion", &"szturmowiec", &"strzelec", &"lancer", &"medyk"],
		[&"pancerniak", &"szaleniec", &"siekacz", &"rakieciarz", &"lotniak"],
	]
	var bases: Array[StringName] = [&"citadel", &"war_camp"]
	var m := Match.new(decks, bases, seed_value)
	_play(m, [Bot.new(seed_value), Bot.new(seed_value + 1)])
	var names := ["Gracz A (Ludzie)", "Gracz B (Orkowie)"]
	print("=== PRZYKLADOWY MECZ (seed %d) ===" % seed_value)
	for h in m.history:
		print("-- Runda %d --" % h.round)
		for p in 2:
			print("  %s wybral: %s" % [names[p], " | ".join(h.picks[p])])
			print("    armia: %s" % h.armies[p])
		var outcome: String = ["eliminacja", "wiecej HP", "wiecej obrazen", "losowanie"][h.outcome]
		print("  Walka %.1f s -> wygrywa %s (%s). HP: %d - %d, laska: %d - %d" % [
			h.seconds, names[h.winner], outcome, h.hp[0], h.hp[1], h.favor[0], h.favor[1]])
	print("ZWYCIEZCA: %s\n" % names[m.winner])
