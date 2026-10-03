class_name GameDB
extends RefCounted
## Loads unit, faction and base definitions from res://data once.

const UNITS_DIR := "res://data/units/"
const FACTIONS_DIR := "res://data/factions/"
const BASES_DIR := "res://data/bases/"
const CONFIG_PATH := "res://data/config.tres"

static var units: Dictionary[StringName, UnitData] = {}
static var factions: Dictionary[StringName, FactionData] = {}
static var bases: Dictionary[StringName, BaseData] = {}
static var config: GameConfig


static func ensure_loaded() -> void:
	if config != null:
		return
	for res in _load_dir(UNITS_DIR):
		units[res.id] = res
	for res in _load_dir(FACTIONS_DIR):
		factions[res.id] = res
	for res in _load_dir(BASES_DIR):
		bases[res.id] = res
	config = load(CONFIG_PATH)


static func unit(id: StringName) -> UnitData:
	ensure_loaded()
	return units[id]


static func base(id: StringName) -> BaseData:
	ensure_loaded()
	return bases[id]


static func faction(id: StringName) -> FactionData:
	ensure_loaded()
	return factions[id]


static func unit_ids_sorted() -> Array[StringName]:
	ensure_loaded()
	var ids: Array[StringName] = []
	ids.assign(units.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Units that can be put in a deck (evolved forms are excluded).
static func card_ids_sorted() -> Array[StringName]:
	return unit_ids_sorted().filter(func(id: StringName) -> bool: return not units[id].is_evolution)


static func base_ids_sorted() -> Array[StringName]:
	ensure_loaded()
	var ids: Array[StringName] = []
	ids.assign(bases.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


static func _load_dir(dir: String) -> Array:
	var out := []
	var files := Array(ResourceLoader.list_directory(dir))
	files.sort()
	for f in files:
		if f.ends_with(".tres") or f.ends_with(".res"):
			out.append(load(dir + f))
	return out
