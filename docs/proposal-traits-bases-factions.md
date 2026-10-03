# Propozycja: cechy podklas, bazy, nowe frakcje

Status: **propozycja do dyskusji, nic z tego nie jest jeszcze w grze.**
Uzupełnia `docs/design.md`. Liczby są punktem startowym do symulacji, nie decyzją.

---

## 1. Założenia

1. **Rola wspólna, twist frakcyjny.** Każda podklasa ma tę samą rolę we wszystkich frakcjach (tank, DPS, artyleria…) i **jedną** cechę frakcyjną. Na telefonie gracz musi zrozumieć jednostkę w 2 sekundy.
2. **Wspólny słownik efektów.** Cechy składamy z małego zestawu słów-kluczy z ikonkami. Nowa jednostka to nowa kombinacja klocków, a nie nowa zasada.
3. **Czysta frakcja i mix są równorzędne.**
   - Czysta frakcja: mocniejsza pasywka bazy i wewnętrzne pętle synergii.
   - Mix: lepsze kontry i synergie między frakcjami, które czysta frakcja zwykle ma tylko częściowo.
4. **Baza definiuje archetyp.** Każda frakcja ma docelowo kilka baz: przynajmniej jedną „pod czystą frakcję” i jedną „przyjazną mixowi”.

---

## 2. Słownik efektów

| Słowo | Działanie | Limit (anty-combo) |
|---|---|---|
| **Spowolnienie** | −X% prędkości ruchu i ataku | maks. −50% łącznie |
| **Korozja** | −1 pancerza na stos | maks. 3 stosy, pancerz nie spada poniżej 0 |
| **Ogłuszenie** | brak ruchu i ataku | po ogłuszeniu 2 s odporności |
| **Prowokacja** | wrogowie w promieniu muszą atakować tę jednostkę | 1 źródło na wroga, najbliższe wygrywa |
| **Strefa** | efekt na ziemi przez kilka sekund | maks. N stref na stronę |
| **Przebicie** | ignoruje pancerz lub trafia też jednostki za celem | — |
| **Oznaczenie** | cel otrzymuje +X% obrażeń | 1 znacznik na cel |
| **Egzekucja** | bonus do celów z niskim HP | — |

**Priorytet wyboru celu** (musi być jednoznaczny, bo od niego zależą kontry):
`Prowokacja` > cecha jednostki (np. „przez szereg”, „na tyły”) > najbliższy wróg.
Dzięki temu **Prowokacja jest twardą kontrą** na jednostki omijające front.

---

## 3. Cechy podklas

### Ludzie: precyzja, dyscyplina, wiara

| Jednostka | Cecha | Słowa | Ewolucja wzmacnia cechę |
|---|---|---|---|
| Bastion (ciężkie melee) | **Prowokacja** w małym promieniu; obok innego Bastionu −20% obrażeń z range (mur tarcz) | Prowokacja | Pretorianin: większy promień, mur tarcz −35% |
| Szturmowiec (lekkie melee) | **Desant**: na starcie walki skacze na front wroga, ogłusza na 1 s przy lądowaniu; **Egzekucja** +50% do celów < 30% HP | Ogłuszenie, Egzekucja | Elita: drugi skok w trakcie walki |
| Strzelec (szybki range) | **Ogień zaporowy**: każde trafienie daje krótkie Spowolnienie 10%; na starcie rozchodzi się na skrzydła | Spowolnienie | Weteran: Spowolnienie 15% |
| Lancer (ciężki range, stacjonarny) | **Snajper**: celuje w najcenniejszy cel w zasięgu (ewolucje > tanki > reszta); pocisk przebija linię | Przebicie, Oznaczenie | Ciężki Lancer: trafiony cel jest oznaczony |
| Medyk (special) | leczy najbardziej rannego sojusznika (dowolnej frakcji) | — | Archimedyk: leczy dwa cele naraz |

**Pętla czystej frakcji:** Bastion trzyma wroga w miejscu (Prowokacja) → Strzelec spowalnia → Lancer bije oznaczone, wolne cele → Szturmowiec dobija (Egzekucja).

### Orkowie: chaos, masa, złom, brud

| Jednostka | Cecha | Słowa | Ewolucja wzmacnia cechę |
|---|---|---|---|
| Pancerniak (ciężkie melee) | **Maź**: co kilka sekund zostawia kałużę rdzawego oleju (Spowolnienie + Korozja); po śmierci wybucha zbiornik i zostaje duża kałuża | Strefa, Spowolnienie, Korozja | Megapancerniak: kałuże częściej i większe |
| Szaleniec (lekkie melee) | **Przez szereg**: omija ciężkie melee i bije pierwszy cel, który nim nie jest; **Ostatni oddech**: po 0 HP walczy jeszcze 1 s | — | Berserker: każde zabójstwo przyspiesza ataki |
| Siekacz (szybki range) | **Na oślep**: każda seria w losowego wroga w zasięgu; +5% szybkości ataku za każdego Siekacza w pobliżu (maks. +30%) | — | Megasiekacz: bonus z tłumu ×2 |
| Rakieciarz (ciężki range, stacjonarny) | **Artyleria na oko**: rozrzut trafienia, duży obszar, zostawia płonącą Strefę; ok. 15% obrażeń obszarowych może trafić swoich | Strefa, Przebicie (obszar) | Rakietowy Boss: mniejszy rozrzut |
| Lotniak (special, latający) | leci na tyły; po śmierci spada i wybucha | — | As Lotników: wybuch większy |

**Pętla czystej frakcji:** Pancerniaki rozlewają Maź → wróg zwalnia i traci pancerz → masa Siekaczy rozbija go szybkim ostrzałem (Korozja wyrównuje słabość szybkiego ostrzału na pancerz) → Szaleńcy wpadają w tyły.

### Kontrasty, które z tego wychodzą

| Podklasa | Ludzie | Orkowie |
|---|---|---|
| Tank | chroni sojuszników | psuje teren |
| DPS melee | dobija rannych | omija front |
| Szybki range | kontroluje (spowalnia) | zalewa ilością |
| Artyleria | precyzyjny strzał w elitę | niecelny obszar w masę |

---

## 4. Czysta frakcja vs mix: jak to się wyrównuje

### 4.1 Pasywka bazy skaluje się z czystością decku

Czystość liczymy po **kartach w decku**, nie po liczbie jednostek (inaczej orkowa masa zawsze wygrywałaby liczenie).

| Karty frakcji bazy w decku (5) | Siła pasywki |
|---|---|
| 5/5 | 100% |
| 4/5 | 70% |
| 3/5 | 40% |
| ≤ 2/5 | 0% |

Przy decku 3 kart: 3/3 = 100%, 2/3 = 50%, 1/3 = 0%.

### 4.2 Synergie między frakcjami (haczyki pod mix)

| Combo | Dlaczego działa |
|---|---|
| Maź orków + Lancer ludzi | Korozja i Spowolnienie = łatwe, długie cele dla snajpera |
| Prowokacja Bastionu + Szaleńcy/Siekacze | ludzki tank ściąga ogień z kruchej orkowej masy |
| Desant (ogłuszenie) + Rakieciarz | ogłuszeni wrogowie stoją w miejscu, rozrzut mniej boli |
| Na oślep (Siekacz) + Egzekucja (Szturmowiec) | Siekacze zostawiają wielu rannych, Szturmowiec ich dobija |
| Medyk + orkowa masa | leczenie najbardziej rannego przedłuża życie tanim jednostkom |

Zasada balansu: **najlepsze combo z mixu ma być mniej więcej tak silne jak pełna pętla czystej frakcji z pełną pasywką bazy.** Mix traci pasywkę, ale zyskuje kontry dobrane pod przeciwnika.

### 4.3 Neutralne speciale

Docelowo karty bez frakcji, które nagradzają konkretne kompozycje:
- **Najemnik**: +X% statystyk za każdą *inną* frakcję w armii (nagroda za mix).
- **Chorąży** (ludzie) / **Wódz** (orkowie): mocniejsi przy czystym decku (nagroda za czystość).

---

## 5. Analiza obecnych baz

| Baza | Pasywka | Umiejętność | Problem |
|---|---|---|---|
| Cytadela Imperium | ludzie +1 pancerza | Sztandar: przy 70% HP armii +25% szybkości ataku przez 4 s | pancerz przy obecnym wzorze jest **skokowy**: +1 robi ogromną różnicę na Siekacze (5 obrażeń) i prawie zero na Lancera; Sztandar włącza się sam, brak decyzji gracza |
| Obóz Wojenny | szał: +3% obrażeń za każdego poległego orka, maks. 6 | Bębny: pierwsze 3 s +35% ruchu, +17% ataku | szał w masie orków nabija się w kilka sekund, więc w praktyce to płaskie +18%; też brak decyzji |

**Główny wniosek: wzór pancerza trzeba zmienić przed dodaniem cech.**
Obecnie `obrażenia − pancerz` (min. 20%) sprawia, że pancerz albo nic nie znaczy, albo prawie całkowicie blokuje.
Proponuję procentową redukcję: **każdy punkt pancerza = −6% obrażeń, maks. −60%.**
Korozja i Przebicie dalej działają czytelnie, a balans przestaje być tak skokowy.

**Drugi wniosek: moce baz nie dają decyzji.** Obie działają automatycznie, a gracz na nie nie wpływa.

### 5.1 Nowa struktura bazy

Każda baza ma:
1. **Pasywkę**: działa zawsze, skaluje się z czystością (4.1) albo celowo nie, w bazach „pod mix”.
2. **Dekret**: raz na mecz, zamiast ruchu w drafcie, aktywujesz moc bazy na tę rundę. Przeciwnik nie widzi tego pod mgłą, odsłania się dopiero w walce.
   - To ta sama logika co Gambit: płacisz tempem (ruchem) za efekt.
   - Daje decyzję „kiedy?” i blef: czy przeciwnik wstrzymał się dla łaski, czy szykuje Dekret?
   - Obecne Sztandar i Bębny stają się Dekretami.

### 5.2 Propozycje baz

**Ludzie**

| Baza | Archetyp | Pasywka | Dekret |
|---|---|---|---|
| Cytadela Imperium | czysta frakcja, obrona | ludzie: +pancerz (wg czystości) | **Mur Wiary**: przez pierwsze 6 s walki cała armia −30% obrażeń |
| Katedra Męczenników | czysta frakcja, poświęcenie | gdy ginie człowiek, pobliscy ludzie odzyskują trochę HP | **Krucjata**: cała armia +25% obrażeń, ale −15% HP |
| Port Orbitalny | **mix** | jednostki spoza frakcji ludzi +10% HP (nie zależy od czystości) | **Posiłki**: w tej rundzie masz 4 ruchy zamiast 3 |

**Orkowie**

| Baza | Archetyp | Pasywka | Dekret |
|---|---|---|---|
| Obóz Wojenny | czysta frakcja, agresja | orkowie: szał za poległych (wg czystości) | **Bębny wojenne**: pierwsze 4 s walki szybszy ruch i atak |
| Złomowisko | czysta frakcja, attrition | każda śmierć (obu stron) zostawia złom; orkowie przy złomie regenerują pancerz | **Złomowy Kolos**: na starcie walki z resztek powstaje duża jednostka-tank |
| Arena Krwi | **mix** | każde zabójstwo daje +1 łaski (maks. +10 na rundę) | **Rzeź**: zwycięzca tej rundy dostaje podwójną łaskę, przegrany zero |

Moce celowo nie są pociskami. Zmieniają warunki walki, ekonomię albo tempo.

---

## 6. Inne frakcje (poglądowo, na później)

**Decyzja (2026-10-03): na razie rozwijamy grę tylko z 2 frakcjami.** Kolejne frakcje wprowadzamy stopniowo później.

Każda nowa frakcja musi wnieść **nową oś** i najwyżej **1–2 nowe słowa** do słownika.
Liczebność na kartę wyznacza miejsce na skali „elita ↔ masa”.

| Robocza nazwa | Oś | Na kartę | Nowe słowa | Haczyk pod mix |
|---|---|---|---|---|
| **Kult Zarazy** | attrition, rozkład | 3–4 | **Zaraza** (obrażenia w czasie), **Wskrzeszenie** (polegli wstają jako słabe zombie) | wykorzystuje śmierci obu stron, więc łączy się z orkową masą |
| **Rój** (obcy, owadzi) | adaptacja, ilość | 6–8 | **Adaptacja** (jednostki, które przeżyły rundę, rosną w siłę) | nagradza tanki innych frakcji, które pozwalają rojowi przeżyć |
| **Pradawni** (mechaniczni) | elita, odporność | 1 | **Reanimacja** (raz na walkę wstaje z 30% HP) | drogie, mocne kotwice do mixu |
| **Eldarowie Pustki** (psionicy) | szybkość, precyzja, kruchość | 1–2 | **Fazowanie** (krótka niewrażliwość, teleport) | assasini i kontry na artylerię |

Nazwy robocze. Wszystkie muszą być **nasze**, bez nazw i wyglądu z IP Games Workshop.

Ograniczenie: łącznie maks. około 12 słów w słowniku. Każde nowe słowo musi być potrzebne co najmniej 3 jednostkom.

---

## 6a. Ryzyko prawne: Games Workshop

Nie jestem prawnikiem. Przed publikacją w Google Play warto skonsultować nazwy i grafiki z prawnikiem od IP.

**Co chroni prawo, a co nie:**
- Ogólne motywy (żołnierze w pancerzach, orkowie, kult zarazy, rój obcych, mechaniczni nieumarli, psionicy) **nie są chronione**. W sporze *Games Workshop v. Chapterhouse Studios* (USA, 2012–2014) sąd uznał, że wielu ogólnych elementów nie da się zastrzec.
- Chronione są **konkretne nazwy i znaki towarowe** (np. *Space Marine*, *Adeptus Astartes*, *Eldar*, *Necron*, *Tyranid*, *Nurgle*, *Grimgor*), **ikonografia** (aquila, symbole zakonów, charakterystyczne naramienniki) i **konkretne projekty postaci**.
- GW aktywnie egzekwuje swoje prawa. Głośna sprawa: zablokowanie e-booka *Spots the Space Marine* na Amazonie (2013) za samo słowo „Space Marine”.

**Największe ryzyko to suma podobieństw**, a nie jeden element. Ludzie w pancerzach + „Imperium” + „Emperor” w tytule i nazwie łaski + orkowie z „k” to razem wyraźne skojarzenie z 40k.

**Co zmienić przed publikacją:**

| Element | Ryzyko | Propozycja |
|---|---|---|
| „Grimgor's Favor” | wysokie (postać GW) | imię własnego orkowego herszta |
| „Imperium” jako nazwa frakcji ludzi | średnie w połączeniu z resztą | własna nazwa (np. Dominium, Hegemonia, Zakon Tarczy) |
| „Emperor's Mercy”, „Emperor's Gambit” | średnie w połączeniu z „Imperium” | rozważyć zmianę tytułu albo przynajmniej łaski ludzi (np. „Łaska Tronu”) |
| „Orks” w wersji angielskiej | średnie (pisownia 40k) | po angielsku „Orcs”; po polsku „orkowie” to zwykłe słowo |
| „Eldarowie Pustki” | wysokie | całkowicie inna nazwa |
| Pradawni (mechaniczni, wstają po śmierci) | średnie (bliskie Necronom) | inny wygląd i inny twist niż reanimacja |
| Kult Zarazy | średnie, jeśli wygląd jak Nurgle (muchy, zielona zgnilizna, rozdęcia) | inna estetyka rozkładu (np. rdza, grzyb, krystalizacja) |
| Grafiki AI | wysokie, jeśli prompt zawiera nazwy z 40k | nie wpisywać nazw GW w prompty, własny styl |

**Zasada:** klimat grimdark tak, kopiowanie nie. Własne nazwy, własna ikonografia, własne sylwetki jednostek.

---

## 7. Jak to zaimplementować

### 7.1 Architektura

- **Cechy jako dane:** `TraitData` (Resource) z parametrami, a w `UnitData` lista `traits`. Przykłady: `TauntTrait`, `PuddleTrait`, `ScatterTrait`, `PierceLineTrait`, `ExecuteTrait`.
- **Hooki w BattleSim:** każda cecha może podpiąć się pod kilka momentów:
  - `on_spawn`, `on_tick`,
  - `choose_target` (z priorytetem z sekcji 2),
  - `modify_attack` (np. rozrzut, przebicie linii), `on_hit_taken`, `on_death`.
- **Statusy na jednostce:** słownik `status → (stosy, ticki do końca)`, z limitami ze słownika.
- **Strefy:** lista `(pozycja, promień, efekt, ticki, właściciel)` sprawdzana co tick.
- **Przywołania** (wieżyczki, zombie, Kolos): dodanie jednostki w trakcie walki z nowym `uid`.
- **Determinizm bez zmian:** wszystko na liczbach całkowitych, losowość tylko z RNG walki, aktualizacja dwufazowa (najpierw zbieramy akcje, potem je stosujemy). PvP zostaje uczciwe.
- **Dekret** to nowy rodzaj ruchu w `Match.submit()`, obok karty i Gambitu, ukryty pod mgłą jak reszta draftu.

### 7.2 UI

Wymagania od właściciela:
- **Efekt na jednostce:** malutki napis z nazwą efektu nad jednostką + malutki biały pasek pokazujący pozostały czas działania.
- **Wizualizacje efektów:** każdy efekt ma własny efekt wizualny, np. Prowokacja = biały pierścień wokół jednostki pokazujący zasięg.
- **Łączenie efektów:** takie same efekty sąsiednich jednostek **łączą się** w jeden kształt (pierścienie Prowokacji kilku Bastionów zlewają się w jeden obrys), zamiast się nakładać. Technicznie: rysujemy obrys sumy okręgów (np. metaball / pole odległości w shaderze), a nie każdy okrąg osobno.

Pozostałe:
- Strefy rysowane jako półprzezroczyste plamy w kolorze frakcji (też łączone).
- Przytrzymanie karty pokazuje opis jednostki i jej słowa-klucze.
- Przycisk Dekretu obok Gambitu (aktywny raz na mecz).

### 7.3 Bot

- Karty dostają tagi (np. `produkuje: Korozja`, `korzysta z: Spowolnienie`), a bot ocenia synergie z tabeli.
- Do balansu potrzebne będą dwa poziomy bota: „losowy rozsądny” i „pod archetyp”.

---

## 8. Plan balansu

### 8.1 Narzędzia (rozbudowa `tests/simulate.gd`)

1. **Macierz kart:** każda karta kontra każda przy równym budżecie siły. Wynik to tabela kontr, którą trzeba czytać tak:
   - nikt nie może wygrywać ze wszystkimi,
   - każda karta ma co najmniej jedną wyraźną kontrę (< 40%).
2. **Turniej archetypów:** czyste Ludzie, czyste Orki, kilka mixów, każdy z kilkoma bazami. Cel: każdy archetyp 45–55%.
3. **Czystość vs mix:** to samo, ale zmienia się tylko liczba kart frakcji w decku. Cel: krzywa płaska (± 5 pkt), żadna liczba kart nie dominuje.
4. **Tempo:** średnia długość walki 12–18 s, odsetek dogrywek < 10%, średnio 3,5–4,5 rundy.

### 8.2 Ryzyka balansu i zabezpieczenia

| Ryzyko | Zabezpieczenie |
|---|---|
| Prowokacja + leczenie = niezniszczalna ściana | leczenie słabsze na jednostkach z Prowokacją; dogrywka i tak kończy walkę |
| Łańcuch ogłuszeń (Desant + Psionik) | 2 s odporności po ogłuszeniu |
| Stackowanie Spowolnienia (Maź + Ogień zaporowy) | limit −50% |
| Korozja zeruje pancerz | maks. 3 stosy |
| Szaleńcy rozrywają decki oparte na range | Prowokacja ma pierwszeństwo nad „przez szereg”, czyli jasna kontra |
| Trafianie swoich przez Rakieciarza psuje mix z orkową masą | ok. 15% obrażeń obszarowych na swoich, mniejszy rozrzut po ewolucji; to świadoma decyzja przy budowaniu decku |
| Losowość (rozrzut, na oślep) odczuwana jako niesprawiedliwa | deterministyczna z seeda, umiarkowana skala, zawsze widoczna animacja |
| Masa vs efekty obszarowe | budżet siły karty uwzględnia liczbę jednostek: orkowie płacą podatnością na obszar |

### 8.3 Kolejność wdrażania

1. **Fundament:** procentowy wzór pancerza, system statusów i stref, priorytety celu, ikonki w UI, testy. Bez nowej zawartości, potem przebalansowanie.
2. **Cechy obecnych 10 jednostek** (po jednej), ewolucje wzmacniają cechę. Macierz kart i balans.
3. **Bazy:** pasywka skalowana czystością, Dekrety, po 1 nowej bazie na frakcję (Port Orbitalny, Arena Krwi).
4. **Speciale:** Zabójca, Konstruktor, Psionik, Najemnik.
5. **Trzecia frakcja.**

Każdy krok kończy się grywalną wersją na serwerze i Twoją oceną, zanim ruszy następny.
