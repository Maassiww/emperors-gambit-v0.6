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

## Cel speciali: czysta frakcja vs mix

Gracz ma mieć realny wybór między decku jednej frakcji a mieszanym. Speciale są głównym narzędziem:
nagradzają określone kompozycje i dają odpowiedzi na typowe strategie, więc żaden styl nie jest oczywisty.

### Pomysły do dyskusji (nic jeszcze nie jest ustalone)

Od właściciela:
- **Zabójca** – teleportuje się na tyły przeciwnika i poluje na range/speciale.
- **Ork Konstruktor** – idąc do przodu, co jakiś czas stawia wieżyczki.

Propozycje do rozważenia:
- **Ludzie**
  - *Inżynier Tarcz* – rozstawia generator osłony, który pochłania obrażenia jednostek w pobliżu (kontra na artylerię).
  - *Psionik* – co kilka sekund ogłusza grupę wrogów (kontra na masę).
  - *Chorąży Imperium* – aura dla jednostek ludzi; im czystszy deck, tym silniejsza (nagradza czystą frakcję).
- **Orkowie**
  - *Szaman* – „Waaagh”: wzmacnia wszystkie melee w zasięgu, mocniej przy dużej liczbie orków.
  - *Bombowiec* – kamikaze wbiegający w gęste formacje (kontra na stacjonarną artylerię).
  - *Wódz* – każdy poległy ork nakręca szał całej armii.
- **Neutralne / mix**
  - *Najemnik* – silniejszy za każdą inną frakcję obecną w armii (nagradza mix).
  - *Zwiadowca* – na starcie walki odsłania i oznacza najsilniejszą jednostkę wroga (łączy się z mgłą wojny).

## Otwarte decyzje

- Remisy: obecnie zawsze jest zwycięzca (kryteria: eliminacja → HP armii → zadane obrażenia → losowanie). Alternatywa w configu: remis + nagła śmierć.
- Umiejętności baz (obecnie Sztandar i Bębny wojenne) – do przemyślenia, mają być taktyczne, nie „pociski”.
- Balans baz.
