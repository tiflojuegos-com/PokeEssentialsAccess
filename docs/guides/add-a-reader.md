# Add a reader

This guide adds a reader to a screen the mod does not read yet, from the game's scripts to a test that passes in the
suite. Start once the game has a profile ([Add a profile](add-a-game-profile.md)) and the reader's place is
chosen ([Choose where a reader goes](choose-where-a-reader-goes.md)).

The example is the reader that says the dish on Royal's curry results, `games/royal/curry_result.rb`.

## Finding the screen's class

1. Open the screen in the game with the mod installed, and press Ctrl+Alt+F9. The mod appends a
   [diagnostic dump](../architecture/diagnostics.md) to `diag.txt` in the [data folder](../reference/glossary.md).
2. Read the lines that name the screen: `$scene=`, `live_cmd_windows=`, `live_selectables=`, `pictures=` and
   `painted=`. A screen that runs in its own loop does not become `$scene`, so its windows, pictures and painted
   strings name it instead. [Debug a silent screen](debug-a-silent-screen.md) describes each line.
3. Search the game's scripts for those names, such as
   `rg -n "class ResultadosCurry_Scene" "../../decompiled Scripts/royal"`. The
   [script dumps](../reference/glossary.md) live in `../../decompiled Scripts/<game>/`. For a game without one, run
   `ruby tools/dump_scripts.rb "<game folder>"`, which writes the scripts to `Scripts_dump/` in the game's folder.
4. To survey a whole game instead, run `ruby tools/onboard.rb "<game folder>"`. Its report lists the screens no reader
   hooks, each with the file that defines it. To survey every script dump at once, run `ruby tools/silent_screens.rb`:
   it lists the classes and functions that loop on the keys and pump `Graphics.update` with no file of the mod naming
   them, less those already checked. A screen checked and found to need no reader goes to
   `tools/silent_screens_triaged.txt` with the games and the reason; an entry the report says is no longer listed
   (a reader names that screen now) leaves the file.
5. Read the class before choosing a hook. Note the method that opens the screen, the loop that runs it, the methods
   the cursor goes through and the instance variables that hold what it paints.

In Royal, `ResultadosCurry#pbStartScreen` calls `pbStartScene`, `pbUpdate` and `pbEndScene` in turn
(`../../decompiled Scripts/royal/_PluginScripts/Curry/003_Resultado.rb`). `pbStartScene` builds the screen and
returns, `pbUpdate` loops until the player leaves, and the dish is `@tipo_de_curry`, an Array whose second field is
its name.

## Choosing the hook

| What the reader says | Hooked method | Registration |
|---|---|---|
| A text when the screen appears | an opener that returns before the loop | `read_on_open(cname, :pbStartScene)` |
| A text when the screen appears | an opener that runs the loop | `read_on_open` with `:timing => :before` |
| The entry under a moving cursor | a method each move or frame runs | `after` and `PokeAccess::Cursor.announce` |
| The entry under a moving cursor | `opts[:on]`, `update` by default | `focus_reader(cname, opts)` |
| The focused row of a command window | none: the window's class is named | `screen_reader(cname)` |
| A core reader's line, changed for this game | the core reader's method | `override(target, meth)` |
| What a top-level function shows | the function | `kernel(fname, timing)` |

- Do not put an `after` hook on the screen's loop or on a method that runs it. Its original runs under the
  [reentrancy guard](../reference/glossary.md), which skips every other hooked method until the loop returns, so the
  whole screen goes quiet ([Containers](../architecture/hooks.md#containers)).
- For what happens on closing, hook the closer, such as `pbEndScene`. When the hook has to sit on a method that runs a
  loop, register it with `:hook_container => true`.
- Give `:optional => true` only to a method that some of the reader's games lack for a real reason.

The registrations, their block parameters and their options are listed in the [Hooks API](../reference/hooks-api.md),
and the helpers readers call in [Reading APIs](../reference/reading-apis.md).

Royal's `pbStartScene` returns before `pbUpdate` loops, so its reader is a `read_on_open` with the default timing.

## Writing the reader

1. Create `games/<profile>/<name>.rb`, with the registration inside a `PokeAccess::Game.define("<profile>")` block.
2. Add `<name>` to the `:modules` list of `games/<profile>/manifest.rb`. The manifest check fails on a file the
   manifest does not list.
3. Read the screen's state with `PokeAccess.ivar(obj, :@name)`, which answers `nil` for an instance variable the
   object does not have. For an accessor whose name changed between versions, try each name with
   `PokeAccess.attr_of(obj, :totalpp, :total_pp)`.
4. Say the screen's own text as it is painted. Put the mod's own words in `lang/`
   ([Add spoken text](add-spoken-text.md)).
5. Declare every block parameter the registration passes, such as `|scene, _ret, _args|` for `after`. Under Ruby 1.8.7
   a block with one parameter receives every value as one Array.
6. Write Ruby 1.8.7 syntax in the code a 1.8.7 game loads; `test/static/ruby187_test.rb` rejects anything newer.

```ruby
# games/royal/curry_result.rb
PokeAccess::Game.define("royal") do
  read_on_open("ResultadosCurry_Scene") do |scr|
    curry = PokeAccess.ivar(scr, :@tipo_de_curry)
    (curry.is_a?(Array) && curry[1] && !curry[1].to_s.empty?) ? curry[1].to_s : nil
  end
end
```

A reader in `core/` calls the registrars of `PokeAccess::Hooks` directly, and its file is listed in `core/manifest.rb`.
A plugin reader has its probe in `plugins/manifest.rb`, and each profile whose game ships the plugin declares it
([Add a plugin reader](add-a-plugin-reader.md)).

## Testing the reader

1. Create the test file in `test/behavior/<area>/`. A file named `<name>_test.rb` runs in the gen-6 pass, and one
   named `<name>_gd_test.rb` in the GameData pass. Use the pass of the game's
   [engine era](../reference/glossary.md); a core reader that serves both eras needs a file in each pass.
2. At the top of the file, define stub classes with the game's class names, the hooked methods and the instance
   variables the reader reads. Then evaluate the reader's file once, with `Harness.source`. A hook binds once per
   class name and process, so a stub class created again inside a test is not hooked.
3. In each test, call the hooked method and assert on `SpeakCapture.log`, which holds `[text, interrupt]` pairs, or
   use `assert_spoken`. Keep one test that the hooked method still answers the game's value.

```ruby
# test/behavior/menus/royal_screens_gd_test.rb (shortened)
class ResultadosCurry_Scene
  def initialize(curry); @tipo_de_curry = curry; end
  def pbStartScene; :dish; end
end
%w[currydex curry_select creador tarjetas_liga curry_result].each do |name|
  path = File.join(Harness::ROOT, "games", "royal", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end
class RoyalScreensGdTest < PokeAccessTest
  test "says the dish by the name the results paint, queued" do
    ResultadosCurry_Scene.new([3, "Curri picante", "Un curri", "Picante", nil]).pbStartScene
    assert_equal [["Curri picante", false]], SpeakCapture.log
  end
end
```

## Running the suite

1. Regenerate the [censuses](../reference/glossary.md) with `ruby test/static/build_census.rb`. It reads the script
   dumps, from another folder when its first argument or `PA_DUMPS` names one. It also rewrites the list of test files
   that the gen-6 pass compares with the disk.
2. Run the new test with a fragment of its path, `ruby test/run_all.rb royal_screens`, then the whole suite with
   `ruby test/run_all.rb`. A filtered run leaves out the static checks.
3. Read any static check that fails. `hooked_classes_test` wants the class in a surveyed game, `ivars_test` the
   instance variables, `arity_test` the `args` positions and `blocking_hooks_test` no `after` hook on a loop
   ([Static checks](../reference/static-checks.md), [Tests](tests.md)).

## Checking in the game

1. Install the mod from the working tree into the game with the launcher console
   ([Install and release](install-and-release.md)).
2. Open the screen. The reader's line is said when the screen appears.
3. If the screen stays silent, follow [Debug a silent screen](debug-a-silent-screen.md).
