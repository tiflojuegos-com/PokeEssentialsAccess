# Diagnostics

How to find out why something is not being read. First stop for any bug report: the dump states which
version is running, which engine was detected, which hooks bound and which plugins are present. Sources:
`core/input/diag.rb`, `core/util/recorder.rb`, `core/foundation/plugins.rb`. Dump lines are quoted verbatim,
so the Spanish field names below are the code's own.

## Keys

| Key | What it does | Output |
|---|---|---|
| Ctrl+Alt+F8 | Toggles the mod; re-enabling also retries speech init | Spoken |
| Ctrl+Alt+F9 | Full dump, all 10 sections | `<DATA>/diag.txt`, appended. `DATA` is `accessibility/data`, or the game's AppData folder when that one is not writable |
| Ctrl+Alt+F10 | Short spoken diagnostic | Voice only |

The three chords are fixed in `core/input/keyboard.rb` and are not rebindable; what the player rebinds lives
in `Config.keys`. All three are polled **before** the `@enabled` and `focused?` gates, so they answer with
the mod switched off. F9 only says whether it saved ("Diagnostics saved" / "Diagnostics not saved"); the
detail goes to the file. F10 writes nothing and speaks, joined by `". "`:

```
scene Scene_Map. map Viridian City 24,17. last House. 3 hooks missing
```

Map and position only on the field; `last` only if something was spoken; hooks only if any are missing.

## Anatomy of the dump

Header `=== PokeAccess diag <time> ===`, then the sections in `DIAG_ALL` order. The Menu column is the debug
menu subset that copies that section **to the clipboard**; the full dump goes to the file.

| # | Section | Menu | What it carries |
|---|---|---|---|
| 1 | `diag_perf` | Performance | Avg/max ms per label since the previous dump, and **resets** the window |
| 2 | `diag_focus` | Events and locator | Identification, focus, scene, hooks, plugins and config |
| 3 | `diag_map` | Map and navigation | Map, size, position, facing, event count, neighbouring terrain |
| 4 | `diag_locator` | Events and locator | Categories, active category and index, target list |
| 5 | `diag_pathfinder` | Map and navigation | Reachable-tiles flood and the route to the target |
| 6 | `diag_surface` | Map and navigation | Surface labels and terrain cues |
| 7 | `diag_audio3d` | 3D audio | Positional engine, device, channels, gate and nearby events |
| 8 | `diag_scene` | Scene and runtime | Battle, player sprite, pictures, choices, live command windows |
| 9 | `diag_runtime` | Scene and runtime | Introspection of the live scene: its own methods and ivars |
| 10 | `diag_polls` | Performance | `Input.update` layers and per-frame poller count |

Every section runs under `rescue`: a failing one writes `<section>: ERR <class>: <message>` and the rest
continues. A single failing field reads `ERR(<class>)`, and long ones are truncated with `...[cortado]`. A
profile adds its section with `Keys.register_diag_section(name, group) { |o| ... }` (`:scene` by default).

### The identification lines

Emitted by `diag_engine`, inside `diag_focus`. These are read first.

| Line | Field | What it says |
|---|---|---|
| `mod:` | — | Installed version, from `version.json`. `?` when it could not be read |
| `engine:` | `kind` | `gamedata` or `gen6`: the data-API era |
| | `version` | Float, **informative only**: real fangames mix eras. Readers gate on capability, never on this number — see [02-engines](02-engines.md) |
| | `fork` | `nil`, or `:sky` on the La Base de Sky fork |
| | `caps` | Registered capabilities answering true, plus `PokeBattle_Scene`/`$player`/`$Trainer`. Omits `:gamedata`, `:gen6` and `:sky_fork`, which `kind` and `fork` already state |
| `voice:` | `prism` | `false` = `prism_pea.dll` did not load |
| | `ready` | `false` = no backend was acquired |
| | `backend` | `"NVDA"`, `"JAWS"`, `"SAPI 5"`… or `""` |
| `timing:` | `uptime_scale` `render_fps` | `1000000.0` on mkxp-z builds whose `System.uptime` counts microseconds; the fps figure is measured between two dumps and should match `frame_rate` |

```
mod: 0.2.5
engine: kind=gamedata version=21.1 fork=:sky caps=[battle_scene, ui_rework, $player]
engine: kind=gen6 version=16.0 fork=nil caps=[PokeBattle_Scene, $Trainer]
voice: prism=true ready=true backend="NVDA" speaking=false
```

### Hooks and plugins

| Line | Field | What it says |
|---|---|---|
| `hooks:` | `missing` | Class present, method absent. By contract, **the typo list**. Also written at boot to `accessibility/data/loader_error.txt`, as `[diag] enganches sin metodo (posible typo): ...` |
| | `fn_absent` | Global functions found nowhere. Informative: legitimate cross-game variance |
| | `overrides` | Replacements installed by `override`, as `"Class.method (tag)"` |
| `guard_suppressed=` | | `outer>inner` pairs the reentrancy guard dropped |
| `caches=` `data_err=` | | Modules that registered a reset, and data lookups that fell back |
| `plugins:` | `cargados` | Plugin readers from `plugins/` loaded this session |
| | `sin_declarar` | **The key line**: the game ships a plugin we know and the profile never declared its reader. That screen is mute and nothing else would say so |
| `plugins_juego:` | | The game's own register, via `PluginManager` |

`plugins_juego` also lists plugins the mod has never heard of, exactly the set a screen with no reader is
most likely to belong to. It has three values, and they **do not mean the same thing**:

| Value | Meaning |
|---|---|
| `Easy Questing 1.0.4, Tip Cards 2.1` | The list: `"name version"` per entry, sorted, truncated at 400 |
| `ninguno registrado` | `PluginManager` exists and its list is empty |
| `sin PluginManager` | **There is no register to query.** Older games paste plugin code straight into the script list, so nothing registers: "none installed" would be a lie here |

## The session recorder

Started from the debug menu, not from a key; it writes
`accessibility/data/recordings/rec-YYYYMMDD-HHMMSS.txt` and reports the event count when stopped. It turns a
play session into a **transcript**: what the mod saw and what it said, in order. It hooks nothing inside the
readers — everything reaches it through `PokeAccess.on_speak` and a per-frame read of state the mod already
keeps — so the instrument can never break a reader, and costs nothing when off. Tab-separated, text last:

| Line | Fields | When |
|---|---|---|
| `# pea-recording 1` | kind, version, fork | First line |
| `map` | id, name | On map change |
| `pos` | x, y | On movement |
| `scene` | class | On scene or `busy_reason` change |
| `sel` | index, target name | On locator selection change |
| `say` | 0/1 interrupt, text | Every spoken line |
| `in` | `confirm`, `cancel`, `dir` or `tecla:<name>` | Every player input |
| `diag` | reason, one section line | At start, on map change and on scene change |

The embedded `diag` rows are what makes the attachment worth having: the report answers what the mod
**saw**, not just what it said. A dump identical to the previous one for the same reason writes a single
`(igual que el anterior)` line; `diag_perf` and `diag_polls` are deliberately excluded (the first would
reset the player's own measurement window, the second is a micro-benchmark). Attached to a report it audits
itself through `test/support/replay.rb`, and any file dropped into `test/fixtures/recordings/` becomes a
regression test.

| Mode | What it catches |
|---|---|
| SILENCE | The selection moved and nothing was spoken afterwards |
| REPEAT | The same line twice with **nothing** from the player in between (hence the recorded keys) |
| RAW | A spoken line still carrying RPG Maker control codes (`\c[1]`, `\PN`) |

## Symptom → what to check → likely cause

| Symptom | What to check | Likely cause |
|---|---|---|
| **Nothing** is read | `mod:` | **Stale install: cause #1.** The installed version is not the one you think |
| | `voice: prism=false` | `prism_pea.dll` did not load: `accessibility/lib/` missing, or arch mismatch |
| | `voice: ready=false` | No screen-reader backend. Ctrl+Alt+F8 twice retries init |
| | `enabled=false` / `focused?=false` | The mod is off (Ctrl+Alt+F8), or window focus is not being detected |
| **One screen** is not read | `scene=` | The class name to search for in the game's script dump |
| | `plugins: sin_declarar` | The profile never declared the reader for a plugin the game does ship |
| | `plugins_juego:` | The screen belongs to a plugin the mod does not know yet |
| | `hooks: missing` | Typo in a hooked method name |
| | `diag_runtime` | Custom screen with no reader: gives the methods and ivars to write one |
| Read **twice** | `live_cmd_windows=` | The generic command-window reader sees it too: claim the window with `PokeAccess.dedicate`. Or two related class names hooked at once, where `Engine.scene_classes` keeps only the ancestor |
| **Wrong** or empty value | The real ivar, against the script dump | Accessor name differs across games. See below |
| **3D audio** is silent | `audio3d: available=false` | The native dll is missing, or the architecture does not match |
| | `audio3d: ready=false boot_tried=true` | `INIT` did not return 1: Steam Audio failed to start |
| | `audio3d: sound_nav=false` | Switched off in config |
| Sounds while walking, silent when still | `audio3d gate:` | Per-reason tally. Loops are only repositioned on a tile change; a shut gate leaves them muted |
| One map runs **slow** | `perf:` | F9 on entering, walk a bit, F9 again, and compare `map_poll` against `audio3d` |

## Silent failures

The most expensive failure in the project and the only one that leaves no trace: **the class exists, the
method exists, the hook binds perfectly, and the ivar being read is named differently in that game.** It
reads `nil` forever, with no exception, no log line and no entry in `Hooks.missing`, which only records
class-present-method-absent. Real cases: `totalpp` vs `total_pp`, `power` vs `base_damage`. Ask for both:

```ruby
PokeAccess.attr_of(obj, :totalpp, :total_pp)
```

The second shape is about classes: a fork declares the old names as **empty subclasses** of the new ones and
instantiates only the new one, so the hook binds to a class the game never builds. It does not reach
`missing` either, because the class does exist; `Engine.scene_classes` keeps only the ancestor.

**How to confirm it:** an installed hook does not prove the data is where you think. Cross-check against the
game's script dump; without one, `diag_runtime` gives the same live — methods and ivars of the active scene:

```
$scene=PokemonPartyScreen methods=["pbChooseAblePokemon", "pbDisplay", ...]
  ivars: ["@index=0", "@party=Array(6)[PokeBattle_Pokemon...]", "@scene=PokemonParty_Scene"]
```

An ivar under the expected name with a `nil` value confirms the diagnosis; a different name resolves it.
