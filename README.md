# Emperor's Gambit

Mobilny card battler (Godot 4.7, Android). Grimdark sci-fi: ludzie w pancerzach wspomaganych kontra orkowie.

## Struktura
- `game/` – projekt Godot (otwórz `game/project.godot` w Godot 4.7)
  - `core/` logika meczu (deterministyczna, bez grafiki)
  - `data/` karty, frakcje, bazy
  - `ai/` bot · `ui/` + `scenes/` ekrany · `tests/` testy
- `tools/build.sh` – test + build web i APK do `build/`
- `tools/screenshot.sh` – zrzut ekranu sceny (Xvfb)
- `tools/deploy.sh` – build + publikacja na serwer testowy (port 8090, z hasłem)
- `.github/workflows/build.yml` – kopia zapasowa: test + APK na GitHubie przy każdym pushu

## Jak testować
- **Przeglądarka (iPhone/PC):** http://139.162.152.247:8090 (login i hasło u właściciela)
- **Android:** pobierz `http://139.162.152.247:8090/emperors-gambit.apk`, przeciągnij do emulatora Android Studio.
