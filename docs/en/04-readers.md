# Readers

A reader is the code hooked onto a game screen that decides **what** to say and **when** to say it. It
lives in `core/<module>/`, `plugins/<plugin>.rb` or `games/<profile>/`, depending on who owns the screen.
How it attaches is in [03-hooks](03-hooks.md); this is what goes inside the body.

## Speaking

| Call | File | What it does |
|---|---|---|
| `PokeAccess.speak(text, interrupt = true)` | `core/speech/speech.rb` | Speaks through the active screen reader. Collapses whitespace, ignores empty text. |
| `PokeAccess.speak_clean(text, interrupt = true)` | `core/speech/speech.rb` | `speak(clean(text), interrupt)`. |
| `PokeAccess.say_dialogue(message)` | `core/dialogue/dialogue.rb` | `pbMessage` dialogue: cleans, stores the line for the repeat key, drops an identical line within 0.5 s, speaks queued. |

**Text coming from the GAME goes through `speak_clean`**: Essentials strings carry control codes the screen
reader would spell out. Text the mod builds itself, via i18n, is already clean and goes through `speak`.

`PokeAccess.clean` (`core/speech/text.rb`) substitutes `\PN` with the player name and `\V[n]` with the game
variable, turns `\N` and `|` into spaces, and strips `\C[n]`, every other `\X` and `\X[..]`, `<...>` tags
and the `\x00-\x1f` bytes. Those bytes matter: leave them in and a paused line no longer compares equal to
its unpaused twin, slips past `say_dialogue`'s dedup, and the dialogue is spoken twice.

### The `interrupt` argument

| Value | When |
|---|---|
| `true` | Cursor movement: the player just moved and wants the new entry now. |
| `false` | Lines that must not cut each other: dialogue, consecutive battle messages, or the opening read of a screen that opens over a title still playing. |

## i18n

No new spoken text is hardcoded in `core/`. Every string is `I18n.t(:key)`
(`core/foundation/i18n.rb`), with the text per language in `lang/<code>.txt`: one key per line, `key=text`,
blank lines and `#` lines ignored. Interpolation uses `%{name}`.

```
# lang/en.txt
bt_state=%{name}, level %{level}, %{hp}
```

```ruby
# core/battle/battle.rb
t = PokeAccess::I18n.t(:bt_state, :name => b.name, :level => b.level, :hp => hp)
```

`t` looks the key up in the active language (`Config.language`), falls back to the reference language
(`:en`) and then to **the key name itself**: a gap is audible but never crashes. A missing variable
interpolates to an empty string.

**A new key goes into `lang/es.txt` AND `lang/en.txt`.** Two static checks enforce it:

| Test | What it requires |
|---|---|
| `test/static/i18n_parity_spec.rb` | `I18n.parity_issues` empty: no key present in one language and missing in another, none duplicated within a file, same `%{var}` set in both. |
| `test/static/i18n_refs_spec.rb` | That every key the code references exists in `lang/en.txt`. It scans `I18n.t(:k)` and the short `t(:k)` form across `core/`, `games/` and `plugins/`. |

`__meta__` keys (the `__` prefix) are excluded from parity. A dynamically built family (`:"chr_#{kind}"`)
cannot be scanned: its prefix is declared in `dynamic_prefixes`, inside `i18n_refs_spec.rb`.
`loader/boot.rb` runs the parity check at boot and logs it as a warning. Monolingual `games/` profiles may
use literals; see [05-extending](05-extending.md).

## Dedup with `Cursor`

Nearly every screen re-asserts its selection each frame: without dedup, the reader repeats the same entry
continuously. `PokeAccess::Cursor` (`core/menus/cursor.rb`) compares the current key against the previous
one and only lets the line through when it changes.

| Method | What it does |
|---|---|
| `changed?(holder, slot, key)` | `true` (and records `key`) when it differs from the previous one. A `nil` key never counts as a change. |
| `on_change(holder, slot, key) { }` | Runs the block only on a change; returns its value, else `nil`. The block builds the line lazily. |
| `announce(holder, slot, key, interrupt = true, first_interrupt = nil) { }` | `on_change` + `clean` + `speak`. No-op when the line comes out blank. |
| `reset(holder, slot)` | Forgets the key, so reopening the screen re-reads it even if the selection did not change. |
| `pending?(holder, slot)` | `true` while the slot holds no key: the FIRST read of a fresh or reset cursor. |

`first_interrupt`, `announce`'s fifth argument, is the `interrupt` that first read uses while the slot is
`pending?`. It queues the opening read without giving up interrupting on every later move; at `nil` (the
default) every read uses `interrupt`.

```ruby
# core/menus/menus.rb -- command-window focus: the opening read queues, each move interrupts
PokeAccess::Cursor.announce(win, :cmd_focus, [idx, pkt], true, false) { PokeAccess::Menus.focused_text(win) }
```

Dedup state lives **on the instance**: a composed ivar (`@access_cur_<slot>`) on the `holder`, the scene or
its visuals. It dies with the holder, so the screen reads again when reopened in the same state; module-wide
state would leave it mute. The `slot` keeps two readers sharing one scene apart. The key can be an index, a
string or a tuple (`[page, index]`); keying on the TEXT covers the screen that changes what it shows without
moving the index. A `nil` holder falls back to a module-wide table, only for readers with no instance to
hang on.

## The Data API

Data is fragmented across eras. Gen-6 keeps it in `PB*` tables indexed by integer (`PBMoveData`, `PBItems`,
`PBSpecies`); the GameData era (v19+) in registries indexed by symbol (`GameData::Move`, `GameData::Item`).
A shared reader cannot branch on the engine, so `PokeAccess::Data` (`core/data/data.rb`) resolves an id to
a name or field without the caller knowing who answers.

### Providers

A provider is a **module** with class methods, one per query, registered with a priority; the
highest-priority one present serves, memoized until the next `register`. Resolvers stay raw, with no
`rescue`: `Data.resolve` wraps every call.

| Priority | Provider | File | Registered when |
|---|---|---|---|
| 20 | `DataV21` | `core/data/v21/data_v21.rb` | `GameData` and `GameData::Move` are defined |
| 10 | `DataG6` | `core/data/gen6/data_g6.rb` | `PBMoves` is defined and `GameData` is NOT |
| 0 | `DataFallback` | `core/data/data_fallback.rb` | always, unconditionally |

The priority-0 one guarantees there is never zero providers: it returns the raw id as a string and leaves
the rich fields `nil`. Saying "PIKACHU" beats saying nothing. `loader/boot.rb` warns when that is the
active provider (`active_priority` <= 0), so an unrecognised engine is never a silent dead state.

### Methods

| Method | Returns | gen-6 | GameData era |
|---|---|---|---|
| `move_name(id)` | "Tackle" | `PBMoves.getName` | `Move#name` |
| `move_type_name(id)` | "Normal" | `PBTypes.getName(PBMoveData#type)` | `Type.get(Move#type).name` |
| `move_power(id)` | 40 | `PBMoveData#basedamage` | `attr_of(:power, :base_damage)` |
| `move_accuracy(id)` | 100 | `PBMoveData#accuracy` | `Move#accuracy` |
| `move_description(id)` | long text | `pbGetMessage(MoveDescriptions)` | `Move#description` |
| `type_name(id)` | "Fire" | `PBTypes.getName` | `Type#name` |
| `item_name(id)` | "Potion" | `PBItems.getName` | `Item#name` |
| `item_name_plural(id)` | "Potions" | `PBItems.getNamePlural` | `portion_name_plural`, else `portion_name`, else `name` |
| `item_description(id)` | text | `pbGetMessage(ItemDescriptions)` | `Item#description` |
| `item_id(sym)` | `[id, name]` | `PBItems.const_get(sym)`, else `getID` | the symbol IS the id |
| `species_name(id)` | "Pikachu" | `PBSpecies.getName` | `Species#name` |
| `species_entry(id)` | `[name, category, dex text]` | `pbGetMessage(Kinds` / `Entries)` | `category` / `pokedex_entry` |
| `ability_name(id)` | "Static" | `PBAbilities.getName` | `Ability#name` |
| `nature_name(id)` | "Timid" | `PBNatures.getName` | `Nature#name` |
| `stat_name(s)` | "Attack" | `PBStats.getName` | `Stat#name` |
| `status_name(st)` | see note | `Config.status_names[st]` | `Status#name` |
| `pokemon_types(pk)` | `["Fire", "Flying"]` | `type1` / `type2` | `pk.types` |

`status_name` is asymmetric: on the GameData era it returns the status text; on gen-6, the **i18n key** from
`Config.status_names` (`:st_burn`), which the caller passes through `I18n.t`; on the fallback, `nil`.
`pokemon_types` never returns `nil`: `[]` when nothing resolves.

`resolve` returns `nil` in two distinct cases: the datum does not exist (intended silence), or the provider
raised (likely a bug). The second is recorded once per `(method, error class)` in the marker and in
`Data.errors`, and still returns `nil`: the reader degrades instead of crashing. Write against a possible `nil`.

## Defensive introspection

The engine exposes accessors for almost nothing, and what it does expose changed names between eras. These
helpers live in `core/foundation/const.rb` and swallow any exception.

| Helper | Returns |
|---|---|
| `PokeAccess.ivar(obj, :@index, fallback = nil)` | The ivar, or `fallback` when unset or the read raises. |
| `PokeAccess.ivar_i(obj, :@index, fallback = 0)` | The same, coerced to Integer. |
| `PokeAccess.sprite(scene, "commands")` | The window at `@sprites["commands"]`, or `nil` when the hash or key is absent. |
| `PokeAccess.attr_of(obj, :totalpp, :total_pp)` | The first of those accessors to answer with something non-nil, or `nil`. |

`attr_of` exists because Essentials renamed accessors between eras -- `totalpp` to `total_pp`,
`base_damage` to `power` -- and each fangame kept the spelling it forked from. Asking for a single name does
not raise, since these reads are already guarded: it just answers `nil`, and a move with no pp or zero power
reads as missing data rather than as a bug. Names are tried in order, commonest spelling first.

```ruby
# core/data/v21/data_v21.rb -- the v18 GameData hybrids kept base_damage
def self.move_power(id); PokeAccess.attr_of(GameData::Move.get(id), :power, :base_damage); end
```

The remaining helpers in that file (`const_at`, `dedicate`, `dedicated?`) are in [08-reference](08-reference.md).

## Split: the text into core, the hook apart

The line builder goes into core as a pure function of the scene state; the hook -- which class, which
method, when -- goes separately, in the layer that owns the screen. Two screens with the same shape share
the first without sharing the second. `PokeAccess::MoveList` (`core/menus/move_list.rb`) reads a hand-drawn
move list, and `detail` speaks the full line via `MoveInfo.line`, from two different layers:

```ruby
# core/menus/v21/move_relearner_v21.rb -- vanilla v21 Move Relearner
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerV21::SCENE, :pbDrawMoveList) do |s, _r, _a|
  PokeAccess::MoveList.detail(s)
end
# plugins/sv_summary_screen.rb -- egg-move tutor, from a third-party plugin
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbDrawMoveList, :optional => true) do |s, _r, _a|
  PokeAccess::MoveList.detail(s)
end
```

The module is named after **what it reads**, not after the screen that needed it first. While it was called
`SkyEggMove` and sat in the fork's folder, a core reader using it crossed versions and the coupling check
had to carry a whitelist entry, the only one in the mod. Renaming it removed the exception instead of
documenting it: `test/static/coupling_spec.rb` now has an empty whitelist.
