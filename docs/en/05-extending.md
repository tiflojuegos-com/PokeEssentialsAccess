# Extending

Recipes for adding things to the mod. Every one of them ends in `ruby test/run_all.rb`; the last section
says which check fails and why.

## Does this belong in `core/`, `plugins/` or `games/`?

The question is who owns the class you are about to hook.

| The class… | Is | Layer |
|---|---|---|
| exists in some upstream Essentials tag | vanilla | `core/` |
| comes with a plugin several fangames install | third-party | `plugins/` |
| exists in one game only | the game's own | `games/<profile>/` |

```bash
# F:\claude\pokemon esentials\pokemon-essentials -- the upstream checkout, carrying the v19...v21.1 tags
git grep -l "class PokemonBag_Scene" v19 v19.1 v20 v20.1 v21 v21.1   # output = vanilla
git grep -l "class Window_Berrydex" v19 v19.1 v20 v20.1 v21 v21.1    # no output = not vanilla
```

If it is not vanilla, look at where it comes from in the game's own scripts. `tools/dump_scripts.rb`
extracts them to readable `.rb` files:

```bash
ruby tools/dump_scripts.rb "C:\path\to\the game"
```

It writes `Scripts_dump/` inside the game folder (or wherever a second argument says). It reads
`Data/Scripts.rxdata`, the loose script tree when the game keeps only a loader in there, and
`Data/PluginScripts.rxdata`; if the game ships packed in `Game.rgssad` it opens that too. No gems needed.

With the dump in front of you:

| Source folder | What it is |
|---|---|
| `_PluginScripts/`, or a numbered addons folder | third-party plugin |
| Anything else | the game's own code, or a plugin pasted in by hand |

Only a few games keep plugins in a folder of their own; the rest paste the plugin's code into the script
list, so there the path tells you nothing. Those games have no `PluginManager` either, which is why
`Plugins.game_plugins` answers `nil` rather than an empty list.

Two traps:

1. **A plugin that REOPENS a vanilla class looks like it defines it.** Deluxe Battle Kit reopens `Battle`
   and Modular UI Scenes reopens `PokemonPokedexInfo_Scene`: the class exists in every game, so a
   class probe always answers yes. Those are detected by method: `"Battle#pbToggleSpecialActions"`.
2. **The Sky fork puts things that look like plugins inside its engine.** Games built on it carry MUI and
   DBK inside the engine's own script tree, not in a plugins folder. What belongs to the FORK, rather than
   to one game, goes in `core/<module>/skyflyer/`.

## 1. Adding a game profile

1. Create `games/<key>/` with at least `manifest.rb` and `constants.rb`.
2. Write the manifest: an ordered list, no `.rb`, order = load order.

```ruby
# games/africanus/manifest.rb
{
  :modules => %w[
    constants
    pausemenu
    minigames
  ],
  :plugins => %w[easy_questing logros]
}
```

3. Declare the profile in `constants.rb`.

```ruby
# games/armonia/constants.rb
PokeAccess::Game.define("armonia") do
  button_labels :x => "DexNav"
end
```

4. Register it in `games/catalog.json`, the single source for the installer and the launcher.

| Field | What it is |
|---|---|
| `key` | the folder under `games/` |
| `display` | the spoken name |
| `titles` | exact titles from `mkxp.json` or `Game.ini`; every `"pokemon x"` needs its `"pokémon x"` twin |
| `detect` | case-insensitive regex over "folder + exe", or `null` |
| `exes` | a distinctive exe name; a generic `Game.exe` identifies nothing |
| `engine` | `"gen6"`, `"gamedata"` or `"any"` |

Detection is layered: `titles`, then `detect`, then `exes`, and if nothing matches the player is asked. The
LONGEST match wins, not the first. **`generic` must stay LAST**: it is the wildcard (empty `titles`,
`detect` set to `null`) and the order is kept for older launchers, which resolve by first match.

5. Prefix module names with the game's own (`ZBattleBag`, `AnilMenus`) where they could collide with core:
   unprefixed, `coupling_spec` reads them as a core reopen.
6. Add the profile's i18n keys, prefixed, to both `lang/` files (§5). A profile for a monolingual fangame
   may hardcode literals; see invariant 4 in [01-overview](01-overview.md).
7. If the engine is gen-6, the whole profile must pass `check187.py`. Modern ones are in its `MODERN` list.

What does NOT happen by itself: the behaviour suite loads ONE profile per engine (`pokemon_z` for gen-6,
`anil` for gamedata). A new one is scanned by `manifest_check.rb`, `coupling_spec` and `check187.py`, but no
test LOADS it.

## 2. Adding a reader to a profile

1. One file per screen in `games/<profile>/<screen>.rb`, holding its `Game.define`.
2. Hook the class by its name as a string: if it does not exist, the hook is never registered. That is how a
   profile can declare readers for classes only one version of the game ships.
3. Add the name, without `.rb`, to `:modules` in `manifest.rb`.

```ruby
# games/relict/difficulty.rb
PokeAccess::Game.define("relict") do
  after("PickDifficulty", :update) do |scr, _ret, _args|
    diffs = PokeAccess.ivar(scr, :@difficulties)
    idx   = PokeAccess.ivar(scr, :@index)
    # ...
  end
end
```

Where core already packages the pattern, the file is one line:

```ruby
# games/africanus/pausemenu.rb
PokeAccess::SpriteButtonMenu.define("africanus")
```

The full DSL is in [03-hooks](03-hooks.md); building the text and deduping it, in
[04-readers](04-readers.md). **A profile never reopens a core module**: the declared route is `override`,
which the diagnostic also lists, and `coupling_spec` rejects the reopen.

## 3. Adding a third-party plugin reader

Before writing a line, compare BOTH copies of the plugin in the dumps: the same class name does not
guarantee the same code. In order: the arity of the methods you hook, the name and SHAPE of the data in the
ivars you read, whether the support methods exist (via `respond_to?`, never `rescue true`), and whether the
hooked method is a modal `loop do` (there you need `SceneWatcher`). The header records where they diverge.

**The split: the text builder goes in core, the hooks go in the plugin.** WHAT to say usually serves more
than one game; WHEN to say it is the plugin's.

```ruby
# plugins/encounter_list_ui.rb -- triggers only; the text comes from PokeAccess::EncounterList, in core.
PokeAccess::Hooks.before_hook("EncounterList_Scene", :pbStartScene, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :encounter_list) }
PokeAccess::Hooks.after_hook("EncounterList_Scene", :drawPresent, :optional => true) { |s, _r, _a| PokeAccess::EncounterList.read_present(s) }
```

1. `plugins/<name>.rb`. **The name is the PLUGIN's, not the screen's** (`encounter_list_ui`, not
   `encounter_screen`). Every hook `:optional`.
2. One line in `plugins/manifest.rb`: `:<name> => "GiveawayClass"`. If the plugin brings no class of its own
   and reopens an engine one, the form is `"Class#method"`; the probe goes through `Engine.has?`, which
   takes both.
3. `:plugins => %w[... <name>]` in every profile whose game ships it. Not one more, not one less: the
   census checks both directions.
4. Regenerate the census: `ruby test/static/build_fangame_census.rb`. It reads the dumps (which live
   outside the repo) and rewrites `test/static/fangame_classes.txt` and `test/static/plugin_census.txt`.
5. A spec pinning **the divergence**, not the obvious part: if both shapes are not in the test, the reader
   goes green the day somebody simplifies the one that is not covered.

`generic` declares nothing: it uses `:plugins => :auto` and asks the running game through that same table.

## 4. Adding a config-menu option

1. One row in `Config::SCHEMA`: `[key, default, kind, group, lbl_label, help_help]`.
2. Its `lbl_` and `help_` keys in `lang/es.txt` and `lang/en.txt`.

```ruby
# core/foundation/config.rb
[:proximity_radar,    false, :flag,  :audio,         :lbl_proximity_radar, :help_proximity_radar],
[:audio3d_wall_range, 3,     :tiles, :audio3d_walls, :lbl_wall_range,      :help_wall_range],
```

That alone puts it in its group, persists it to `settings.ini` and brings it back on "restore defaults":
both `Settings` and `ConfigMenu` derive from the SCHEMA. Three cases need more:

| Case | What else is needed |
|---|---|
| A new numeric kind | a `KIND_BOUNDS` row of `[min, max, step, unit]`; `Settings::NUMERIC` derives from it |
| A new symbol kind | add it to `Settings::SYMS` and give it a reading and a cycling in `core/menus/config_menu.rb` |
| A new group | a `Config::CATEGORIES` row if it is a root one, or an `:enter` pushed by hand in `config_menu.rb` |

Do not reuse a kind because the unit looks alike: `:sonar` (1-30) exists apart from `:tiles` (1-20) so that
widening the sonar range does not widen the wall probe as a side effect.

## 5. Adding spoken text

1. The key in `lang/es.txt` AND in `lang/en.txt`, with the SAME `%{var}` placeholders.
2. Use it through `PokeAccess::I18n.t(:key)` or the short alias `t(:key)`.

```
# lang/es.txt
load_play=%{h} horas %{m} minutos de juego

# lang/en.txt
load_play=%{h} hours %{m} minutes played
```

Format is `key=text`, UTF-8, `#` comments. Key families built at runtime (`:"chr_#{kind}"`) cannot be
grepped: their prefix is declared in `dynamic_prefixes`, inside `test/static/i18n_refs_spec.rb`.
Transcriptions of text the game itself paints stay literal: they replicate the game, they are not the mod's
own sentences.

## Automated rules

`ruby test/run_all.rb`, then `powershell -File installer/install.ps1 -Force`. What fails and why:

| Check | Fails when |
|---|---|
| `manifest_check.rb` | a `.rb` in `core/` or in a profile is not in its manifest, an entry has no file, or one is listed twice |
| `manifest_check.rb` (catalog) | a `games/` folder has no `catalog.json` entry or the reverse; a `detect` is an invalid regex or does not even match its own `display`; two profiles claim a title or an exe; an `exes` says `Game.exe` |
| `catalog_detect_spec.rb` | the `pokemon_z` `detect` swallows a `Z:` drive letter or `mkxp-z.exe` again; a `"pokemon x"` title lacks its accented twin |
| `coupling_spec.rb` | a cross reference between core versions, between profiles, from `shared` into a version, into or out of `plugins/`; or a profile reopening a core module |
| `coupling_spec.rb` (census) | a `core/` file names, as a string, a class only ONE fangame has |
| `plugins_spec.rb` | a `plugins/` file is not in the table or the reverse; a hook is not `:optional`; two readers claim the same `Class#method`; two entries share a probe; a profile declares a plugin its game does not ship or fails to declare one it does; the probe is missing from the census |
| `plugins_smoke_spec.rb` | a `plugins/` reader hooks a class or a method that is no longer named that |
| `i18n_parity_spec.rb` | a key is in one language and not the other, is duplicated, or its `%{}` placeholders differ |
| `i18n_refs_spec.rb` | the code references a key absent from `lang/en.txt`, the SCHEMA's `lbl_`/`help_` included |
| `check187.py` | modern syntax in `core/`, `plugins/`, `loader/` or a gen-6 profile |
| `mts_mutator_guard_spec.rb` | there is a `CONST + array` or `x - array` in code that loads under Pokémon Z, whose engine redefines `Array#+` and `Array#-` as in-place mutators |
| `twins_spec.rb` | two twins declared in `test/static/twins.rb` have stopped being identical |
