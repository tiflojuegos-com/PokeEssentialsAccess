# Glossary

This page defines the terms the documentation uses, one per concept, in alphabetical order. Each entry links to the
page that explains it.

- **assisted step**: what the player does where walking stops, such as Cut on a tree or a push on a boulder; a route
  on foot stops at its gate, and Surf takes a plan of its own
  ([World and routes](../architecture/world-and-routes.md#assisted-steps)).
- **bind**: a hook binds when its class and method exist in the game and its wrapper is installed over the method
  ([Hooks](../architecture/hooks.md#binding-by-class-name)).
- **binding**: a key that the remap screen gives a game button, an extra or a mod key, saved in `settings.ini`
  ([Keys](keys.md#what-a-binding-changes)).
- **build language**: the language of the running game build, `GameLang.code`, read from the game's `LANGUAGES`
  table ([Speech and languages](../architecture/speech-and-languages.md#game-text-in-several-builds)).
- **cane**: the guide that chimes toward the next press of the route to the selected target
  ([Guide and sound](../architecture/guide-and-sound.md#the-cane)).
- **capability**: a feature of the running engine that `Engine.has?` answers, by symbol, constant name or
  `"Class#method"` ([Engine eras](../architecture/engine-eras.md#capabilities)).
- **catalog**: `games/catalog.json`, the launcher's list of profiles with the titles, patterns and executables that
  identify each game ([Loading](../architecture/loading.md#profile-selection)).
- **census**: a generated file under `test/static/` that records facts about the surveyed sources; static tests
  compare the mod against it ([Static checks](static-checks.md#censuses)).
- **change detection**: the rule, kept by `PokeAccess::Cursor`, that a reader speaks only when the key of what has the
  focus changes ([Readers](../architecture/readers.md#change-detection)).
- **command-window reader**: the after-hook on `Window_DrawableCommand#update` that reads the focused option of every
  command window ([Readers](../architecture/readers.md#command-windows)).
- **container**: a hooked method whose original drives other hooked readers; it runs without the reentrancy guard
  ([Hooks](../architecture/hooks.md#containers)).
- **control code**: a code of the game's message system, such as `\PN` or `\C[n]`, that `PokeAccess.clean`
  substitutes or removes before a line is spoken
  ([Speech and languages](../architecture/speech-and-languages.md#game-text-and-control-codes)).
- **data folder**: `PokeAccess::Paths::DATA`, the folder of the player's settings and the mod's logs, which is
  `accessibility/data` when that folder can be written
  ([Diagnostics](../architecture/diagnostics.md#what-the-diagnostics-record)).
- **data provider**: a module that `PokeAccess::Data` asks for names and fields by id; the registered one with the
  highest priority serves ([Engine eras](../architecture/engine-eras.md#data-providers)).
- **detection table**: `plugins/manifest.rb`, which maps each plugin reader to its probe
  ([Loading](../architecture/loading.md#plugin-readers-and-probes)).
- **diagnostic dump**: the report of the mod's state that Ctrl+Alt+F9 appends to `diag.txt` in the data folder
  ([Diagnostics](../architecture/diagnostics.md#the-diagnostic-dump)).
- **earcon**: a sound that always plays through the flat channel, such as the radar's tick
  ([Guide and sound](../architecture/guide-and-sound.md#the-flat-channel)).
- **emitter**: a source the sonar pings, such as an event, a marker or a map's edge exit
  ([Guide and sound](../architecture/guide-and-sound.md#sonar)).
- **engine era**: a family of Essentials versions the mod treats alike: gen-6 (v16 and v17), GameData (v18 to v21.1)
  and GameData with the v22 interface; `Engine.kind` tells only gen-6 from GameData
  ([Engine eras](../architecture/engine-eras.md#eras)).
- **extra**: a raw key that a game reads, added to the remap screen by its profile with `remap_extra`
  ([Keys](keys.md#remap-screen)).
- **extractor**: a block registered for a window class with `Menus.def_extractor`, or `screen_reader` in a profile,
  that gives the text of the focused option ([Readers](../architecture/readers.md#command-windows)).
- **facet**: a meaning of a map event, such as `:touch` or `:gate`, computed from its record on first use and kept
  while the state it read holds ([World and routes](../architecture/world-and-routes.md#events-and-facets)).
- **flat channel**: `Sound::Flat`, which plays panned files through the game's sound effect channel, for the earcons
  and for the cues while the positional engine is down
  ([Guide and sound](../architecture/guide-and-sound.md#the-flat-channel)).
- **focus reader**: a reader declared with `FocusReader.define`, or `focus_reader` in a profile, for a screen whose
  cursor is an index on the scene ([Readers](../architecture/readers.md#command-windows)).
- **function wrapper**: the wrapper that `Hooks.wrap_global`, `Hooks.wrap_kernel` or `Hooks.wrap_singleton` installs
  over a top-level function or a module's singleton method
  ([Hooks](../architecture/hooks.md#functions-module-methods-and-overrides)).
- **game button**: a button of the game's input, such as `Input::C`, which the remap screen can bind to another key
  ([Keys](keys.md#remap-screen)).
- **gate**: the hash an assisted step carries, naming what stands in the way and how to get past it, such as `:field`
  or `:pull` ([World and routes](../architecture/world-and-routes.md#assisted-steps)).
- **generic profile**: `games/generic/`, the profile the launcher installs for a game without its own; it loads the
  plugin readers whose probe matches ([Loading](../architecture/loading.md#profile-selection)).
- **guarded call**: a call in shared core to a function only some games define, made only where the game has it
  ([Engine eras](../architecture/engine-eras.md#era-folders)).
- **harness profile**: the profile a pass of the suite loads, `pokemon_z` in the gen-6 pass and `anil` in the
  GameData pass ([Run and write tests](../guides/tests.md#what-each-pass-loads)).
- **hook**: code the mod runs before, after or around a game's method, installed by a registrar without editing the
  game's scripts ([Hooks](../architecture/hooks.md#what-a-hook-is)).
- **info key**: the key that says the details of what has the focus, T by default
  ([Readers](../architecture/readers.md#info-key)).
- **information window**: a standing window whose text changes while its scene runs, watched with `InfoWindow.watch`
  or `info_window` in a profile ([Readers](../architecture/readers.md#information-windows)).
- **ladder**: a call in shared core that tries one era's spelling of a function and falls back to the other's
  ([Engine eras](../architecture/engine-eras.md#era-folders)).
- **launch**: the last tile walked before the water on a surf plan, with its facing, from which the player pushes off
  ([World and routes](../architecture/world-and-routes.md#water-and-surfing)).
- **launcher**: the separate program, `pokeessentialsaccess-launcher.exe`, that installs, updates and removes the mod
  and chooses each game's profile ([Install and release](../guides/install-and-release.md)).
- **lend through**: to make events passable for the engine while a block runs, with `Probe.lend_through`
  ([World and routes](../architecture/world-and-routes.md#passability-probe)).
- **locator**: `PokeAccess::Locator`, which lists the targets of one locator category and keeps one of them selected
  ([Guide and sound](../architecture/guide-and-sound.md#targets-and-categories)).
- **locator category**: one of the lists the locator cycles, such as `:people`, `:exits` or `:surfaces`
  ([Guide and sound](../architecture/guide-and-sound.md#targets-and-categories)).
- **map frame**: the mod's work that runs once per `Game_Player#update`, in four stages
  ([Loading](../architecture/loading.md#map-frame)).
- **map owner**: a block registered with `Info.map_owner` that answers the info key on the map
  ([Readers](../architecture/readers.md#info-key)).
- **marker file**: `hook_loaded.txt` in the data folder, which holds the load line and the first failure of each
  place ([Diagnostics](../architecture/diagnostics.md#the-marker-file)).
- **mechanic**: a map's puzzle as a profile models it with `mechanic(kind, maps)`, of type `:state`, `:grid` or
  `:facing` ([World and routes](../architecture/world-and-routes.md#puzzles)).
- **message history**: `PokeAccess::History`, the last lines said, which the history keys browse by speech category
  ([Readers](../architecture/readers.md#message-history)).
- **mod key**: a key of the mod's own, such as the info key or the locator's keys, listed in `Config.keys`
  ([Keys](keys.md#mod-keys)).
- **override**: a replacement of a mod module's method or a game class's method, installed with `Hooks.override` and
  listed in `Hooks.overrides` ([Hooks](../architecture/hooks.md#functions-module-methods-and-overrides)).
- **painted text**: the text a screen draws, captured by the mod as drawn
  ([Readers](../architecture/readers.md#painted-text-capture)).
- **parity check**: `test/static/i18n_parity_test.rb`, which requires every file of `lang/` to hold every key with
  the same placeholders and the plural forms of its language ([Language files](lang-files.md#parity-check)).
- **pass**: one of the two runs of the suite, each in a Ruby process of its own: the gen-6 pass and the GameData pass
  ([Run and write tests](../guides/tests.md#the-whole-suite)).
- **passability probe**: `World::Probe`, the one place that asks the engine whether the player can take a step; a
  plugin's probe is another thing ([World and routes](../architecture/world-and-routes.md#passability-probe)).
- **plain passability**: the declaration, `plain_passability` in a profile, that the game's player passability reads
  only the map's tiles, its events and the mode, so the passability probe's answers outlive an event's end
  ([World and routes](../architecture/world-and-routes.md#map-memory)).
- **plan**: a `Routes::Plan`, the planner's answer for a target, of kind `:walk`, `:assisted`, `:surf`, `:company`,
  `:none`, `:cut` or `:far` ([World and routes](../architecture/world-and-routes.md#the-planner)).
- **plugin reader**: a file in `plugins/` that reads a community plugin's screens; a profile declares it, and the
  generic profile loads it when its probe matches ([Loading](../architecture/loading.md#plugin-readers-and-probes)).
- **plural form**: one of the texts of a key whose words change with a number, written `key.one`, `key.other` and the
  other suffixes of its language's rule ([Language files](lang-files.md#plural-forms)).
- **poller**: a block registered with `Frame.each_pulse`, or `poll_each_frame` in a profile, that runs on every pulse
  ([Loading](../architecture/loading.md#pulse)).
- **positional engine**: `PA3D_steam.dll`, built from `native/`, which places the mod's sounds around the listener
  with Steam Audio ([Guide and sound](../architecture/guide-and-sound.md#positional-audio)).
- **probe**: the class or method whose presence shows that a plugin is installed, as the detection table gives it
  ([Loading](../architecture/loading.md#plugin-readers-and-probes)).
- **profile**: the folder `games/<name>/` with one game's readers, rules and data; the launcher chooses it at install
  from the catalog ([Loading](../architecture/loading.md#profile-selection)).
- **pulse**: the mod's work that runs after every `Input.update`, once per frame in any scene and inside every modal
  loop ([Loading](../architecture/loading.md#pulse)).
- **reader**: code that turns a screen's state into speech ([Readers](../architecture/readers.md#what-a-reader-is)).
- **reading**: a kind of row, such as `:bag_item`, whose parts the mod says up to the level its scheme gives it
  ([Readers](../architecture/readers.md#verbosity-and-readings)).
- **reentrancy guard**: the rule that skips the hooks of other methods while the original of an `after_hook` runs
  ([Hooks](../architecture/hooks.md#reentrancy-guard)).
- **reference copy**: a copy of a third-party plugin that no surveyed game ships, kept under
  `../../../repositorios genericos/_refmods` ([Static checks](static-checks.md#census-sources)).
- **reference language**: English, `I18n::REFERENCE`, whose file gives the text of a key another language lacks
  ([Speech and languages](../architecture/speech-and-languages.md#the-mods-language)).
- **region**: a set of search states that plain steps join both ways, which `Routes::Regions` uses to tell whether a
  tile can be reached ([World and routes](../architecture/world-and-routes.md#regions)).
- **registrar**: a method of `PokeAccess::Hooks`, such as `after_hook`, that installs a hook
  ([Hooks](../architecture/hooks.md#what-a-hook-is)).
- **remap screen**: the Remap game controls screen of the configuration menu, which binds the game's buttons, the
  extras and the mod keys ([Keys](keys.md#remap-screen)).
- **room**: one of the parts into which the transfers within a map divide it
  ([World and routes](../architecture/world-and-routes.md#transfers)).
- **route style**: the `route_style` setting, which prices a route's presses and turns as `:shortest`, `:balanced` or
  `:straightest` ([World and routes](../architecture/world-and-routes.md#goals-cost-and-states)).
- **rule owner**: the tiles a terrain rule answers for, given by `:tags`, `:kinds`, `:flags` or `:tiles`
  ([World and routes](../architecture/world-and-routes.md#rules-a-profile-adds)).
- **runner check**: a check that `test/run.rb` makes on a whole pass, such as `ArityNet` or the test census
  ([Static checks](static-checks.md#runner-checks)).
- **scene watcher**: `PokeAccess::SceneWatcher`, which reads a screen that runs its own input loop: an around-hook
  holds the scene and a poller reads it on every pulse ([Readers](../architecture/readers.md#scene-watchers)).
- **scheme**: the set of levels that verbosity gives the readings, a built-in level or a player's own scheme
  ([Readers](../architecture/readers.md#verbosity-and-readings)).
- **screen reader bridge**: `prism_pea.dll`, built from `bridge/`, through which the mod's lines reach the screen
  reader ([Speech and languages](../architecture/speech-and-languages.md#the-screen-reader-bridge)).
- **script dump**: a game's scripts written out as `.rb` files by `tools/dump_scripts.rb`; the census builders read
  the script dumps under `../../decompiled Scripts` ([Static checks](static-checks.md#census-sources)).
- **self-check**: the Engine self-check row of the Debugging screen, which tests in the running game what the suite
  only stubs ([Diagnostics](../architecture/diagnostics.md#the-self-check)).
- **session recorder**: the recorder of `core/util/recorder.rb`, which writes a transcript of what the mod saw and
  said ([Diagnostics](../architecture/diagnostics.md#the-session-recorder)).
- **shared profile**: a profile in `games/<name>_common/` that the profiles of one family of games import, such as
  `games/rv_common/` ([Loading](../architecture/loading.md#manifests)).
- **silence watch**: `PokeAccess::Silence`, which lists the screens that came up and said nothing
  ([Diagnostics](../architecture/diagnostics.md#the-silence-watch)).
- **Sky fork**: the Essentials fork that puts the v22 interface on a v21.1 base, as Añil, Royal and World Frontier
  run it;
  `Engine.fork` answers `:sky` there ([Engine eras](../architecture/engine-eras.md#eras)).
- **slot**: a symbol that names a reader's change-detection record on its holder, so readers that share a holder keep
  their records apart ([Readers](../architecture/readers.md#change-detection)).
- **sonar**: the positional pings of the emitters near the player, played in full sound navigation
  ([Guide and sound](../architecture/guide-and-sound.md#sonar)).
- **sound family**: a group of sounds in `Sound::Catalog` that share a volume, a frequency, a tone and an on switch
  ([Guide and sound](../architecture/guide-and-sound.md#the-sound-catalog)).
- **soundscape**: what `Sound::Scheduler.tick` plays in the sound stage: the sonar, the water, the walls' winds and
  the shore ([Guide and sound](../architecture/guide-and-sound.md#the-soundscape)).
- **speech category**: the class of a spoken line, one of `Speech::CATEGORIES`, under which the message history files
  it ([Speech and languages](../architecture/speech-and-languages.md#speech-categories)).
- **speech output**: `PokeAccess.speak`, the one call every spoken line goes through on its way to the screen reader
  bridge ([Speech and languages](../architecture/speech-and-languages.md#the-speech-output)).
- **stage**: one of the four parts of the map frame, `:world`, `:control`, `:nav` and `:sound`, each running its steps
  by order number ([Loading](../architecture/loading.md#map-frame)).
- **step guide**: the guide that says the route to the selected target leg by leg
  ([Guide and sound](../architecture/guide-and-sound.md#the-step-guide)).
- **suite**: the test suite; it runs a gen-6 pass with the `pokemon_z` profile and a GameData pass with `anil`
  ([Run and write tests](../guides/tests.md#the-whole-suite)).
- **surveyed source**: a game's script dump, or the vanilla Essentials scripts, that the census builders read
  ([Static checks](static-checks.md#census-sources)).
- **target**: an entry of the locator's lists, such as an event, a map edge or a surface; the guides lead to the
  selected one ([Guide and sound](../architecture/guide-and-sound.md#targets-and-categories)).
- **track**: the states that the presses of the guides' route reach, by which the guides find the player on the route
  ([Guide and sound](../architecture/guide-and-sound.md#the-route-both-guides-follow)).
- **transfer**: an event that moves the player elsewhere, a `:warp` within the map or an `:exit` off it
  ([World and routes](../architecture/world-and-routes.md#transfers)).
- **verbosity**: the levels (brief, medium and full) and the readings that decide how much of a row the mod says
  ([Readers](../architecture/readers.md#verbosity-and-readings)).
- **witness**: the row count and the focused row that a command window's key carries, so a row that changes under a
  still cursor is read again ([Readers](../architecture/readers.md#interrupting-and-queueing)).
- **World layer**: `core/world/`, which reads the game's terrain, passability, events and puzzle mechanics, keeps
  what it reads and says nothing ([World and routes](../architecture/world-and-routes.md#layers)).
