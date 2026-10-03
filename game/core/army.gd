class_name Army
extends RefCounted
## One player's unit counts. Persists for the whole match.
## Cards are keyed by base unit id; after an evolution the card adds the evolved form.

var counts: Dictionary[StringName, int] = {}
## Base unit id -> evolved unit id.
var evolved: Dictionary[StringName, StringName] = {}


## The unit a card currently produces (evolved form if the card evolved).
func resolve(card_id: StringName) -> StringName:
	return evolved.get(card_id, card_id)


func count(card_id: StringName) -> int:
	return counts.get(resolve(card_id), 0)


func add(card_id: StringName, amount: int) -> void:
	var id := resolve(card_id)
	counts[id] = counts.get(id, 0) + amount


func can_evolve(card_id: StringName) -> bool:
	return not evolved.has(card_id) and count(card_id) > 0 and GameDB.unit(card_id).evolves_to != &""


## Turns every unit of this card into its evolved form.
func evolve(card_id: StringName) -> void:
	var to := GameDB.unit(card_id).evolves_to
	var n: int = counts.get(card_id, 0)
	counts.erase(card_id)
	evolved[card_id] = to
	counts[to] = counts.get(to, 0) + n


func total() -> int:
	var sum := 0
	for n in counts.values():
		sum += n
	return sum


## Stable order independent of insertion (StringName order is not portable).
func ids_sorted() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(counts.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func copy() -> Army:
	var a := Army.new()
	a.counts = counts.duplicate()
	a.evolved = evolved.duplicate()
	return a


func power() -> float:
	var sum := 0.0
	for id in counts:
		sum += counts[id] * GameDB.unit(id).power()
	return sum


func describe() -> String:
	var parts: Array[String] = []
	for id in ids_sorted():
		parts.append("%dx %s" % [counts[id], GameDB.unit(id).display_name])
	return ", ".join(parts) if not parts.is_empty() else "(pusto)"
