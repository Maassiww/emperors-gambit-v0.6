class_name Bot
extends RefCounted
## Simple heuristic opponent. Sees only Match.view_for(), exactly like a human player.

## 0 = always the best-scored option, higher = more random.
var noise := 0.15
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0, p_noise: float = 0.15) -> void:
	rng.seed = seed_value
	noise = p_noise


## Returns an offer index or Match.HOLD.
func choose(view: Dictionary) -> int:
	var me: Dictionary = view.me
	var opp: Dictionary = view.opponent
	var offers: Array = me.offers
	if _should_hold(view):
		return Match.HOLD
	var best := 0
	var best_score := -INF
	for i in offers.size():
		var score := _score(offers[i], me.army, opp.army) * (1.0 + rng.randf_range(-noise, noise))
		if score > best_score:
			best = i
			best_score = score
	return best


func _should_hold(view: Dictionary) -> bool:
	var me: Dictionary = view.me
	var opp: Dictionary = view.opponent
	var cfg := GameDB.config
	if me.favor >= cfg.favor_max - cfg.favor_per_hold / 2:
		return false
	var mine: float = (me.army as Army).power()
	var theirs: float = (opp.army as Army).power()
	# Comfortable lead (in HP or known strength): invest in favor.
	if me.hp > opp.hp and mine > theirs * 1.3 and rng.randf() < 0.5:
		return true
	return view.round > 1 and mine > theirs * 1.6 and rng.randf() < 0.3


func _score(offer: DraftOffer, army: Army, opp_army: Army) -> float:
	var data := GameDB.unit(army.resolve(offer.unit_id))
	var value: float
	if offer.kind == DraftOffer.Kind.EVOLVE:
		value = army.count(offer.unit_id) * (GameDB.unit(data.evolves_to).power() - data.power())
	else:
		value = offer.amount * data.power()
	return value * _counter_factor(data, opp_army)


## Bonus for units that counter what the opponent showed at the last reveal.
func _counter_factor(data: UnitData, opp: Army) -> float:
	var total := opp.total()
	if total == 0:
		return 1.0
	var flyers := 0
	var armor_sum := 0
	for id in opp.counts:
		var u := GameDB.unit(id)
		armor_sum += u.armor * opp.counts[id]
		if u.is_flying():
			flyers += opp.counts[id]
	var flyer_share := float(flyers) / total
	var avg_armor := float(armor_sum) / total
	var f := 1.0
	if data.armor_pierce:
		f *= 1.0 + avg_armor / 8.0
	if data.role == UnitData.Role.RAPID and avg_armor > 4.0:
		f *= 0.7
	if data.splash_radius > 0:
		f *= 1.0 + minf(total, 30) / 60.0
	if data.can_hit_air():
		f *= 1.0 + 0.5 * flyer_share
	elif flyer_share > 0.4:
		f *= 0.6
	return f
