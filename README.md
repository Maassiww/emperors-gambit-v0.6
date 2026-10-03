# Emperor's Gambit

Mobilny card battler (Godot 4.7, Android). Grimdark sci-fi: ludzie w pancerzach wspomaganych kontra orkowie.

## Struktura
- `game/` – projekt Godot (otwórz `game/project.godot` w Godot 4.7)
  - `core/` logika meczu (deterministyczna, bez grafiki)
  - `data/` karty, frakcje, bazy
  - `ai/` bot · `ui/` + `scenes/` ekrany · `tests/` testy
- `tools/build.sh` – test + build web i APK do `build/`
- `tools/screenshot.sh` – zrzut ekranu sceny (Xvfb)
- `.github/workflows/build.yml` – automatyczny build web + APK przy każdym pushu

## Jak testować
- **Przeglądarka (iPhone/PC):** link do wersji web.
- **Android:** pobierz APK z zakładki Actions → ostatni build → `emperors-gambit-apk`, przeciągnij do emulatora Android Studio.
