# Blinkweave testen – Anleitung für Einsteiger

Diese Anleitung setzt **nichts** voraus: kein installiertes Tool, keine Roblox-Erfahrung.
Sie führt dich von der Installation bis zum vollständigen Test des MVP.

Du brauchst einen Computer mit **Windows 10/11** oder **macOS** (Roblox Studio läuft nicht auf Linux oder Chromebooks) und etwa 30–45 Minuten.

**Überblick**

| Teil | Was | Pflicht? |
|---|---|---|
| A | Werkzeuge installieren (Roblox Studio, Git, Rokit, Rojo) | ja |
| B | Projekt herunterladen und Spieldatei bauen | ja |
| C | Spiel in Roblox Studio starten | ja |
| D | Test-Checkliste durchspielen | ja |
| E | Smoke-Test, Mehrspieler- und Handy-Test | empfohlen |
| F | Speichern (DataStore) testen | optional |
| G | Automatische Tests lokal ausführen | optional |
| H | Häufige Probleme | bei Bedarf |

Ein paar Begriffe vorab:

- **Roblox Studio**: das offizielle Programm, mit dem man Roblox-Spiele baut und testet.
- **Rojo**: überträgt die Code-Dateien aus diesem Repository nach Roblox Studio. Ohne Rojo müsstest du jede Datei per Hand in Studio kopieren.
- **Rokit**: installiert Rojo und die anderen Werkzeuge in genau der Version, die im Projekt festgelegt ist (`rokit.toml`).
- **Terminal**: das Fenster für Textbefehle. Unter Windows **PowerShell** (Startmenü → „PowerShell“ eintippen), unter macOS **Terminal** (Spotlight → „Terminal“).

---

## A. Werkzeuge installieren

### A1. Roblox-Konto und Roblox Studio

1. Falls noch nicht vorhanden: Konto auf <https://www.roblox.com> anlegen.
2. Roblox Studio herunterladen: <https://create.roblox.com> → **Start Creating** bzw. **Download Studio**.
3. Installer ausführen und in Studio mit deinem Roblox-Konto anmelden.

### A2. Git

Git lädt das Projekt von GitHub herunter.

- **Windows:** <https://git-scm.com/download/win> herunterladen und mit den Standardeinstellungen installieren. Dabei wird auch **Git Bash** installiert (brauchst du nur für Teil G).
- **macOS:** Im Terminal `git --version` eingeben. Wenn Git fehlt, bietet macOS an, die „Command Line Tools“ zu installieren – bestätigen.

Prüfen (neues Terminal-Fenster öffnen):

```sh
git --version
```

Erwartet: eine Versionsnummer, z. B. `git version 2.x`.

### A3. Rokit

- **Windows (PowerShell):**

  ```powershell
  Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
  ```

- **macOS (Terminal):**

  ```sh
  curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
  ```

Danach das Terminal **schließen und neu öffnen** und prüfen:

```sh
rokit --version
```

Erwartet: `rokit 1.x`. Kommt „Befehl nicht gefunden“, siehe [Häufige Probleme](#h-häufige-probleme).

---

## B. Projekt herunterladen und Spieldatei bauen

### B1. Repository klonen

Im Terminal in einen Ordner wechseln, in dem das Projekt liegen soll, und klonen:

```sh
cd ~/Documents
git clone https://github.com/ghinta/Blinkweave.git
cd Blinkweave
```

Solange der Pull Request mit dem MVP noch nicht gemergt ist, liegt der Code auf einem eigenen Branch:

```sh
git checkout claude/sweet-cray-catiam
```

Nach dem Mergen reicht der Standard-Branch `main`. Um später Änderungen zu holen: `git pull`.

### B2. Projekt-Werkzeuge installieren

Im Ordner `Blinkweave`:

```sh
rokit install
```

Rokit fragt, ob du den Werkzeugen vertraust (Rojo, Lune, Selene, StyLua, luau-lsp) – mit `y` bestätigen. Prüfen:

```sh
rojo --version
```

Erwartet: `Rojo 7.7.1`.

### B3. Rojo-Plugin für Studio installieren

```sh
rojo plugin install
```

Das kopiert das Rojo-Plugin in Studios Plugin-Ordner. **Roblox Studio danach neu starten**, falls es offen war.

### B4. Spieldatei bauen

```sh
rojo build default.project.json --output Blinkweave.rbxlx
```

Erwartet: `Built project to Blinkweave.rbxlx`. Die Datei enthält das komplette Spiel (Skripte, Licht-Einstellungen). Lobby, Turm und Spielfelder werden beim Start per Code gebaut – deshalb siehst du in Studio vor dem Starten eine fast leere Welt.

---

## C. Spiel in Roblox Studio starten

### C1. Datei öffnen

1. Roblox Studio starten.
2. **File → Open from File…** und `Blinkweave.rbxlx` aus dem Projektordner wählen.
3. Fenster einblenden, falls sie fehlen (Tab **View**): **Explorer**, **Properties** und **Output**.
   - *Explorer*: Baum aller Objekte im Spiel.
   - *Properties*: Eigenschaften des ausgewählten Objekts.
   - *Output*: Meldungen und Fehler – hier schaust du nach, wenn etwas nicht funktioniert.

Im Explorer solltest du sehen: `ServerScriptService → Server`, `ReplicatedStorage → Shared`, `StarterPlayer → StarterPlayerScripts → Client`.

### C2. Live-Verbindung mit Rojo (optional, für Code-Änderungen)

Nur nötig, wenn du Code änderst und die Änderung sofort in Studio sehen willst:

1. Im Terminal im Projektordner: `rojo serve` (Fenster offen lassen).
2. In Studio: Tab **Plugins → Rojo → Connect**.

Danach landet jede gespeicherte Code-Änderung automatisch in Studio.

### C3. Spielen

- **Play** drücken (Taste **F5**). Beenden mit **Stop** (**Shift+F5**).
- Steuerung am PC: **W A S D** laufen, **Leertaste** springen, **rechte Maustaste gedrückt** halten und ziehen = Kamera drehen, **Mausrad** = Zoom.

Erwartet nach dem Start:

- Du stehst auf einem Steinplatz vor einem Turm mit der Aufschrift **BLINKWEAVE**.
- In der Mitte des Bildschirms erscheint das Lobby-Fenster mit 10 Stockwerken. Stockwerk 1 ist frei, die anderen zeigen „Gesperrt“.
- Unten steht in Rot „Fortschritt kann gerade nicht gespeichert werden.“ – das ist in Studio **normal**, siehe [Teil F](#f-speichern-datastore-testen).
- Die Sprache der Oberfläche folgt der Sprache deines Roblox-Kontos (Deutsch oder Englisch).

---

## D. Test-Checkliste

Spielregel: Eine Fliese umschalten schaltet sie **und ihre direkten Nachbarn** (oben, unten, links, rechts) um. Ziel: **alle Lichter aus**.

Das Mini-Spielfeld rechts im HUD entspricht dem 3D-Feld, wenn du vom Eingang Richtung Tür schaust: Feld 1 ist oben links, gezählt wird zeilenweise von links nach rechts. Zum schnellen Testen zeigt `lune run scripts/levels.luau` (im Projektordner) für jedes Stockwerk das Startfeld und eine Lösung mit diesen Feldnummern. Beispiel Stockwerk 1: **Feld 4** (linke Mitte) drücken – gelöst.

Hake ab, was funktioniert. Wenn etwas nicht klappt: Output-Fenster kopieren und mitschicken.

**Lobby**

- [ ] Stockwerk 1 im Lobby-Fenster anklicken → du wirst auf eine Plattform mit Fliesen teleportiert.
- [ ] Zurück zur Lobby (Knopf **Lobby**), dann auf das leuchtende Feld vor dem Turm laufen („Turm betreten“) → startet das höchste freigeschaltete Stockwerk.
- [ ] **Ausblenden** versteckt das Lobby-Fenster; der Knopf **Stockwerke** oben holt es zurück.

**Eingabe**

- [ ] Fliese mit der Maus anklicken → sie und ihre Nachbarn wechseln den Zustand (leuchtend türkis mit dunkler Raute ↔ grau mit kleinem Punkt).
- [ ] Auf eine Fliese **springen** (Leertaste) → bei der Landung schaltet sie um.
- [ ] Feld im Mini-Spielfeld rechts anklicken → gleiche Wirkung.
- [ ] Bei jedem Zug ertönt ein kurzer Ton; „Züge“ oben links zählt mit.

**Aktionen**

- [ ] **Z** oder Knopf **Rückgängig** → macht den letzten Zug rückgängig (nur einen Schritt).
- [ ] **R** oder **Neustart** → Startzustand. In Stockwerk 1–3 (Tutorial) gehen die Züge auf 0, ab Stockwerk 4 zählen sie weiter.
- [ ] **H** oder **Hinweis** → eine Fliese wird golden markiert (3D und Mini-Spielfeld).
- [ ] Viele Klicks sehr schnell hintereinander → Meldung „Etwas langsamer, bitte.“, das Spiel bleibt stabil.

**Lösen und Aufsteigen**

- [ ] Alle Lichter aus → Fenster „Stockwerk gelöst!“ mit Sternen, Zügen, Par und Zeit, außerdem „Bestwert“.
- [ ] Die orange Tür im Norden wird durchsichtig, das Schild wechselt auf „Ausgang“.
- [ ] Durch die Tür auf das grüne Feld laufen **oder** **Nächster Stock** (Taste **N**) → nächstes Stockwerk, eine Etage höher.
- [ ] **Nochmal** startet dasselbe Stockwerk neu.
- [ ] Sterne: Par-Züge ohne Hinweis = 3 Sterne; mit einem Hinweis höchstens 2.
- [ ] Zurück in der Lobby: das gelöste Stockwerk zeigt die Sterne, das nächste ist frei.

**Besonderheiten**

- [ ] Stockwerke 4–7 sind 4×4, Stockwerke 8–10 sind 5×5.
- [ ] In Stockwerk 10 ist **Rückgängig** ausgegraut.
- [ ] Lobby-Einstellungen: **Ton: Aus** schaltet alle Töne ab; **Sprung schaltet: Aus** – Landungen schalten dann nichts mehr um.
- [ ] Von der Plattform fallen ist nicht möglich (unsichtbare Wände). Stirbst du trotzdem (z. B. Reset-Menü), landest du wieder am Eingang deines Stockwerks.

---

## E. Smoke-Test, Mehrspieler- und Handy-Test

### E1. Smoke-Test

Ein eingebauter Selbsttest prüft Welt-Aufbau, Spielfelder und Tür ohne echten Spieler.

1. Im **Explorer** `ServerScriptService` anklicken.
2. Im **Properties**-Fenster ganz unten bei **Attributes** auf **Add Attribute** (bzw. **+**) klicken.
3. Name `BlinkweaveSmokeTest`, Typ **boolean**, speichern, dann das Häkchen setzen.
4. **Play** drücken.

Erwartet im **Output**: `[Blinkweave SmokeTest] PASS`. Bei `FAIL` stehen die Fehler darunter – bitte kopieren und mitschicken. Zum Abschalten das Häkchen wieder entfernen.

### E2. Zwei Spieler gleichzeitig

1. Tab **Test** → Bereich **Clients and Servers**: links **Local Server** auswählen, Spielerzahl **2**, dann **Start**.
2. Es öffnen sich drei Fenster: ein Server und zwei Spieler.
3. In beiden Spieler-Fenstern ein Stockwerk starten.

Erwartet:

- [ ] Jeder Spieler hat seine eigene Plattform (nebeneinander), Züge des einen ändern nichts beim anderen.
- [ ] Beide können unabhängig lösen und aufsteigen.

Beenden mit **Cleanup** im Tab **Test**.

### E3. Handy und Tablet

1. Tab **Test** → **Device** (Geräte-Emulation) einschalten.
2. Oben im Spielfenster ein Handy auswählen (z. B. iPhone) und zwischen Hoch- und Querformat wechseln.
3. **Play** drücken. Die Maus simuliert jetzt Finger-Tipps.

Erwartet:

- [ ] Bewegungs-Joystick links und Sprungknopf rechts überdecken keine Spiel-Knöpfe.
- [ ] Antippen einer Fliese schaltet sie um; alle Knöpfe sind gut treffbar.
- [ ] Nichts wird von der Notch/Kamera-Aussparung verdeckt.

### E4. Gamepad (falls vorhanden)

Controller anschließen und Play drücken: **A** springen, **X** rückgängig, **Y** Hinweis. Knöpfe im HUD lassen sich mit der UI-Navigation des Controllers auswählen.

---

## F. Speichern (DataStore) testen

In einem nie veröffentlichten Studio-Projekt kann Roblox nichts speichern; das Spiel läuft dann mit Fortschritt im Arbeitsspeicher (deshalb der rote Hinweis in der Lobby). So aktivierst du echtes Speichern:

1. **File → Publish to Roblox** und eine neue Experience anlegen (Name z. B. „Blinkweave Test“). Sie bleibt privat, solange du sie nicht öffentlich schaltest.
2. Tab **Home → Game Settings → Security**: **Enable Studio Access to API Services** einschalten, **Save**.
3. Play drücken, Stockwerk 1 lösen, Stop drücken, erneut Play.

Erwartet:

- [ ] Kein roter Speicher-Hinweis mehr in der Lobby.
- [ ] Nach dem Neustart ist Stockwerk 2 weiterhin frei und Stockwerk 1 zeigt die Sterne.
- [ ] Ton- und Sprung-Einstellung bleiben erhalten.

Hinweis: Studio-Tests speichern in denselben Speicher wie das echte Spiel dieser Experience.

---

## G. Automatische Tests lokal ausführen (optional)

Diese Prüfungen laufen bei jedem Push automatisch auf GitHub (Reiter **Actions** im Repository). Lokal ausführen kannst du sie im Projektordner so:

```sh
lune run scripts/test.luau           # 112 Tests der Spiellogik, Server-Regeln und Welt
lune run scripts/levels.luau         # alle Stockwerke mit Startfeld, Par und Lösung
stylua --check src tests scripts     # Formatierung
selene src tests scripts             # Lint (lädt beim ersten Mal die Roblox-API herunter)
```

Erwartet bei den Tests als letzte Zeile: `112 tests, 0 failed`.

Die Typprüfung braucht zusätzlich die Roblox-Typdefinitionen und eine Bash-Shell (unter Windows **Git Bash**):

```sh
curl -fsSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau
bash scripts/typecheck.sh
```

Erwartet: keine Fehlermeldungen außer `Created sourcemap at sourcemap.json`.

Zum Ansehen und Bearbeiten des Codes eignet sich **Visual Studio Code** (<https://code.visualstudio.com>) mit den Erweiterungen **Luau Language Server**, **StyLua** und **Selene**.

---

## H. Häufige Probleme

| Problem | Lösung |
|---|---|
| `rokit`, `rojo` oder `lune`: „Befehl nicht gefunden“ | Terminal schließen und neu öffnen. Unter Windows ggf. abmelden und neu anmelden, damit der neue `PATH` gilt. |
| `rokit install` meldet ein GitHub-Limit | Kurz warten und erneut versuchen. |
| Rojo-Plugin fehlt in Studio | `rojo plugin install` ausführen und Studio komplett neu starten. |
| Rojo **Connect** schlägt fehl | Läuft `rojo serve` im Projektordner? Port muss `34872` sein. Bei Versionswarnung `rojo plugin install` erneut ausführen. |
| Nach Play passiert nichts, kein Lobby-Fenster | Im **Output** nach roten Fehlermeldungen suchen und mitschicken. Prüfen, ob im Explorer `ServerScriptService → Server → Main` existiert. |
| Roter Hinweis „Fortschritt kann nicht gespeichert werden“ | In Studio ohne Teil F normal. |
| Gelbe Warnungen mit `[Progression]` oder `[Analytics]` im Output | In Studio ohne API-Zugriff normal; sie beeinflussen das Spiel nicht. |
| Keine Töne | Lobby-Einstellung **Ton** prüfen. Die Töne sind vorläufige Roblox-Standardklänge und werden vor dem Launch ersetzt. |
| Klick auf eine Fliese tut nichts | Nur eigene Fliesen reagieren, und nur solange das Stockwerk nicht gelöst ist. |

---

## Fehler melden

Hilfreich sind: Was du gemacht hast, was passiert ist, was du erwartet hast – und der Text aus dem **Output**-Fenster (Rechtsklick → **Copy** oder markieren und kopieren). Ein Screenshot hilft bei Darstellungsfehlern.
