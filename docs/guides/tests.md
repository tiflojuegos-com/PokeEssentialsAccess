# Run and write tests

This guide runs the [suite](../reference/glossary.md) whole, one engine pass or part of it, replays a failing order,
adds a test in the house style and regenerates the censuses. The checks under `test/static/` are listed in the
[static checks reference](../reference/static-checks.md).

## Starting point

- A desktop Ruby with the `minitest` and `prism` libraries. The suite runs on it, with stubs standing in for the
  engine; it does not run on Ruby 1.8.7.
- `python` on the path, for the Ruby 1.8.7 sweep.
- Optionally, a Ruby 1.8.7 interpreter at `../tools/ruby-1.8.7-*/bin/ruby.exe` or in `RUBY187`, for the real 1.8.7
  parse ([Engine eras](../architecture/engine-eras.md#the-checkers)).

Run the commands from the repository root.

## The whole suite

1. Run `ruby test/run_all.rb`.
2. Read the last line, such as `gen6: ok  gamedata: ok  (seed 4242)`. The command exits non-zero when either pass
   fails.

The suite runs in two passes, each in a Ruby process of its own:

- The gen-6 pass runs every `*_test.rb` under `test/unit/`, `test/behavior/` and `test/static/` whose name does not
  end in `_gd_test.rb`, under the gen-6 stubs.
- The GameData pass runs the `*_gd_test.rb` files under the GameData stubs.

A pass that cannot load the mod prints `the mod failed to load` with the first errors and runs nothing. After its
tests, a pass also fails on the [runner checks](../reference/static-checks.md#runner-checks) of `test/run.rb`.

## One engine pass

1. Set `PA_ENGINE` to `gen6` or `gamedata`: `PA_ENGINE=gamedata` before the command in a POSIX shell, or
   `$env:PA_ENGINE = "gamedata"` in PowerShell.
2. Run `ruby test/run.rb`. Without `PA_ENGINE`, it runs the gen-6 pass.

## Part of the suite

1. Pass a path fragment: `ruby test/run_all.rb behavior/battle` runs, in each pass, that pass's test files whose path
   contains it.
2. To run several areas, separate the fragments with commas: `ruby test/run_all.rb behavior/battle,unit/routes`.
3. To run tests by name, add a minitest option after the fragment:
   `ruby test/run_all.rb behavior/field/turbo -n /first_frame/`. A test's name is `test_` and its description, with
   underscores for the spaces. `-v` lists each test as it runs.

A fragment that matches no test file fails the pass with `no test file matches`. The static checks run only when the
fragment matches their path, as `static` does.

## Replaying an order

Minitest runs the tests in an order drawn from a seed. `test/run_all.rb` draws one, or takes `SEED`, and gives the same
seed to both passes.

1. Read the seed on the last line of the failing run.
2. Run `ruby test/run_all.rb --seed 4242`, with the same fragment if the run had one.
3. For one pass, run `ruby test/run.rb --seed 4242` with `PA_ENGINE` set.

## What each pass loads

Each pass loads core, every [plugin reader](../reference/glossary.md) and one
[harness profile](../reference/glossary.md), as the boot loads them ([Loading](../architecture/loading.md)):

- The gen-6 pass loads `pokemon_z`, with the shared profile it imports, `lostie_common`.
- The GameData pass loads `anil`, with `skyflyer_common`.

A rule or override that either profile installs applies to every test of its pass. Every plugin reader is loaded,
declared by the profile or not, since plugin hooks are optional. Before each test, `Reset.before_test` puts the
settings back to their defaults, clears the mod's state and pins the language to Spanish (`:es`). Each process writes
its runtime files to a temporary folder of its own, `POKEACCESS_DATA_DIR`, and removes it at exit.

## Writing a test

1. Choose the folder. `test/unit/<area>/` holds tests of a module's logic, such as
   `test/unit/routes/planner_test.rb`; `test/behavior/<area>/` holds tests of readers, such as
   `test/behavior/battle/announce_hp_test.rb`.
2. Name the file `<subject>_test.rb` for the gen-6 pass or `<subject>_gd_test.rb` for the GameData pass. For cases both
   passes run, write a `<subject>_cases.rb` module whose `define(base)` declares the tests on the class it gets, and
   two short test files that call it, as `test/behavior/field/turbo_cases.rb` does.
3. Open the file with a header comment: the screen or module under test and what the mod says there.
4. Declare the class as `<Subject>Test < PokeAccessTest` and each test as `test "what it does" do ... end`. Two tests
   of one class may not share a description. A test that asserts nothing fails.
5. Drive the code the way the game does: call the reader or the hooked method on stand-ins from `test/support/`, such
   as `World.stub_scene(ivars)` for a scene, `TestPoke` for a Pokémon and `TestCmd` for an event command.
6. For a profile's reader, define the classes it hooks at the top of the file, then evaluate the profile's file once
   with `eval(Harness.source(path), TOPLEVEL_BINDING, path)` and restore what it replaces, as
   `test/behavior/battle/rejuvenation_inspect_test.rb` does. A hook binds once per class name: a class created again
   under the same name stays unhooked, and a file evaluated twice adds its hook bodies twice. Load a shared profile
   with `Harness.load_common(name)`.
7. Assert what the mod says. `assert_spoken(pattern)`, `assert_spoken_once`, `refute_spoken` and
   `assert_nothing_spoken` match the lines spoken since the last `SpeakCapture.clear`. `SpeakCapture.log` gives
   `[text, interrupt]` pairs, where `false` means queued. Write the expected text in Spanish.
8. Run `ruby test/static/build_census.rb` to add the file to `test/static/test_census.txt`; the builder needs the
   script dumps ([Regenerating the censuses](#regenerating-the-censuses)). Until then, the gen-6 pass stops and names
   the file.
9. Run the test: `ruby test/run_all.rb <fragment>`.
10. Undo the change the test covers and run the test again; it must fail. `ruby tools/mutate.rb <file> <fragment>`
    lists the small changes to a file that the chosen tests still pass on.

```ruby
# test/behavior/field/fl_wall_clock_test.rb
class FlWallClockTest < PokeAccessTest
  test "the time is said once, queued, and the info key follows the later updates" do
    scene = World.stub_scene({})
    PokeAccess::WallClock.updated(scene, Time.local(2026, 10, 4, 9, 5))
    PokeAccess::WallClock.updated(scene, Time.local(2026, 10, 4, 9, 6))
    assert_equal [["09:05", false]], SpeakCapture.log
    assert_equal "09:06", PokeAccess::Info.info_text
  end

  test "an update without a time says nothing" do
    PokeAccess::WallClock.updated(World.stub_scene({}), nil)
    assert_nothing_spoken
  end
end
```

Other helpers of the test case:

- `vb_levels { ... }` gives the block's result at the brief, medium and full [verbosity](../reference/glossary.md)
  levels.
- `with_intl(map) { ... }` makes the game's `_INTL` answer the given translations, as a build in another language does.
- `list_place(i, n)` gives a row's place as the positions reading says it.
- `Reset.with_capability(name, value) { ... }` makes a capability answer `value` for the block.
- `GameFunctions.with(map) { ... }` defines a game's top-level functions, such as `getMoveName`, for the block.
- `Harness.with_provider(provider, priority) { ... }` puts a data provider in place for the block.

## Regenerating the censuses

The builders read the [script dumps](../reference/glossary.md) of the surveyed games, which live outside the
repository ([Census sources](../reference/static-checks.md#census-sources)).

1. Check that the script dumps are at `../../decompiled Scripts`. To add a game, run
   `ruby tools/dump_scripts.rb "<game folder>" "../../decompiled Scripts/<profile>"`.
2. Run `ruby test/static/build_census.rb`, or pass the folder of script dumps as its argument.
3. Check that the last line is `every census regenerated`.
4. Review the changes with `git diff test/static`.
5. If you added a source, raise `SOURCES` in `test/static/hooked_classes_test.rb` and `test/static/era_calls_test.rb`.
6. Run `ruby test/run_all.rb static`.

## Other runs

- With `PA_SWALLOWED` set, a pass also lists the failures the mod's rescues swallowed.
- `ruby tools/coverage.rb [fragment]` measures the mod's line and branch coverage over both passes.
- `ruby tools/game_overrides.rb <scripts folder> --run [fragment]` runs the suite with a game's redefinitions of Ruby's
  own methods applied to the mod's calls ([Engine eras](../architecture/engine-eras.md#core-methods-games-redefine)).
