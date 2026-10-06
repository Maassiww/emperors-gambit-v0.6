# Emperor's Gambit – zasady pracy

Card battler (Godot 4.7, GDScript), Android + web. Plan bieżącego etapu: `docs/plan-v0.6.md` (odhaczać postęp tam).
Zasady projektu od właściciela: `game/markdown.txt`.

## Kod
- Godot 4: `@onready`, `@export`, typowane GDScript (`var hp: int = 100`), snake_case / PascalCase dla klas.
- UI i sceny (`game/scenes/`, `game/ui/`): węzły jako komponenty, sygnały w górę, metody w dół, małe skrypty.
- Logika meczu (`game/core/`, `game/ai/`): czyste klasy bez węzłów. Walka musi być deterministyczna:
  ticki 20/s, pozycje całkowite (`BattleSim.SCALE`), RNG tylko z ziarna, stała kolejność.
- Statystyki, cechy i opisy kart edytuj w `tools/gen_units.py`, potem `python3 tools/gen_units.py`.
  Nie zmieniaj ręcznie `game/data/units/*.tres`.
- Melee nie atakuje latających. To zamierzona przewaga latających, nie zmieniać przy balansie.

## Komendy
- testy: `godot --headless --path game --script res://tests/run_tests.gd` (muszą przejść przed commitem)
- smoke: `godot --headless --path game --script res://tests/smoke_test.gd`
- balans: `godot --headless --path game --script res://tests/simulate.gd -- 350 <ziarno>`; puszczać 4 shardy równolegle
  w tle. Czekać przez `pgrep -x godot`. Wynik kart: cel 45–55%.
- zrzuty ekranu (xvfb): `xvfb-run -a godot --path game --resolution 720x1280 --script res://tests/shot_match.gd -- <katalog>`
  (także `shot_deck.gd`, `shot_zones.gd`)
- po nowym `class_name`: `godot --headless --path game --import`
- gra lokalnie: `godot --path game --position 100,100`, scena: `godot --path game res://scenes/main.tscn`
- wdrożenie na serwer testowy: `tools/deploy.sh` (buduje web + APK, uruchamia testy)
