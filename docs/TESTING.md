# Testing Blinkweave – a beginner's guide

This guide assumes **nothing**: no tools installed, no Roblox experience.
It takes you from installation to a complete test of the MVP.

You need a computer running **Windows 10/11** or **macOS** (Roblox Studio does not run on Linux or Chromebooks) and about 30–45 minutes.

**Overview**

| Part | What | Required? |
|---|---|---|
| A | Install the tools (Roblox Studio, Git, Rokit, Rojo) | yes |
| B | Download the project and build the place file | yes |
| C | Start the game in Roblox Studio | yes |
| D | Work through the test checklist | yes |
| E | Smoke test, multiplayer and phone tests | recommended |
| F | Test saving (DataStore) | optional |
| G | Run the automated checks locally | optional |
| H | Common problems | if needed |

A few terms first:

- **Roblox Studio**: the official program for building and testing Roblox games.
- **Rojo**: copies the code files from this repository into Roblox Studio. Without Rojo you would have to paste every file into Studio by hand.
- **Rokit**: installs Rojo and the other tools in exactly the versions pinned in `rokit.toml`.
- **Terminal**: the window for typing commands. On Windows use **PowerShell** (Start menu → type "PowerShell"), on macOS use **Terminal** (Spotlight → "Terminal").

---

## A. Install the tools

### A1. Roblox account and Roblox Studio

1. If you don't have one yet, create an account at <https://www.roblox.com>.
2. Download Roblox Studio: <https://create.roblox.com> → **Start Creating** or **Download Studio**.
3. Run the installer and sign in to Studio with your Roblox account.

### A2. Git

Git downloads the project from GitHub.

- **Windows:** download <https://git-scm.com/download/win> and install it with the default settings. This also installs **Git Bash** (only needed for part G).
- **macOS:** type `git --version` in Terminal. If Git is missing, macOS offers to install the "Command Line Tools" – accept.

Check (open a new terminal window):

```sh
git --version
```

Expected: a version number, e.g. `git version 2.x`.

### A3. Rokit

- **Windows (PowerShell):**

  ```powershell
  Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
  ```

- **macOS (Terminal):**

  ```sh
  curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
  ```

Then **close and reopen** the terminal and check:

```sh
rokit --version
```

Expected: `rokit 1.x`. If you get "command not found", see [Common problems](#h-common-problems).

---

## B. Download the project and build the place file

### B1. Clone the repository

In the terminal, go to the folder where the project should live and clone it:

```sh
cd ~/Documents
git clone https://github.com/ghinta/Blinkweave.git
cd Blinkweave
```

Until the MVP pull request is merged, the code lives on its own branch:

```sh
git checkout claude/sweet-cray-catiam
```

After the merge, the default branch `main` is enough. To fetch later changes: `git pull`.

### B2. Install the project tools

Inside the `Blinkweave` folder:

```sh
rokit install
```

Rokit asks whether you trust the tools (Rojo, Lune, Selene, StyLua, luau-lsp) – confirm with `y`. Check:

```sh
rojo --version
```

Expected: `Rojo 7.7.1`.

### B3. Install the Rojo plugin for Studio

```sh
rojo plugin install
```

This copies the Rojo plugin into Studio's plugin folder. **Restart Roblox Studio** afterwards if it was open.

### B4. Build the place file

```sh
rojo build default.project.json --output Blinkweave.rbxlx
```

Expected: `Built project to Blinkweave.rbxlx`. The file contains the whole game (scripts, lighting settings). The lobby, tower and puzzle boards are built by code when the game starts – so before you press Play, the world in Studio looks almost empty.

---

## C. Start the game in Roblox Studio

### C1. Open the file

1. Start Roblox Studio.
2. **File → Open from File…** and choose `Blinkweave.rbxlx` from the project folder.
3. Show these windows if they are missing (**View** tab): **Explorer**, **Properties** and **Output**.
   - *Explorer*: tree of every object in the game.
   - *Properties*: properties of the selected object.
   - *Output*: messages and errors – look here whenever something doesn't work.

In the Explorer you should see `ServerScriptService → Server`, `ReplicatedStorage → Shared` and `StarterPlayer → StarterPlayerScripts → Client`.

### C2. Live sync with Rojo (optional, for code changes)

Only needed if you change code and want to see the change in Studio right away:

1. In the terminal, inside the project folder: `rojo serve` (keep the window open).
2. In Studio: **Plugins** tab → **Rojo → Connect**.

From then on, every saved code change appears in Studio automatically.

### C3. Play

- Press **Play** (key **F5**). Stop with **Stop** (**Shift+F5**).
- PC controls: **W A S D** to walk, **Space** to jump, hold the **right mouse button** and drag to turn the camera, **mouse wheel** to zoom.

Expected after starting:

- You stand on a stone plaza in front of a tower labelled **BLINKWEAVE**.
- The lobby window with 10 floors appears in the middle of the screen. Floor 1 is unlocked, the others show "Locked".
- At the bottom it says in red "Progress can't be saved right now." – this is **normal** in Studio, see [part F](#f-test-saving-datastore).
- The UI language follows your Roblox account language (English or German). This guide quotes the English texts.

---

## D. Test checklist

Game rule: flipping a tile also flips **its direct neighbours** (up, down, left, right). Goal: **all lights off**.

The mini board on the right of the HUD matches the 3D board as seen from the entrance looking towards the door: cell 1 is the top-left, numbered row by row from left to right. For quick testing, `lune run scripts/levels.luau` (in the project folder) prints every floor's starting board and a solution using these cell numbers. Example for floor 1: press **cell 4** (middle left) – solved.

Tick off what works. If something fails, copy the Output window and send it along.

**Lobby**

- [ ] Click floor 1 in the lobby window → you are teleported to a platform with tiles.
- [ ] Go back to the lobby (**Lobby** button), then walk onto the glowing pad in front of the tower ("Enter the tower") → starts the highest unlocked floor.
- [ ] **Hide** hides the lobby window; the **Floors** button at the top brings it back.

**Input**

- [ ] Click a tile with the mouse → it and its neighbours change state (glowing cyan with a dark diamond ↔ grey with a small dot).
- [ ] **Jump** onto a tile (Space) → it flips when you land.
- [ ] Click a cell in the mini board on the right → same effect.
- [ ] Every move plays a short sound; "Moves" at the top left counts up.

**Actions**

- [ ] **Z** or the **Undo** button → undoes the last move (one step only).
- [ ] **R** or **Restart** → back to the starting board. On floors 1–3 (tutorial) the move count resets to 0; from floor 4 on it keeps counting.
- [ ] **H** or **Hint** → one tile is highlighted in gold (in 3D and on the mini board).
- [ ] Many very fast clicks → message "A little slower, please.", the game stays stable.

**Solving and climbing**

- [ ] All lights off → "Floor solved!" window with stars, moves, par and time, plus "Best".
- [ ] The orange door to the north becomes see-through and its sign changes to "Exit".
- [ ] Walk through the door onto the green pad **or** press **Next floor** (key **N**) → next floor, one level higher.
- [ ] **Play again** restarts the same floor.
- [ ] Stars: par moves without hints = 3 stars; with one hint at most 2.
- [ ] Back in the lobby: the solved floor shows its stars and the next one is unlocked.

**Special cases**

- [ ] Floors 4–7 are 4×4, floors 8–10 are 5×5.
- [ ] On floor 10, **Undo** is greyed out.
- [ ] Lobby settings: **Sound: Off** mutes all sounds; **Jump flips: Off** – landings no longer flip tiles.
- [ ] You cannot fall off the platform (invisible walls). If your character dies anyway (e.g. via the reset menu), you respawn at the entrance of your floor.

---

## E. Smoke test, multiplayer and phone tests

### E1. Smoke test

A built-in self-test checks world building, boards and door without a real player.

1. In the **Explorer**, click `ServerScriptService`.
2. At the bottom of the **Properties** window, under **Attributes**, click **Add Attribute** (or **+**).
3. Name `BlinkweaveSmokeTest`, type **boolean**, save, then tick the checkbox.
4. Press **Play**.

Expected in the **Output**: `[Blinkweave SmokeTest] PASS`. On `FAIL` the failures are listed below it – please copy and send them. To turn the test off, untick the checkbox again.

### E2. Two players at once

1. **Test** tab → **Clients and Servers** area: select **Local Server**, set players to **2**, then **Start**.
2. Three windows open: one server and two players.
3. Start a floor in both player windows.

Expected:

- [ ] Each player has their own platform (side by side); moves of one player don't change anything for the other.
- [ ] Both can solve and climb independently.

Stop with **Cleanup** in the **Test** tab.

### E3. Phone and tablet

1. **Test** tab → turn on **Device** (device emulation).
2. Pick a phone at the top of the game view (e.g. an iPhone) and switch between portrait and landscape.
3. Press **Play**. The mouse now simulates finger taps.

Expected:

- [ ] The movement joystick on the left and the jump button on the right don't cover any game buttons.
- [ ] Tapping a tile flips it; all buttons are easy to hit.
- [ ] Nothing is hidden behind the notch/camera cut-out.

### E4. Gamepad (if you have one)

Connect a controller and press Play: **A** jumps, **X** undoes, **Y** shows a hint. HUD buttons can be selected with the controller's UI navigation.

---

## F. Test saving (DataStore)

In a Studio project that has never been published, Roblox cannot save anything; the game then keeps progress in memory only (hence the red notice in the lobby). To enable real saving:

1. **File → Publish to Roblox** and create a new experience (e.g. "Blinkweave Test"). It stays private as long as you don't make it public.
2. **Home** tab → **Game Settings → Security**: turn on **Enable Studio Access to API Services**, then **Save**.
3. Press Play, solve floor 1, press Stop, press Play again.

Expected:

- [ ] No red save notice in the lobby anymore.
- [ ] After the restart, floor 2 is still unlocked and floor 1 shows its stars.
- [ ] Sound and jump settings are kept.

Note: Studio tests save to the same storage as the live game of this experience.

---

## G. Run the automated checks locally (optional)

These checks run automatically on GitHub on every push (**Actions** tab of the repository). To run them locally in the project folder:

```sh
lune run scripts/test.luau           # 112 tests of game logic, server rules and world building
lune run scripts/levels.luau         # every floor with starting board, par and solution
stylua --check src tests scripts     # formatting
selene src tests scripts             # lint (downloads the Roblox API on first run)
```

Expected last line of the tests: `112 tests, 0 failed`.

The type check also needs the Roblox type definitions and a Bash shell (on Windows use **Git Bash**):

```sh
curl -fsSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau
bash scripts/typecheck.sh
```

Expected: no errors, only `Created sourcemap at sourcemap.json`.

To read and edit the code, **Visual Studio Code** (<https://code.visualstudio.com>) with the extensions **Luau Language Server**, **StyLua** and **Selene** works well.

---

## H. Common problems

| Problem | Fix |
|---|---|
| `rokit`, `rojo` or `lune`: "command not found" | Close and reopen the terminal. On Windows, sign out and back in if needed so the new `PATH` applies. |
| `rokit install` reports a GitHub rate limit | Wait a moment and try again. |
| Rojo plugin missing in Studio | Run `rojo plugin install` and fully restart Studio. |
| Rojo **Connect** fails | Is `rojo serve` running in the project folder? The port must be `34872`. On a version warning, run `rojo plugin install` again. |
| Nothing happens after Play, no lobby window | Look for red errors in the **Output** and send them. Check that `ServerScriptService → Server → Main` exists in the Explorer. |
| Red notice "Progress can't be saved right now." | Normal in Studio without part F. |
| Yellow warnings with `[Progression]` or `[Analytics]` in the Output | Normal in Studio without API access; they don't affect the game. |
| No sound | Check the lobby setting **Sound**. The sounds are temporary Roblox default sounds and will be replaced before launch. |
| Clicking a tile does nothing | Only your own tiles react, and only while the floor is not solved yet. |

---

## Reporting bugs

Helpful: what you did, what happened, what you expected – and the text from the **Output** window (right-click → **Copy**, or select and copy). A screenshot helps with display issues.
