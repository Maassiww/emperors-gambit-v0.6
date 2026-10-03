class_name Army
extends RefCounted
## One player's unit counts and evolution levels. Persists for the whole match.

var counts: Dictionary[StringName, int] = {}
var levels: Dictionary[StringName, int] = {}


func count(id: StringName) -> int:
	return counts.get(id, 0)


func level(id: StringName) -> int:
	return levels.get(id, 1)


func add(id: StringName, amount: int) -> void:
	counts[id] = count(id) + amount


func evolve(id: StringName) -> void:
	levels[id] = level(id) + 1


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
	a.levels = levels.duplicate()
	return a


func power(evolution_bonus_pct: int) -> float:
	var sum := 0.0
	for id in counts:
		sum += counts[id] * GameDB.unit(id).power(level(id), evolution_bonus_pct)
	return sum


func describe() -> String:
	var parts: Array[String] = []
	for id in ids_sorted():
		var lvl := level(id)
		parts.append("%dx %s%s" % [counts[id], GameDB.unit(id).display_name, "" if lvl == 1 else " (lvl %d)" % lvl])
	return ", ".join(parts) if not parts.is_empty() else "(pusto)"
