# Loading

This page explains how the mod enters a running game: the files the launcher installs and the profile it chooses, the
preload script and the deferred boot, the load order of core, plugin readers and profiles, the F12 reset, and the two
beats the mod's own work runs on. Read it before adding a profile or a plugin reader, or when the mod does not start
in a game.

## Installed layout

The launcher copies the mod into an `accessibility/` folder inside the game's folder
([Install and release](../guides/install-and-release.md)):

- `core/`, `lang/` and `plugins/`, from the folders of the same name.
- `game/`, from `games/<profile>/`, the [profile](../reference/glossary.md) the launcher chose for the game.
- `common/<name>/`, from each [shared profile](../reference/glossary.md) `games/<name>/` that the profile imports.
- `boot.rb` and `preload_access.rb`, from `loader/`.
- `sounds/`, from `assets/sounds/`, and `lib/`, from `assets/x86/` or `assets/x64/` by the game's architecture.
- `data/`, which holds the player's `settings.ini` and tags, the mod's logs and the launcher's `installed.json`. A
  reinstall keeps it.

The launcher also adds `accessibility/preload_access.rb` to the `preloadScript` list in the game's `mkxp.json`. The
game's scripts stay as they are. `PokeAccess::Paths` holds this layout for the mod's code. Its `DATA`, the
[data folder](../reference/glossary.md), falls back to an `accessibility` folder in mkxp-z's per-game data directory
(`System.data_directory`) when `accessibility/data` cannot be written.

## Profile selection

The launcher chooses the profile when it installs the mod, from the [catalog](../reference/glossary.md),
`games/catalog.json`. It tries three tests in order:

1. The `titles` of each entry against the title in `mkxp.json` or `Title=` in the game's `.ini`. The longest match
   wins.
2. The `detect` pattern of each entry against the game's folder and executable names. The longest match wins.
3. The executable names in `exes`.

When nothing matches, the launcher asks which profile to install. The generic profile, `games/generic/`, serves a game
with no profile of its own. The boot does not detect the game: it loads whatever `accessibility/game/` holds.

A catalog entry can also name a `convert` engine, the mkxp-z build the launcher moves the game to when it still runs
on the RPG Maker XP player. It can name a `compat` script too, which the launcher registers in `preloadScript` before
the mod's own entry. Uranium's `games/uranium/compat.rb` runs before the game's scripts and turns off the parts
written for its original player that mkxp-z cannot run.

## Preload script

mkxp-z runs the `preloadScript` entries before the game's script list, when no class of the game exists yet. A hook
binds by class name when it registers ([Hooks](hooks.md)), so the mod cannot load at that point.
`loader/preload_access.rb` defers the boot. It wraps `Graphics.update` and, after each frame, asks
`AccessPreload.ready?`, which is true when both hold:

- No thread of the game is still evaluating its scripts, as Rejuvenation's `ThreadLoader` does.
- `$scene` is set, or 120 frames (`READY_FRAME`) have passed and `Main`, the last script, has defined `pbCallTitle`.

On the first ready frame the preload evaluates `accessibility/boot.rb` at the top level, once. An exception that
escapes the boot goes to `accessibility/data/loader_error.txt`, and the game goes on.

The preload writes `accessibility/data/preload_started.txt` as it starts, so the file tells a preload that never ran
from a boot that failed. After 1800 frames (`STALL_FRAME`) without becoming ready, the preload adds one `stalled`
line to it ([Files of the loader](diagnostics.md#files-of-the-loader)).

The mod does not read a screen that the script list shows before `Main` runs, because it has not loaded yet. In
Africanus and Reminiscencia, `pbSetUpSystem` runs at the top level of `PSystem_System`. On a first run, with no save
data, it asks for the language with `pbChooseLanguage`.

## Load order

`PokeAccessBoot.run` in `loader/boot.rb` loads the mod in this order:

1. Core: every module that `core/manifest.rb` lists, in its order.
2. The plugin readers the profile declares ([Plugin readers and probes](#plugin-readers-and-probes)).
3. The shared profiles the profile imports, in the order of its `:imports`.
4. The game's profile, in `accessibility/game/`.
5. The player's settings: `PokeAccess::Settings.apply` reads `settings.ini` over the defaults that core and the
   profile set.
6. The boot's diagnostics, logged: the hooks whose method does not exist and the `variants` groups that bound under
   no name (`Hooks.missing` and `Hooks.unbound`), and a game that only the fallback data provider serves.

The shared profiles and the game's profile load after the plugin readers, so they can override one. The settings come
last, so the player's choices win over the profile's.

Each folder's `manifest.rb` gives the order. The boot never reads a folder's contents, so a file that the manifest
omits does not load; `test/static/manifest_check_test.rb` reports a file on disk that no manifest lists. The boot
evaluates each file at the top level (`TOPLEVEL_BINDING`). A file that raises is logged with its backtrace, and the
boot goes on with the next one.

### Manifests

A manifest is a Ruby literal that the boot evaluates. Core's is an Array of module paths without `.rb`. A profile's
is either such an Array or a Hash with `:modules` and, when it needs them, `:plugins` and `:imports`
([Manifest keys](../reference/profile-dsl.md#manifest-keys)).

A shared profile lives in `games/<name>_common/`. It has no catalog entry and imports nothing itself
(`test/static/imports_test.rb`). The boot logs and skips a folder without a manifest, a manifest of
neither shape, an import whose folder has no manifest and a declared plugin reader with no file.

## Plugin readers and probes

`plugins/manifest.rb` is the [detection table](../reference/glossary.md). It maps each plugin reader's name to its
[probe](../reference/glossary.md): a class name, or `"Class#method"` when a class name alone does not identify the
plugin, as when it adds a method to a class that other games also have. The probe of the Deluxe Battle Kit is
`"Battle#pbToggleSpecialActions"`, and a top-level function's is `"Object#name"`. The boot stores the table in
`PokeAccess::Plugins.table`.

A profile names its plugin readers in `:plugins`. The boot adds the lists of the shared profiles it imports, in import
order and once each. It loads every named reader whatever its probe says, and it never adds a reader by itself, because
two games can ship the same plugin class with different internals.

The generic profile declares `:plugins => :auto`. The boot then asks `Engine.has?` for each probe in the table and
loads every reader whose probe matches, in name order.

`Plugins.note_loaded` records each reader the boot loads. `Plugins.undeclared` lists the plugins the running game has,
by their probes, whose reader did not load; the diagnostic dump prints them ([Diagnostics](diagnostics.md)). Every hook
in `plugins/` is registered `:optional` (`test/static/plugins_test.rb`), so a declared reader whose plugin is absent
adds nothing to `Hooks.missing`. A game that ships an older or edited copy of a plugin has its reader in its profile
([Choose where a reader goes](../guides/choose-where-a-reader-goes.md)).

## F12 reset

F12 makes mkxp-z raise `Reset` out of `Graphics.update` and evaluate the game's scripts again. The preload script does
not run again, and the boot is not repeated:

1. `AccessPreload.note_reset` sees the `Reset`, once the mod has loaded, and keeps the game's current `pbCallTitle`.
2. The game's scripts run again. Their definitions replace the wrappers the mod had installed.
3. On each frame, `AccessPreload.after_reset` waits until no script thread is loading and `Main` has defined
   `pbCallTitle` anew, or, in a game without that method, until 120 frames have passed.
4. It calls `Hooks.after_reset`, which installs every replaced wrapper again (`Hooks.rebind`) and clears the per-run
   caches (`Caches.reset_all`).

[Hooks](hooks.md#game-resets) explains how a wrapper is recorded and put back.

## The two beats

A hook runs when the game calls its method. The rest of the mod's work runs on two beats, both in
`core/input/frame.rb` (`PokeAccess::Frame`): the pulse, once per frame in any scene, and the map frame, once per update
of the player on the map.

### Pulse

`Input.update` runs on every frame, in every scene and inside every modal loop a screen runs. The mod wraps it with
`Hooks.keep_bound`, so an F12 reset puts the wrapper back. After the game's update, the pulse runs these jobs:

1. `Keyboard.snapshot` takes the frame's picture of the keys, so every reader in the frame compares against the same
   keys.
2. `Remap.update` tracks how long each remapped key has been held.
3. `Keys.global_poll` handles the mod's own keys: on and off, the configuration menu, the
   [info key](../reference/glossary.md) and the other contextual keys.
4. The pollers registered with `Frame.each_pulse` run in registration order. A profile registers one with
   `poll_each_frame` ([Profile DSL](../reference/profile-dsl.md)).
5. `Control.pulse` checks for a change of scene or a stalled map.

The pollers serve screens that run their own loop, the session recorder and the silence watch. `Graphics.transition`
does not call `Input.update`, so a transition makes no pulse.

### Map frame

`Frame.run` is bound to `Game_Player#update` with `frame_hook`. In gen-6 a wild battle runs inside that method, and a
guarded hook would mute every battle reader for the whole fight ([Containers](hooks.md#containers)).

A map frame runs four [stages](../reference/glossary.md) in this order, and each stage runs its steps by order
number:

1. `:world` settles what changed: a map change, a teleport within the map, forced movement, the end of an event or of
   a battle, and the locator's information.
2. `:control` evaluates whether the player has free control, now that the world has settled, and emits
   `:control_lost` or `:control_regained`.
3. `:nav` runs the navigation steps ([Guide and sound](guide-and-sound.md)):
   - `:listener` moves the sound listener to the player's tile.
   - `:feedback` plays the sounds of the player's own moves, and `:surfaces` says the ground underfoot and the water
     ahead.
   - `:guide` runs the two guides, `:puzzles` follows the map's puzzle and `:keys` polls the locator's keys.
   - `:regions` and `:hpa` run a slice of the route searches' background work, the region walk and the HPA* graph
     ([World and routes](world-and-routes.md)).

   The listener, the cues, the guides and the background work wait while something holds the player
   (`Control.free?`).
4. `:sound` runs the soundscape.

The first three stages run only while `Locator.polling?` is true: a map and a player exist, the mod is on and its
configuration menu is closed. `Frame.run` runs them inside `Speech.as(:nav)`, so what they say takes the `:nav`
[speech category](speech-and-languages.md#speech-categories). The sound stage runs on every map frame, so it can also
silence what must stop.

The listener moves first so that a step or the guide's chime from a new tile sounds from where the player stands
(`Sound.follow_player` in `core/sound/cues.rb`).

`Frame.step` registers a step in a stage at an order number. Lower numbers run first, and equal numbers keep their
registration order. Registering a name again replaces its step. `core/input/frame.rb` registers every step at its
end, so that file holds the frame's whole table.

### Counters and failures

- `Frame.serial` counts map frames. Memos kept for one map frame key on it, such as the one in `Control.reason`.
- `Frame.pulses` counts pulses. A modal loop opened from a step pulses while its map frame is still running.
- `Frame.running?` is true while a map frame runs.
- Each pulse and each map frame starts with `World::Epoch.dirty!`, which marks the world unsettled so that the next
  question about it reads it again.

Each step, each pulse job and each poller runs inside a rescue. The first failure of each goes to the
[marker file](../reference/glossary.md), under `frame_<step>`, `pulse_<job>` or `frame_poller_<n>`, and the rest of
the frame goes on. The keyboard snapshot runs outside those rescues: its failure ends that pulse and is logged as
`input_frame`. `PokeAccess::Perf` measures the pulse as `input_frame` and each stage as `frame_<stage>`.

### Stalled map

A screen can loop over the map without a flag or a scene change. Its pulses then go on with no map frame. After six
pulses in a row (`STALL_PULSES`), about a tenth of a second, `Frame.stalled?` is true; a message closing leaves two
such pulses in a normal game. `Control` then reports the reason `:stalled`: the cues, the guides and the soundscape
go quiet, and the locator keys lock. The map frame cannot see the stall, since it has stopped running, and
`Control.pulse` reports it instead.

## Files the loading writes

The preload writes `preload_started.txt` in `accessibility/data`, and the error of a boot that fails to
`loader_error.txt` in the same folder. The boot writes its own lines to `loader_error.txt` in the data folder, or in
`accessibility/data` before `PokeAccess::Paths` has loaded. The hooks, the steps and the pulse jobs write their first
failures and each F12 reset to the marker file, `hook_loaded.txt`, in the data folder.
[Files of the loader](diagnostics.md#files-of-the-loader) and
[The marker file](diagnostics.md#the-marker-file) describe their lines.
