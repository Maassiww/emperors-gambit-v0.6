# Emperor's Gambit

Mobilny card battler (Godot 4.7, Android). Grimdark sci-fi: ludzie w pancerzach wspomaganych kontra orkowie.

## Struktura
- `game/` – projekt Godot (otwórz `game/project.godot` w Godot 4.7)
  - `core/` logika meczu (deterministyczna, bez grafiki)
  - `data/` karty, frakcje, bazy
  - `ai/` bot · `ui/` + `scenes/` ekrany · `tests/` testy
- `tools/build.sh` – test + build web i APK do `build/`
- `tools/screenshot.sh` – zrzut ekranu sceny (Xvfb)
- testy: `godot --headless --path game --script res://tests/run_tests.gd`
- balans: `godot --headless --path game --script res://tests/simulate.gd -- 300 1 log` (mecze bot vs bot)
- `tools/deploy.sh` – build + publikacja na serwer testowy (HTTPS, z hasłem)
- `.github/workflows/build.yml` – kopia zapasowa: test + APK na GitHubie przy każdym pushu

## Jak testować
- **Przeglądarka (iPhone/PC):** https://139-162-152-247.sslip.io (login i hasło u właściciela)
- **Android:** pobierz `https://139-162-152-247.sslip.io/emperors-gambit.apk`, przeciągnij do emulatora Android Studio.
