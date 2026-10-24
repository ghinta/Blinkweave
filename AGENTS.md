# AGENTS.md — instructions for coding agents

Read `README.md` first; it is the product specification. This file covers how
to work in the code.

## Commands

```sh
rokit install                      # pinned tools (or: scripts/install-tools.sh)
stylua --check src tests scripts   # formatting
selene src tests scripts           # lint
scripts/typecheck.sh               # strict Luau type check against Roblox API
lune run scripts/test.luau         # headless tests (filter: ... test.luau Solver)
lune run scripts/levels.luau       # print every floor's board, par and solution
rojo build default.project.json --output build/blinkweave.rbxlx
rojo serve                         # live sync into Studio
```

All five checks run in `.github/workflows/ci.yml` and must pass before merging.

## Layout

| Path | Runs in | Notes |
|---|---|---|
| `src/shared/` | ReplicatedStorage | `Types` (requests, snapshots, level type), `Protocol` (remotes, tags, attributes) |
| `src/server/logic/` | ServerScriptService | Pure Luau rules: `ToggleEngine`, `GF2Solver`, `PuzzleGenerator`, `Prng`, `LevelCodec`, `Scoring`, `LevelLibrary` |
| `src/server/levels/Catalog.luau` | ServerScriptService | Data-only floor definitions; never replicated to clients |
| `src/server/services/` | ServerScriptService | `SessionManager`, `RequestValidator`, `RateLimiter`, `ProgressModel`, `ProgressStore` are pure; `GameService`, `ActionGateway`, `ProgressionService`, `Analytics` use Roblox APIs |
| `src/server/world/` | ServerScriptService | Lobby and chamber geometry built from code |
| `src/server/dev/SmokeTest.luau` | Studio only | Runs when ServerScriptService has attribute `BlinkweaveSmokeTest = true` |
| `src/client/` | StarterPlayerScripts | `Net` (state + actions), `Hud`, `BoardController`, `InputController`, `Audio`, `Strings` |
| `tests/*.spec.luau` | Lune | Loaded through `scripts/lib/Loader.luau`, which maps `script.Parent`/`game:GetService` requires from `default.project.json` |

## Rules

- `--!strict` in every Luau file. Keep `scripts/typecheck.sh` clean.
- The server is authoritative. Clients send intents (`ActionRequest`), never
  board state, move counts or completion. Every remote payload goes through
  `RequestValidator`, the rate limiter and `SessionManager` checks
  (session id, expected revision, bounds).
- Pure modules (everything in `logic/` and the pure services listed above)
  must not create instances or use `task`, `os.clock` or Roblox services
  other than requiring `ReplicatedStorage.Shared` modules; pass time and
  dependencies in. That keeps them testable in Lune.
- Roblox Parts are a view. `SessionManager` owns board state; tiles mirror it
  through the `BlinkweaveLit` attribute.
- Levels: author `id`, size, `rule`, `seed`, `scrambleMoves`, `allowUndo`,
  `tutorial` only. `parMoves` is computed by the solver; authoring it fails
  validation. Changing a seed or size changes the board: update the pinned
  boards in `tests/Levels.spec.luau` deliberately.
- New toggle rules (diagonal, row/column, blocked cells) need their own
  tutorial floor and tests before use; never change rules inside a floor.
- Persistence only through `ProgressModel.merge` (monotonic) via `UpdateAsync`.
- No monetization, third-party telemetry SDKs, external backends or
  marketplace assets. Audio uses `rbxasset://` sounds shipped with Roblox.
- UI strings live in `src/client/Strings.luau` (German and English).
- Never put model or tool identifiers in commits or code comments.

## Acceptance criteria (definition of done)

- [ ] Toggle rule: self + valid orthogonal neighbours; pressing twice restores the board.
- [ ] Generator: ≥1,000 solvable, unsolved puzzles across 3×3/4×4/5×5 and seeds.
- [ ] Solver: valid solutions; any "par"/minimum claim is proven (null-space enumeration).
- [ ] Remote actions: out-of-bounds, duplicate, stale and rapid-fire requests are rejected.
- [ ] Two concurrent players have independent boards and saved progress.
- [ ] Save/load survives reconnects; data-store failures never break gameplay.
- [ ] Playable with touch only, mouse only, keyboard, or gamepad.
- [ ] Formatting, lint, type check, tests and Rojo build pass in CI.
- [ ] Studio: smoke test prints `PASS`; 2-client local server test; phone portrait/landscape emulation.
