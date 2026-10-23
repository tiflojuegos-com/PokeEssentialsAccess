# PokeEssentialsAccess technical documentation

PokeEssentialsAccess is an accessibility mod for Pokémon Essentials fangames on mkxp-z. It reads the game's screens
through a screen reader and adds navigation by sound, without modifying the game's scripts.

This documentation is for people who maintain or extend the mod. It assumes Ruby and some Pokémon Essentials code, and
explains the mod's own internals. The players' manuals are [README.en.md](../README.en.md) and
[README.es.md](../README.es.md) at the root of the repository.

Start with the [Overview](architecture/overview.md), then open the guide for the task at hand. The
[Glossary](reference/glossary.md) defines the terms the pages use.

## Architecture

How each part of the mod works and why it is built that way.

- [Overview](architecture/overview.md): what the mod does, its three layers, the design rules and the source tree.
- [Loading](architecture/loading.md): the installed layout, profile selection, the preload script, the boot and its
  load order, plugin readers and probes, the F12 reset, the pulse and the map frame.
- [Engine eras](architecture/engine-eras.md): gen-6, GameData, v22 and the Sky fork, their detection, data providers
  and capabilities, the class names that change between versions, the Reborn engine, and the constraints of Ruby 1.8.7
  and of the core methods some games redefine.
- [Hooks](architecture/hooks.md): how a hook binds, several hooks on one method, the reentrancy guard and containers,
  game resets, failures and the diagnostic lists.
- [Readers](architecture/readers.md): how a screen becomes speech through dialogue, command windows and change
  detection, painted text, information windows, scene watchers, the info key, verbosity, the message history and key
  hints, and where readers go.
- [World and routes](architecture/world-and-routes.md): the World layer, the route planner and its searches, regions,
  assisted steps, water and surfing, transfers, puzzles and route text.
- [Guide and sound](architecture/guide-and-sound.md): the locator's targets and categories, the cane and the step
  guide, positional audio, the flat channel and the sound catalog, the soundscape and its sonar, and the cues of the
  player's moves and of the surfaces.
- [Speech and languages](architecture/speech-and-languages.md): the speech output and the screen reader bridge,
  game text and control codes, speech categories, interrupting and queueing, braille, the mod's language, plural
  forms and game text in builds of several languages.
- [Diagnostics](architecture/diagnostics.md): the diagnostic dump and its lines, the marker file, the files of the
  loader, the session recorder, the self-check and the silence watch.

## Guides

One task each, from a starting point to a result to check.

- [Add a profile](guides/add-a-game-profile.md): create a profile with its manifest, catalog entry, constants,
  passability and first readers, and check that it loads.
- [Add a reader](guides/add-a-reader.md): find the screen's class in the game's scripts, choose the hook, read what the
  screen paints and test it in both suite passes.
- [Add a plugin reader](guides/add-a-plugin-reader.md): a reader in `plugins/`, its probe, the profiles that declare it
  and its census entry.
- [Choose where a reader goes](guides/choose-where-a-reader-goes.md): the placement by the screen's origin and the
  version exception.
- [Add a setting](guides/add-a-setting.md): a row in the configuration menu, with its key, default, help text and
  test.
- [Add spoken text](guides/add-spoken-text.md): a key in every `lang/` file, plural forms, the impersonal voice and the
  parity check.
- [Debug a silent screen](guides/debug-a-silent-screen.md): from a screen that says nothing to the cause, through the
  diagnostic dump, the real class and window names, suppressed hooks and missing instance variables.
- [Run and write tests](guides/tests.md): run the suite or one pass, filter by path, repeat a seed, write a test and
  regenerate the censuses.
- [Install and release](guides/install-and-release.md): install with the launcher's console in one game or in all of
  them, and publish a release.

## Reference

Interfaces, settings, keys and files, complete and terse.

- [Profile DSL](reference/profile-dsl.md): the manifest keys and every method a profile can call, with its arguments
  and effect.
- [Hooks API](reference/hooks-api.md): the registrars, their block arguments, options, timings, failure behavior and
  lists.
- [Reading APIs](reference/reading-apis.md): the speech calls, `PokeAccess::Cursor`, command windows and focus
  readers, `SceneWatcher`, `PaintCapture`, `Info`, `Verbosity` and `KeyHints`, with their signatures.
- [Settings](reference/settings.md): every setting of the configuration menu, its key in `settings.ini`, its default
  and its effect.
- [Keys](reference/keys.md): the default keys, what each does and how the remap changes them.
- [Language files](reference/lang-files.md): the format of `lang/*.txt`, its keys and placeholders, the plural forms
  of each language and the checks the suite runs on the files.
- [Static checks](reference/static-checks.md): each static test and census under `test/static/`, what it guards and
  how to regenerate it.
- [Glossary](reference/glossary.md): the terms these pages use, one per concept.
