# Add a profile

This guide adds a [profile](../reference/glossary.md) for a fangame the mod has none for. It starts from the
game's folder and ends with a profile the launcher detects, that loads in both passes of the
[suite](../reference/glossary.md) and whose static checks pass. Every declaration a profile can make is in the
[profile DSL reference](../reference/profile-dsl.md); where each reader of the game belongs is decided in
[Choose where a reader goes](choose-where-a-reader-goes.md).

## Starting point

- Without a profile, the launcher installs the [generic profile](../reference/glossary.md): core's readers and every
  [plugin reader](../reference/glossary.md) whose [probe](../reference/glossary.md) the game has, with obstacles said
  without what clears them.
- Choose the profile's name in lowercase, as the other folders of `games/`. It becomes the folder `games/<name>/` and
  the catalog key. A name ending in `_common` belongs to a [shared profile](../reference/glossary.md).
- `tools/onboard.rb` runs on the system Ruby and needs the `prism` gem. Run every command from the repository root.

## Steps

1. Write the game's [script dump](../reference/glossary.md) under the profile's name:
   `ruby tools/dump_scripts.rb "<game folder>" "../../decompiled Scripts/<name>"`. The census builders read the
   script dumps from `../../decompiled Scripts`. If the script dump keeps another name, add it to
   `ReaderSites::PROFILE_OF` in `test/static/reader_sites.rb`, which maps a script dump's folder to its profile.
2. Run the onboarding report:
   `ruby tools/onboard.rb "<game folder>" --scripts "../../decompiled Scripts/<name>" --profile <name>`. Add
   `--out <file>` to keep it in a file. With `--profile` and no `games/<name>/` yet, the tool writes
   `games/<name>/manifest.rb` and `games/<name>/constants.rb`, and the report ends with the catalog entry to add. The
   report gives:
   - the engine facts and the [engine era](../reference/glossary.md) the mod treats the game as
     ([Engine eras](../architecture/engine-eras.md));
   - the plugin readers whose probe the game's scripts define, and the plugins in the script dump's `_PluginScripts/`;
   - the Ruby core methods the game redefines;
   - the screens no reader hooks, and those read only through a hooked ancestor;
   - the classes and functions that run their own input loop and that no file the game loads names, whatever their
     name, each marked when it was already checked (`tools/silent_screens.rb`);
   - each passability method the game defines, with the state it reads beyond the map.
3. Add the catalog entry to `games/catalog.json`, in alphabetical order by key, and fill in what identifies the game.
   Every profile but the generic one needs at least one of `titles`, `detect` and `exes`.

   | Field | Holds |
   |---|---|
   | `key` | the profile's folder name |
   | `display` | the game's name as the launcher says it |
   | `titles` | lowercase titles matched against the game's own title |
   | `detect` | a case-insensitive regular expression over the folder and exe names |
   | `exes` | names of the game's own executables, compared without case; `Game.exe` identifies nothing |
   | `engine` | `gen6` or `gamedata`; the generic profile's is `any` |
   | `compat`, `convert`, `markers` | optional, for a game the launcher prepares or converts |

   The launcher tries `titles`, then `detect`, then `exes`
   ([Profile selection](../architecture/loading.md#profile-selection)).

4. Keep `constants` the first entry of `:modules`. The first `Game.define` in the profile's load order names the
   profile, and `test/static/profile_names_test.rb` requires that name to be the folder's. The name stamps the
   player's tag, mark and map-name files, and an import stamped with another name is refused.
5. Declare the game-wide rules in `games/<name>/constants.rb`, each checked against the game's scripts, with a
   comment naming the script it rests on. The usual ones are the letters its key hints paint (`key_hints`), what its
   Surf asks of company (`surf_company`), the items that stand in for a field move (`field_move_item`,
   `field_move_tool`) and its own status and weather ids (`names`).

   ```ruby
   # games/opalo/constants.rb
   PokeAccess::Game.define("opalo") do
     # Key hints for the letters Opalo's Input maps to one button each: R and Y are anthem keys, A is bound to two.
     key_hints "Z" => :a, "X" => :b, "C" => :c, "D" => :z

     # Its Kernel.pbSurf (189_Following.rb) refuses while anyone walks along as a dependent event, unless the following
     # Pokemon's switch is on.
     surf_company(:dependents) { $game_switches[Following_Activated_Switch] }
   end
   ```

   To change what a core reader does in this game, use `override`. `test/static/coupling_test.rb` fails a profile
   that reopens a core module other than `PokeAccess::Config`.
6. Fill `:plugins` with the readers of `plugins/` whose plugin the game ships unedited; the report's two plugin lines
   are the starting list. A plugin with no reader yet gets one ([Add a plugin reader](add-a-plugin-reader.md)). An
   old or edited copy stays out of the list, and the profile reads it
   ([Choose where a reader goes](choose-where-a-reader-goes.md)). A game of a family that has a shared profile
   imports it with `:imports => %w[<family>_common]`.
7. Declare the passability. Follow `Game_Player#passable?` down through every method it calls, the aliases plugins add
   included; the report lists their definitions. A follower script that stops only other events reads nothing for the
   player. When the player's passability reads nothing an event sets besides the map's tiles, tileset and events, the
   bridge, surf and bike state and the player's place, add `games/<name>/passability.rb` with `plain_passability`
   and list it in `:modules`. Register each other state it reads with `PokeAccess::World::Probe.mode_reader`, in the
   same file and before the declaration. A declaration that misses a read keeps answers that an event's end has made
   wrong.

   ```ruby
   # games/africanus/passability.rb
   # Africanvs' player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
   # player's place, nothing else an event sets (checked against its scripts; its follower script only stops other
   # events), so an event's end keeps the probe's answers.
   PokeAccess::Game.define("africanus") do
     plain_passability
   end
   ```

8. If the report lists Ruby core methods the game redefines, run the suite under them:
   `ruby tools/game_overrides.rb "../../decompiled Scripts/<name>" --run`. A failure is a call of the mod that the
   game's redefinition changes.
9. Write the readers for the screens the report lists ([Add a reader](add-a-reader.md)) and add each file to
   `:modules`.
10. Regenerate the [censuses](../reference/glossary.md) with `ruby test/static/build_census.rb`. Then set `SOURCES` in
    `test/static/hooked_classes_test.rb` and in `test/static/era_calls_test.rb` to the number of surveyed sources the
    regenerated census headers print.
11. Run `ruby test/run_all.rb` ([Tests](tests.md)). Among the static tests, `profile_load_test` loads every profile
    under both engines' stubs, `manifest_check_test` compares the manifest with the disk and the catalog with the
    profiles, and `plugins_test` compares `:plugins` with the plugin census
    ([Static checks](../reference/static-checks.md)).
12. Install the mod in the game from the repository with the launcher console, without `--profile`
    ([Install and release](install-and-release.md)).

## Result

- The launcher's `status` names the new profile for the game.
- In the game's folder, `accessibility/data/loader_error.txt` names no file under `accessibility/game/`, and its
  list of hooks without a method holds none of the profile's.
- The diagnostic dump (Ctrl+Alt+F9, written to `accessibility/data/diag.txt`) lists every declared reader after
  `plugins: cargados=` and none after `sin_declarar=` ([Diagnostics](../architecture/diagnostics.md)).
