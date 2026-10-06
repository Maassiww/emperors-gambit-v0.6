# Plan v0.6: cechy jednostek, style gry, czystość przez bazy

Status: **zaakceptowany 2026-10-06**. Po akceptacji ten plik jest źródłem prawdy dla etapu; postęp odhaczamy tutaj.

## Cel etapu

Każda jednostka ma czytelną cechę, a trzy sposoby grania są realne i zbalansowane:

| Styl | Na czym wygrywa | Co go hamuje |
|---|---|---|
| **Spam** jednej karty | cechy rosnące z liczbą tej samej jednostki, ewolucja całej masy | karta w ręce tylko w ~60% ruchów, przeciwnik widzi armię po odsłonięciu i dobiera kontrę |
| **Dywersyfikacja** | combo między różnymi jednostkami (spowolnij → snajper, korozja → szybki ostrzał) | słabszy pojedynczy element, mniej bonusów z masy |
| **Czysta frakcja** | pasywka bazy wg czystości decku + pętle cech jednej frakcji | brak kontr z drugiej frakcji |
| **Mix** | kontry z obu frakcji + jednostki bezfrakcyjne | pasywka bazy słabsza lub zerowa |

**Kryteria sukcesu** (symulacje bot vs bot):
- każda karta 45–55%, każda ma co najmniej jedną kontrę < 40% w macierzy kart,
- style spam / dywersyfikacja: 45–55% każdy,
- decki czyste / mieszane: różnica ≤ 5 pkt,
- dogrywki < 10% walk, średnio 3,5–4,5 rundy (tempa walki na razie nie ruszamy).

## Decyzje już podjęte

- Limit **1 speciala** w decku (test 2 speciali, gdy dojdzie kilka nowych – zapytać właściciela).
- Bezfrakcyjne to **zwykłe podklasy**, nie speciale. Każda karta = jeden styl, poziom Kontraktu wzmacnia ten sam efekt.
- Aury Chorążego i Szamana **nie słabną**; działają tylko na własną frakcję.
- Czystość nagradza **pasywka bazy wg decku**: 5/5 = 100%, 4/5 = 70%, 3/5 = 40%, ≤ 2/5 = 0%.
- Losowość orków (Siekacz na oślep, rozrzut Rakieciarza, ~15% obszaru w swoich) – **tak, umiarkowanie**, deterministycznie z ziarna.
- Tempo walki bez zmian do dalszych testów.

- Karta bezfrakcyjna obniża czystość decku (liczy się jak obca).
- Aura Chorążego nazywa się „Chorągiew” (umiejętność Cytadeli zostaje „Sztandar”).

## Etapy

### 1. Porządki po v0.5 (mały) – ✅ zrobione 2026-10-06
Wynik: 2000 meczów bot vs bot, karty 44–57% (szum między seriami ±3–5 pkt), Cytadela 56% / Obóz 44%.
Po pierwszej serii wzmocnione: Chorąży (+30% obr., +3 panc., promień 180; był 35%) i Najemnik (210 HP, 30 obr.; był 41%).
Przy limicie 1 speciala czysty deck to zawsze 4 zwykłe karty frakcji + 1 special – różnorodność czystych decków dadzą dopiero cechy z etapu 3.
- Obrys aur bez przerw: dokładny punkt przecięcia okręgów zamiast pomijania odcinka.
- Config: limit 1 speciala; aury bez skalowania czystością (usunąć `scales_with_purity` z danych i kod `_purity_pct`).
- Bezfrakcyjni:
  - **Najemnik** (lekkie melee, ×2): aura melee +15% obrażeń przy 1 frakcji, +30% przy 2.
  - **Łowca Nagród** (szybki range, ×2): trafienia oznaczają cel, +15% przy 1 frakcji, +30% i dłużej przy 2.
- Bot: decki i presety pod limit 1 speciala.

### 2. Fundament: Spowolnienie i Strefa
- **Spowolnienie**: −X% ruchu i szybkości ataku, sumuje się do maks. −50%.
- **Strefa**: efekt na ziemi (pozycja, promień, czas, właściciel, efekt), maks. N stref na stronę.
- UI: plamy stref w kolorze frakcji, łączone jak obrysy aur; napis + pasek czasu dla Spowolnienia.
- Testy obu mechanik i ich limitów.

### 3. Cechy jednostek (wszystkie naraz)

| Jednostka | Cecha | Styl | Ewolucja |
|---|---|---|---|
| Bastion | Prowokacja + **mur tarcz**: obok innego Bastionu −20% obrażeń od range | spam | Pretorianin: większy promień, −35% |
| Szturmowiec | **Desant**: na starcie skok na front wroga, ogłuszenie 1 s; Egzekucja +50% < 30% HP | dywersyfikacja | Elita: drugi skok w trakcie walki |
| Strzelec | **Ogień zaporowy**: trafienie = Spowolnienie 10%; na starcie rozchodzą się na skrzydła | spam / wspiera Lancera | Weteran: 15% |
| Lancer | **Snajper**: celuje w najcenniejszy cel (ewolucje > tanki > reszta), pocisk przebija linię | dywersyfikacja | Ciężki Lancer: trafiony cel oznaczony |
| Medyk | bez zmian | — | Archimedyk: leczy 2 cele |
| Pancerniak | **Maź**: co kilka s kałuża (Spowolnienie + Korozja), po śmierci duża kałuża | dywersyfikacja (wspiera Siekaczy, Lancera) | większe i częstsze kałuże |
| Szaleniec | **Przez szereg**: omija ciężkie melee (Prowokacja go zatrzymuje); **Ostatni oddech**: walczy 1 s po 0 HP | spam (masa) | Berserker: zabójstwa przyspieszają ataki |
| Siekacz | **Na oślep**: losowy cel w zasięgu; **Tłum**: +5% szybkości ataku za sąsiedniego Siekacza (maks. +30%) | spam | Megasiekacz: bonus z tłumu ×2 |
| Rakieciarz | **Rozrzut** + płonąca Strefa; ~15% obszaru rani swoich | dywersyfikacja (lepszy na stojących, ogłuszonych) | Rakietowy Boss: mniejszy rozrzut |
| Lotniak | bez zmian (wybuch po śmierci) | — | — |

### 4. Pasywka bazy wg czystości
- Czystość = karty frakcji bazy w decku / rozmiar decku → 100/70/40/0%.
- Skaluje pasywki Cytadeli (pancerz) i Obozu (szał). Bez Dekretów i nowych baz (to osobny etap).
- Ekran decku pokazuje siłę pasywki na żywo przy wyborze kart.

### 5. Narzędzia balansu
- **Style bota**: spammer (trzyma się 1–2 kart, wstrzymuje ruch, gdy ich brak), dywersyfikator (preferuje nowe typy), obecny.
- **Raporty**: winrate per styl, per udział największej karty w armii, per czystość decku (0/40/70/100%).
- **Macierz kart**: każda karta przeciw każdej przy równym budżecie siły; wypisuje kontry < 40% i karty bez kontry.
- Symulacje w 4 równoległych shardach.

### 6. Balans i wydanie
- Iteracje liczb w `tools/gen_units.py` aż do kryteriów sukcesu.
- Testy jednostkowe dla każdej cechy, smoke test, zrzuty ekranu.
- Deploy na serwer testowy, commit, raport z liczbami dla właściciela.

### 7. Dokumentacja
- `docs/design.md`: zasady bieżące (limit speciali, bezfrakcyjni, czystość, cechy, style).
- `docs/proposal-traits-bases-factions.md`: oznaczyć, co wdrożone, i dopisać decyzje, które go zmieniły
  (bezfrakcyjni, aury bez czystości, kolejność wdrażania, limit speciali, cel stylów gry).
- Roadmapa M4+: ekran główny, ranking i areny, znajomi, poziom konta i nagrody, battlepass, osiągnięcia,
  kolekcja kart (odblokowane/zablokowane), sklep, gildie, eventy. Zasada: odblokowania nie dają przewagi w PvP.

## Później (poza tym etapem)
- Dekrety baz i nowe bazy (Port Orbitalny, Arena Krwi, Mur Wiary…).
- Kolejne speciale i bezfrakcyjni; test limitu 2 speciali.
- Bot zbierający łaskę pod ewolucje (dziś ewolucje prawie nie występują w symulacjach).
- Zmiany nazw pod IP przed publikacją.
