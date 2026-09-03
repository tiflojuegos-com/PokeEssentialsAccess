# Engines

Essentials exists in versions with incompatible APIs and real fangames mix them.
`core/foundation/engine.rb` answers which engine is running; all gating goes through `Engine.has?`.

## Eras

| Era | Versions | Data API | Battle scene | Player | Telltale |
|---|---|---|---|---|---|
| gen-6 | v16–v17 | `PB*` tables | `PokeBattle_Scene` | `$Trainer` | no `GameData::Species` |
| GameData transitional | v18 | `GameData::*` | `PokeBattle_Scene` | `$Trainer` | `GameData::Species` without `Battle::Scene` |
| GameData | v19–v21.1 | `GameData::*` | `Battle::Scene` | `$player` | `Battle::Scene` |
| GameData + UI rework | v22 | `GameData::*` | `Battle::Scene` | `$player` | `UI::BaseScreen` with version ≥ 21.9 |
| Sky (fork) | v21.1 with the v22 UI | `GameData::*` | `Battle::Scene` | `$player` | `UI::BaseScreen` with version < 21.9 |

Eras are named after their data API, not "old/modern". `Engine.kind` tells only two apart, `:gen6` and
`:gamedata`; every finer cut is a capability.

## Detection

`gamedata?` is exactly `defined?(GameData) && defined?(GameData::Species)`; `gen6?` is its negation and
`kind` returns the symbol. `Engine.player` resolves `$player` or, failing that, `$Trainer`. `Engine.fork`
gives `:sky` with `GameData`, `UI::BaseScreen` and `version < 21.9`, and `nil` in every other case.

`Engine.version` is a memoised Float **for the diagnostic line only**: it probes `Essentials::VERSION`,
`ESSENTIALS_VERSION`, structure (with `GameData`, 19.0 if `Battle::Scene` exists and 18.0 if not), a parsed
`ESSENTIALSVERSION` floored to 17.0 —some gen-6 forks write it as free text— and 16.0. The transitional era
comes from structure and not from `$Trainer` because at the title screen the player object does not exist.

## Capabilities

A capability is the question "can this engine do X?" answered against the runtime: a boolean lambda, a
constant name, or a constant plus a method. Never a version number, because fangames mix eras: a fork that
backports a feature activates with no code change. The era folders ([01-overview](01-overview.md)) say where
a capability appeared, not when it activates.

`Engine.has?` is the single gate and takes three shapes:

| Shape | Example | Checks |
|---|---|---|
| Registered symbol | `has?(:ui_rework)` | the matching `CAPABILITIES` entry |
| `"A::B::C"` | `has?("UI::BagVisuals")` | that the constant exists, via `PokeAccess.const_at` |
| `"Class#method"` | `has?("Battle::Scene::MenuBase#setIndexAndMode")` | the constant **and** the instance method, public or private |

```ruby
# core/battle/gen6/battle_g6.rb
mega_setter = ["megaButton=", "mode="].detect { |m| PokeAccess::Engine.has?("FightMenuDisplay##{m}") }
```

Any exception answers `false`, and so does an unregistered symbol: it is noted once through `log_once`,
because a typo would silence a whole family of readers with no noise at all.

### The table

| Capability | Probe | What it is |
|---|---|---|
| `:gamedata` | `lambda { gamedata? }` | GameData era |
| `:gen6` | `lambda { gen6? }` | gen-6 era |
| `:sky_fork` | `lambda { fork == :sky }` | the Sky fork |
| `:ui_rework` | `"UI::BaseScreen"` | the v22 `UI::` rework |
| `:battle_scene` | `"Battle::Scene"` | the v19+ battle scene |
| `:dbk` | `"Battle#pbToggleSpecialActions"` | Deluxe Battle Kit, a third-party plugin |
| `:mui` | `"UIHandlers"` | Modular UI Scenes, a third-party plugin |

`:dbk` and `:mui` are not engine features and gate nothing: they reopen classes that exist in all thirteen
games, so only a method identifies them, and they are registered so they show in the diagnostic. Their
readers bind hook by hook with `:optional`, which survives a partial plugin install.

Only transversal capabilities go here; a one-off screen passes its class name to `has?` directly, which is
what every gate in the core does today. What consumes the symbol shape is the diagnostic's `caps=` list,
which walks `CAPABILITIES` instead of enumerating them ([07-diagnostics](07-diagnostics.md)).

## Class names

Era and class name are independent. Some games ship `GameData` while keeping the v16 class names, and others
declare the old names as empty subclasses of the new ones so older scripts keep working. Either way both
classes exist at once and hooking the wrong one mutes or doubles, which is why the era is asked of the engine
and the name resolved separately rather than one being inferred from the other.

| Method | Returns | For |
|---|---|---|
| `scene_classes(*names)` | the ones that exist, dropping any another already covers by inheritance or by being the same class | one screen with several unrelated aliases |
| `scene_class(*names)` | the first of `scene_classes`, or `nil` | aliases of one and the same screen |
| `era_scene(era, own, other)` | the name to hook, or `""` | a reader written against ONE data API |

`era_scene` lets the name decide while only one of the two aliases is around, and breaks the tie by era only
when both exist, which is what a compatibility layer produces. `""` binds nothing.

```ruby
# core/party/gen6/summary_g6.rb
SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonSummaryScene", "PokemonSummary_Scene")
```

## The hybrid band

Between the two eras sit games built on Essentials v18: `GameData` already in, but still `$Trainer` and
`PokeBattle_Scene`. Gen-6 class names with modern internals, which is the combination that breaks any rule of
the form "if it is called this, it belongs to that era".

| Point | What happens |
|---|---|
| `kind` | `:gamedata`; the active data provider is `DataV21` (`core/data/v21/data_v21.rb`) |
| Attribute names | they keep `base_damage` instead of `power`, so `move_power` tries both through `attr_of` |
| Battle | they hook through `PokeBattle_Scene`, in `core/battle/gen6/battle_g6.rb` |
| Argument order | `pbLevelUp` passes speed last, not fourth as v16-17 does; reading the other order does not go quiet, it announces three real numbers under the wrong stat names |
| Player | `Engine.player` falls back to `$Trainer` |
| Pokédex | `seen?`/`owned?` instead of the gen-6 arrays (`core/util/player.rb`) |

```ruby
# core/battle/gen6/battle_g6.rb -- same scene class, two argument orders
LEVELUP_MODERN_ORDER = PokeAccess::Engine.gamedata?
```

## Ruby 1.8.7

Gen-6 games run mkxp-z on Ruby 1.8.7 and modern ones on 3.x. `core/` loads in both, so most of the tree is
**dual code**, and a 1.9+ construct there does not warn: it raises `SyntaxError` and aborts the whole file.
Boot notes it and carries on, so the symptom is not a crash but a module that disappears. Exemption is by
PATH: the `MODERN` constant, in `check187.py` and `check187_real.rb`, both of them.

| Exempt (Ruby 3.x) | Checked (1.8.7) |
|---|---|
| any path containing `/v21/` or `/v22/` | the rest of `core/` and `loader/*.rb` |
| `games/anil/`, `games/royal/`, `games/relict/`, `games/emerald/`, `games/infinitefusion/`, `games/infinitefusion_hoenn/` | the rest of `games/` |
| | all of `plugins/`: a third-party plugin can be installed in a gen-6 fangame |

### Banned in dual code

| Do not write | Write |
|---|---|
| `list.map(&:name)` | `list.map { \|x\| x.name }` |
| `->(x) { ... }` | `lambda { \|x\| ... }` |
| `obj&.method` | `(obj.method rescue nil)` |
| `v.round(2)`, `.ceil(n)`, `.floor(n)` | `(v * 100).round / 100.0` (1.8.7 takes no argument) |
| `n.clamp(0, 100)` | `[[n, 0].max, 100].min` |
| `h.dig(:a, :b)` | `(h[:a] && h[:a][:b])` |
| `list.each_with_object({}) { ... }` | `h = {}; list.each { ... }; h` |
| `%i[a b]`, `<<~TEXT`, `{ key: value }` | `[:a, :b]`, string concatenation, `{ :key => value }` |
| `.transform_keys`, `.transform_values`, `.then`, `.yield_self`, `.tally`, `.filter_map` | a hand-written `each` or `map` |

### Two syntax traps and one semantic one

**Leading dot on a line.** The dot goes at the end of the previous line: `select { ... }.` and `map` on the
next one. A constant chained the other way killed `config_menu.rb`, and without that module the map poll
raised every frame.

**`rescue` hanging off a block.** It may only hang off `begin`, `def`, `class` or `module`; inside a `do` or
a `{` you have to open a `begin`.

**`return` inside `define_method`.** The body is a block, and there `return` exits the method that defined
it: use `next` (`core/menus/scene_watcher.rb`). It is valid syntax, so nothing catches it.

### The two checkers

`test/check187.py` looks for patterns —leading dot, block `rescue` and a curated list of 1.9+ APIs— and needs
nothing installed. `test/check187_real.rb` parses every dual file with a real 1.8.7 interpreter, without
executing it, and only runs when one is found at `tools/ruby-1.8.7-*/bin/ruby.exe` next to the repo or at
`RUBY187`: the pattern checker only knows what it was taught, the parser knows the whole language.

```bash
python test/check187.py                       # the whole tree
python test/check187.py core/nav/locator.rb   # or just what you touched
```
