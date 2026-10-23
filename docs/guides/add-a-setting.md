# Add a setting

This guide adds a setting to the configuration menu: a row on one of its screens, a key in `settings.ini`, a label
and a help text in every language, and the tests that cover them. The [settings reference](../reference/settings.md)
lists the existing settings, their kinds and the rules that show or hide a row.

## Starting point

The mod has a behavior that the player should be able to switch or tune. The result is a row that says its value and
its help, a line in `settings.ini` that keeps the value between sessions, and a suite that passes.

## Steps

1. Choose the screen. Each screen lists one group declared with `Config.group` in `core/foundation/config.rb`, such
   as `:general`, `:pathfinder` or `:pathfinder_adv`; the reference lists them all. A setting of a sound family (its
   switch, volume, frequency or pitch) belongs to the family instead: follow step 4 in place of step 3.

2. Choose the kind. Use `:flag` for a setting that is on or off. For a number, use a kind of `Config::KIND_BOUNDS`,
   and add an entry `[min, max, step, unit key]` only when no kind has the range. For a choice among names, use a kind
   of `Config::LISTS`, or add one with its values and the prefix of the keys that name them: the prefix `"tord_"`
   names the value `:near` with the key `tord_near`.

3. Declare the row with `define` in `core/foundation/config.rb`, among the lines of its group, where the row should
   stand. The order of the `define` lines is the order of the screen and of `settings.ini`.

   ```ruby
   # core/foundation/config.rb
   define(:route_limit, :effort, :rlimit, :pathfinder_adv, :lbl_route_limit, :help_route_limit)
   define(:astar_max,   2500,    :astar,  :pathfinder_adv, :lbl_astar,       :help_astar,
          :show_if => [:route_limit, :effort])
   ```

   The arguments are the key, the default, the kind, the group, the label key and the help key. The default must be
   a value the kind takes. `:show_if => [key, values]` shows the row only while another setting holds one of the
   values, and `:needs => :positional` only while the positional engine is up. `SONAR`, `NAV_ON`, `NAV_ENGINE` and
   `NAV_FULL` hold the conditions the audio rows share.

4. For a family setting, add the row to the family's declaration in `core/sound/catalog.rb`, as
   `[key, default, label, help]` under `:vol`, `:freq` or `:tone`, or as `[key, default, label]` under `:on`.
   `Sound::Catalog.rows` builds the rows, and the family's `:shown` gives their condition. A row of another kind that
   belongs after the family's frequency row goes in `:extra`, as `guide_rhythm` does in the guide's family.

5. Add the label and the help to every file in `lang/`, under the same keys in each
   ([Add spoken text](add-spoken-text.md)). The label is what the row says before its value; the help is what the
   info key says over the row. A help names the mod's keys with `%{key_<action>}`, such as `%{key_hist_prev}`, and
   the menu fills in the key the player has bound. A new list kind also needs a key for each value's name.

   ```text
   # lang/en.txt
   lbl_surface_cues=Surface cues
   help_surface_cues=Announces the terrain under you when it changes: grass, water, sand, ice.
   ```

6. Read the value where it acts, as `PokeAccess::Config.<key>`.

   ```ruby
   # core/nav/surfaces.rb
   def self.surfaces
     return unless PokeAccess::Config.surface_cues
   ```

   Change the value from code only through `Config.set(key, value)`, which emits `:config_changed`. Code that keeps
   state worked out from a setting drops that state on the event:

   ```ruby
   # core/nav/locator_naming.rb
   PokeAccess::Events.on(:config_changed) { |_key| PokeAccess::Locator.clear_verdicts }
   ```

7. Update the menu tests. `test/unit/menus/config_menu_test.rb` asserts the rows of each screen in order, as in the
   test "lists the pathfinder's settings, then its advanced screen, then back": add the key where it now stands. A
   family row also goes in the `ROWS` table of `test/unit/sound/catalog_test.rb`. For a row with `:show_if` or
   `:needs`, add a test that sets the other setting, or runs in `Reset.with_capability(:positional, value)`, and
   checks the rows, as the test "shows the counters' range only while walls hide what is behind them" does.

8. Test the effect with a behavior test that sets the value with `PokeAccess::Config.<key> = value` and checks what
   the mod says or plays. Every test starts with all settings at their defaults and the language set to Spanish
   (`Reset.before_test`), so a test sets only the values it needs ([Tests](tests.md)).

9. Run `ruby test/run_all.rb` from the repository root. Besides the new tests, the run checks that the label and help
   keys exist in `lang/en.txt` (`test/static/i18n_refs_test.rb`), that every language has them
   (`test/static/i18n_parity_test.rb`), and that every setting survives a write and a read of `settings.ini`
   (`test/behavior/foundation/settings_apply_test.rb`).

10. Add the setting to the table of its screen in the [settings reference](../reference/settings.md).

## Result

1. Install the mod in a game ([Install and release](install-and-release.md)) and start it.
2. Open `settings.ini` in the data folder. The new key stands at its place among the settings, with its default: the
   boot rewrites the file whenever it differs from the settings.
3. Open the menu on the map and go to the row's screen. The row says its label and its value, left and right step
   the value, and the info key says the help.
4. Close the menu, which writes the file, and open `settings.ini` again. The line holds the value chosen.

## Changing an existing setting

- A new default reaches only the players whose `settings.ini` does not hold the key yet, since the file holds every
  setting once written.
- A renamed key starts at its default for every player: the boot drops the old line when it rewrites the file. The
  file needs no migration.
- A removed setting takes its `define` line, its keys in every `lang/` file, its readers and its rows in the menu
  tests with it, in the same change.
- A profile gives a setting another value in one game with `config(:key, value)` in its `Game.define` block
  ([Profile DSL](../reference/profile-dsl.md)). The boot applies `settings.ini` after the profile, so a value in the
  file wins.
