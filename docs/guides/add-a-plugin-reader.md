# Add a plugin reader

This guide adds a [plugin reader](../reference/glossary.md): a file in `plugins/` that reads the screens of a
community plugin. It covers the reader, its [probe](../reference/glossary.md) in `plugins/manifest.rb`, the profiles
that declare it and its entry in the plugin [census](../reference/glossary.md). Whether a screen belongs in `plugins/`
at all is decided in [Choose where a reader goes](choose-where-a-reader-goes.md).

## Starting point

- The plugin's code is at hand, in a game's [script dump](../reference/glossary.md) or in a
  [reference copy](../reference/glossary.md) of the plugin. A script dump puts the plugins of the game's
  `Data/PluginScripts.rxdata` under `_PluginScripts/`; other games paste plugins into their script list.
- No reader covers the plugin yet. Its classes appear in no file of `plugins/`, and `plugins/manifest.rb` has no
  entry for it.
- A plugin reader loads in two ways. A profile that lists it under `:plugins` loads it whatever the game has, and its
  optional hooks bind where the plugin's methods exist. The [generic profile](../reference/glossary.md) loads it when
  the game has its probe. The probe also feeds the census and the diagnostic dump's list of plugins that run without
  a reader.

## Steps

1. Choose the probe: the class, or the `"Class#method"`, whose presence gives the plugin away.
   - A class the plugin brings, as `"EncounterList_Scene"` for Encounter List UI.
   - A method, when the plugin only reopens a class every game has: the Deluxe Battle Kit adds `pbToggleSpecialActions`
     to `Battle`, so its probe is `"Battle#pbToggleSpecialActions"`.
   - A top-level function, as `"Object#autosaveAnim"`, when the plugin brings no class of its own.
   - A method that tells a release apart from an older or unrelated copy with the same class name, as
     `"Questlog#pbMain"` or `"Battle::Scene#pbGetFinalModifiers"`.

   Two entries never share a probe.
2. Write `plugins/<name>.rb`. Keep the reader's code in a module of its own under `PokeAccess`, and register each hook
   with `:optional => true`: a game without the plugin is the normal case, and it must not fill
   `Hooks.missing`, the list of likely mistakes ([Hooks](../architecture/hooks.md)).

   ```ruby
   # plugins/punch_bag.rb
   PokeAccess::Hooks.read_on_open("PunchBagScene", :pbStartScene, :optional => true) do |scene|
     PokeAccess::PunchBag.opened(scene)
   end
   PokeAccess::Hooks.around_hook("PunchBagScene", :pbMain, :optional => true) do |scene, nxt, _a|
     PokeAccess::PunchBag.playing(scene) { nxt.call }
   end
   PokeAccess::Hooks.after_hook("PunchBagScene", :computeScore, :optional => true) do |scene, _r, _a|
     PokeAccess::PunchBag.scored(scene)
   end
   PokeAccess::Frame.each_pulse { PokeAccess::PunchBag.poll }
   ```

   Put every spoken text in `lang/` ([Add spoken text](add-spoken-text.md)). Name no profile's module from the
   reader; `test/static/coupling_test.rb` fails a plugin that does, and any file outside `plugins/` that names a
   plugin's module.
3. Keep an override of a core method inert while the plugin is absent. The suite evaluates every file of `plugins/`
   in both passes, so such an override runs under every test. The override of `PokeAccess::FieldMoves.can?` in
   `plugins/hm_catalogue.rb` asks `defined?(::HM_Catalogue)` on each call, and answers the original's value without it.
4. Add the probe to the detection table, `plugins/manifest.rb`, keyed by the file's name without `.rb`:
   `:punch_bag => "PunchBagScene"`. Put a comment above a method probe that says why the class alone would not do.
5. Add the reader's name to `:plugins` in the manifest of each profile whose game ships the plugin unedited. A
   profile whose game ships an old or edited copy leaves it out and reads that copy itself. A shared profile's
   `:plugins` list joins that of every profile importing it.
6. Regenerate the plugin census from the script dumps: `ruby test/static/build_fangame_census.rb`, or
   `ruby test/static/build_census.rb` for every census. Each row of `test/static/plugin_census.txt` holds a probe's
   key and the profiles whose script dump defines it: a class probe by its last name segment, a method probe as
   `<last segment>#<method>`.
7. For a plugin no surveyed game ships, put a copy of it in one of the reference collections, `pokeliberty`,
   `FL-essentials` or `eeveeexpo`, under `../../../repositorios genericos/_refmods`. Then run
   `ruby test/static/build_reference_census.rb`. The static tests accept a reader no profile names when no script
   dump ships its probe and a reference copy defines it, and accept the classes and instance variables the copy
   defines. `plugins/fl_character_selection_v1.rb` is such a reader, for the generic profile alone.
8. Write the reader's test under `test/behavior/`, in a file ending in `_gd_test.rb` for a GameData-era plugin, and
   regenerate the censuses, which list the test files ([Tests](tests.md)).
9. Run `ruby test/run_all.rb`.

## Result

- `test/static/plugins_test.rb` passes. It matches the detection table with the files, requires `:optional` on every
  hook in `plugins/`, rejects two readers on one `Class#method`, and compares each profile's `:plugins` with the
  census in both directions. A profile whose game ships the plugin and does not declare it fails, and so does one
  that declares it with no script dump of its game defining the probe.
- `hooked_classes_test`, `ivars_test` and `arity_test` pass. Every class the reader hooks exists in a script dump or
  a reference copy, every instance variable it reads exists in a game it runs in, and every argument it reads is one
  each surveyed game passes ([Static checks](../reference/static-checks.md)).
- In a game that ships the plugin, the diagnostic dump lists the reader after `plugins: cargados=`
  ([Diagnostics](../architecture/diagnostics.md)).
