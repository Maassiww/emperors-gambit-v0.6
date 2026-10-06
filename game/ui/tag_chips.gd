class_name TagChips
extends HFlowContainer
## Unit tags as small coloured chips (in-match cards). Placeholder look: plain rounded boxes coloured by
## category. When the art is ready, swap _make_chip() for icons; callers only use set_tags().

enum Category { DEFENSE, ATTACK, CONTROL, SUPPORT, MOBILITY, MASS, NEUTRAL, WEAKNESS }

const COLORS := {
	Category.DEFENSE: Color(0.30, 0.48, 0.75),
	Category.ATTACK: Color(0.78, 0.35, 0.25),
	Category.CONTROL: Color(0.55, 0.38, 0.78),
	Category.SUPPORT: Color(0.30, 0.62, 0.40),
	Category.MOBILITY: Color(0.78, 0.62, 0.22),
	Category.MASS: Color(0.45, 0.55, 0.30),
	Category.NEUTRAL: Color(0.55, 0.50, 0.42),
	Category.WEAKNESS: Color(0.35, 0.35, 0.38),
}

const CATEGORY_OF := {
	"Tank": Category.DEFENSE, "Prowokacja": Category.DEFENSE, "Tarcza": Category.DEFENSE,
	"Obrona": Category.DEFENSE, "Wieżyczka": Category.DEFENSE,
	"Snajper": Category.ATTACK, "Przebija pancerz": Category.ATTACK, "Na tanki": Category.ATTACK,
	"Dobija": Category.ATTACK, "Obszar": Category.ATTACK, "Artyleria": Category.ATTACK,
	"Kamikaze": Category.ATTACK, "Losowy ogień": Category.ATTACK, "Ogień": Category.ATTACK,
	"Wybuch": Category.ATTACK, "Szybkostrzelny": Category.ATTACK, "Szał": Category.ATTACK,
	"Ogłuszenie": Category.CONTROL, "Spowalnia": Category.CONTROL, "Kontrola": Category.CONTROL,
	"Kruszy pancerz": Category.CONTROL, "Oznacza": Category.CONTROL,
	"Leczy": Category.SUPPORT, "Leczy ×2": Category.SUPPORT, "Wsparcie": Category.SUPPORT,
	"Aura": Category.SUPPORT, "Wzmacnia ludzi": Category.SUPPORT, "Wzmacnia orków": Category.SUPPORT,
	"Wzmacnia melee": Category.SUPPORT, "Tempo": Category.SUPPORT, "Pancerz": Category.SUPPORT,
	"Skok": Category.MOBILITY, "Teleport": Category.MOBILITY, "Lot": Category.MOBILITY,
	"Poluje na tyły": Category.MOBILITY, "Omija tanki": Category.MOBILITY, "Szybki": Category.MOBILITY,
	"Tyły": Category.MOBILITY,
	"Masa": Category.MASS, "Rośnie w tłumie": Category.MASS, "Przywołania": Category.MASS,
	"Wieżyczki": Category.MASS,
	"Bez frakcji": Category.NEUTRAL, "Kontrakt": Category.NEUTRAL,
	"Słaby na pancerz": Category.WEAKNESS,
}

@export var font_size: int = 11


func _init() -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## tags: "A · B · C", as in UnitData.tags.
func set_tags(tags: String) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for tag in tags.split(" · ", false):
		add_child(_make_chip(tag))


func _make_chip(tag: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS[CATEGORY_OF.get(tag, Category.NEUTRAL)]
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = tag
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel
