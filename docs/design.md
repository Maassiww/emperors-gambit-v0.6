# Emperor's Gambit – dokument projektowy

Żywy dokument: zapisujemy tu uzgodnione zasady i otwarte pomysły. Liczby (statystyki, koszty) są w `game/data/` i `game/core/game_config.gd`.

## Rdzeń meczu

- Każdy gracz ma 3 HP, mecz Bo5. Przegrany rundy traci 1 HP.
- Runda: draft (3 ruchy po 15 s, gracze działają jednocześnie, pod mgłą wojny) → odsłonięcie → automatyczna walka → wynik.
- Ruch = zagranie jednej z 3 losowych kart z decku albo **Gambit** (wstrzymanie ruchu za +20 łaski).
- Karta zawsze daje te same jednostki (np. „+2 Strzelec”).
- Armia rośnie przez cały mecz; w każdej rundzie walczy od nowa z pełnym HP.
- Walka trwa do eliminacji. Po 20 s dogrywka: obrażenia rosną o 25%/s. Pat bez możliwych obrażeń rozstrzyga suma HP armii.

## Łaska (pasek frakcji bazy: Emperor's Mercy, Grimgor's Favor*)

- Kumuluje się przez cały mecz (max 100). Rośnie za Gambit, wygraną (wg ocalałego HP) i przegraną.
- W ręce maksymalnie **jedna** karta specjalna:
  - łaska ≥ 50: szansa = łaska% na podświetloną kartę ×2 jednostki (koszt 50),
  - łaska = 100: zawsze jedna karta **ewolucji** (koszt 100), o ile masz już tę jednostkę.
- Ewolucja zamienia wszystkie jednostki danej karty w osobną, dużo mocniejszą formę; od tej chwili karta wystawia ewoluowaną formę.

\* nazwa robocza – przed publikacją zmienić (IP Games Workshop).

## Szyk

Jednostki ustawiają się automatycznie, od frontu: ciężkie melee → lekkie melee → szybki range → ciężki range → special.

## Tożsamość podklas

| Podklasa | Rola | Zachowanie |
|---|---|---|
| Ciężkie melee | Tank, przyjmuje obrażenia na twarz | Dużo HP i pancerza, mało obrażeń, wolne |
| Lekkie melee | DPS w zwarciu | Mało HP, wysokie obrażenia, szybkie |
| Szybki range | Mobilny DPS | Szybki ostrzał, szybszy ruch (pomysł: na starcie rozchodzą się na boki) |
| Ciężki range | Artyleria / snajperzy | **Stacjonarni**, bardzo duży zasięg, mocne pojedyncze trafienia |
| Special | Kontry i karty-atuty | Unikalne mechaniki, które wiążą deck |

Zwykłe jednostki atakują najbliższego wroga. Atak na tyły to domena speciali.

## Budowanie decku

- Deck: 5 różnych kart z dowolnych frakcji, **maks. 2 speciale** (do rozważenia: maks. 1).
- Baza wybierana osobno. Ostatni deck i baza zapisują się na urządzeniu.
- Bot gra jednym z gotowych zestawów (`Bot.PRESETS`): czyste frakcje i mixy.

## Słownik efektów (wdrożone)

| Słowo | Działanie | Limit |
|---|---|---|
| Pancerz | każdy punkt −6% obrażeń | maks. −60% |
| Prowokacja | wrogowie w promieniu muszą atakować tę jednostkę | najbliższy prowokujący wygrywa; leczenie na niej −50% |
| Ogłuszenie | brak ruchu i ataku | po ogłuszeniu 2 s odporności |
| Korozja | −1 pancerza na stos | maks. 3 stosy |
| Oznaczenie | cel otrzymuje +X% obrażeń | jeden znacznik, liczy się najsilniejszy |
| Egzekucja | +X% obrażeń do celów poniżej progu HP | — |
| Aura | bonus dla sojuszników w promieniu | z kilku aur tego samego parametru liczy się najsilniejsza |
| Przywołanie | nowa jednostka w trakcie walki | limit na przywołującego |

Priorytet celu: **Prowokacja > cecha jednostki** (na tyły, w największą grupę) **> najbliższy wróg**.

W UI:
- zasięgi Prowokacji (biały) i aur (kolor frakcji) rysujemy jako jeden wspólny obrys sumy okręgów;
- efekty czasowe mają nad jednostką nazwę i biały pasek pozostałego czasu;
- podgląd draftu i odsłonięcie pokazują poziom Kontraktu i osłabione aury („Sztandar 50%”).

## Czystość decku

Liczymy **różne typy kart na planszy** (nie liczbę jednostek). Aury „pod czystość” (Chorąży, Szaman):
- 0 obcych typów → 100%,
- 1 obcy typ → 50%,
- 2+ obce typy → 0%.

Typ neutralny też jest obcy. Przeciwnik widzi skład po odsłonięciu, więc czystość jest jawną informacją.

## Speciale

| Special | Frakcja | Działanie | Kontruje | Kontrą jest |
|---|---|---|---|---|
| Medyk polowy | ludzie | leczy najbardziej rannego | wyniszczanie | nagłe zabicie, Zabójca |
| Zabójca | ludzie | ×2; po 2 s skok za najdalszą jednostkę range/special wroga; Egzekucja +50% < 35% HP; trzyma się ofiary do jej śmierci | artyleria, Medyk | obszar, skupiony ostrzał z tyłów |
| Psionik | ludzie | co 6 s ogłusza (1,5 s) największą grupę w zasięgu | masa | Lotniak, Zabójca |
| Chorąży | ludzie | aura: ludzie +20% obrażeń, +2 pancerza (wg czystości) | wyrównana walka | obszar, mix |
| Lotniak | orkowie | lata, poluje na tyły, po śmierci wybucha | artyleria | szybki range, Prowokacja |
| Konstruktor | orkowie | co 7 s stawia wieżyczkę (maks. 2 na konstruktora) | defensywne armie | artyleria, obszar |
| Bombowiec | orkowie | ×3; wbiega w największą grupę i wybucha, ignoruje pancerz (Korozja ×2) | zbite formacje | Prowokacja (wybucha na tanku), ostrzał |
| Szaman | orkowie | aura: orkowie +25% szybkości ataku i ruchu (wg czystości) | wyrównana walka | Psionik |
| Najemnik | neutralny | Kontrakt, patrz niżej | — | — |

Ewolucja każdego speciala wzmacnia jego cechę (krótszy skok, większy promień, więcej wieżyczek…).

### Jednostki bezfrakcyjne (Kontrakt)

Efekt zależy od **liczby różnych frakcji na planszy** (neutralne się nie liczą) i zmienia się z poziomem:

| Poziom | Warunek | Najemnik |
|---|---|---|
| 0 | tylko neutralne | brak efektu |
| I | 1 frakcja | aura: melee +20% obrażeń |
| II | 2 frakcje | aura: **wszyscy** +12% obrażeń **i** Oznaczenie celów (+20%) |

Kolejne neutralne karty i poziom III dojdą z trzecią frakcją. Technicznie każda cecha ma warunek `min_factions`/`max_factions`, więc nowe kontrakty to same dane.

### Pomysły na później
- Inżynier Tarcz (ludzie): generator osłony przeciw artylerii.
- Wódz (orkowie): poległy ork nakręca szał całej armii.
- Zwiadowca (neutralny): oznacza najsilniejszą jednostkę wroga na starcie.

## Otwarte decyzje

- Remisy: obecnie zawsze jest zwycięzca (kryteria: eliminacja → HP armii → zadane obrażenia → losowanie). Alternatywa w configu: remis + nagła śmierć.
- Umiejętności baz (obecnie Sztandar i Bębny wojenne) – do przemyślenia, mają być taktyczne, nie „pociski”.
- Balans baz.
