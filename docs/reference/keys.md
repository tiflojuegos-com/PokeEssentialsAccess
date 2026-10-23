# Keys

This page lists every key the mod answers, with its default, its effect alone and with each modifier and where it
works, and what the remap screen of the configuration menu can bind. The guides and sounds these keys drive are
explained in [Guide and sound](../architecture/guide-and-sound.md).

## How the mod reads keys

- The mod reads its keys from the keyboard itself (`Keyboard.raw_down?`, through `GetAsyncKeyState`), not through
  the game's `Input`.
- A key counts as pressed on the [pulse](../architecture/loading.md#pulse) it goes down, against the picture of the
  keyboard the pulse takes first (`Keyboard.snapshot`).
- A mod key answers only while the mod is on (`Keys.enabled`) and the game window is in front (`Keys.focused?`).
- The game still sees the keys the mod answers. The mod's `Input` hooks change only the game buttons and extras that
  have a binding.

## Global gestures

| Keys | Effect |
|---|---|
| Ctrl+Alt+F8 | Turns the mod on or off and says so |
| Ctrl+Alt+F9 | Writes the diagnostic dump and says whether the file was written |
| Ctrl+Alt+F10 | Says the scene, the map and position, the last line and how many hooks are missing |

[Diagnostics](../architecture/diagnostics.md#the-diagnostic-dump) describes the dump and the spoken status.

The gestures are fixed: the remap screen does not list them, and no entry can take F8, F9 or F10. They are polled
before any other check, so they answer while the mod is off. While Ctrl and Alt are both held, the engine's
`Input::ALT` button and its F8 and F9 buttons read as released (`Remap.chord_button?`), so a gesture turns no game
turbo on and takes no screenshot.

## Mod keys

The mod keys are `Config.keys`, with their defaults in `Config::KEY_DEFAULTS` (`core/foundation/config.rb`).

| Action | Default | Alone | With Shift | With Ctrl |
|---|---|---|---|---|
| `:prev` | J (`0x4A`) | Previous target | Previous category | As alone |
| `:next` | L (`0x4C`) | Next target | Next category | As alone |
| `:where` | K (`0x4B`) | Says the selected target | Renames the target | Opens the target's menu |
| `:route` | I (`0x49`) | Says the route to the target | Turns the cane on or off | Turns the step guide on or off |
| `:info` | T (`0x54`) | Says the details of the focus | Says the last dialogue | Says the focused row whole |
| `:hp` | H (`0x48`) | Says the player's side's HP | Says the foes' HP | As alone |
| `:field` | G (`0x47`) | Says the field conditions | As alone | Sets or renames a marker here |
| `:coords` | M (`0x4D`) | Says the map and the coordinates | Renames the map | Cycles `hide_unreachable` |
| `:config` | O (`0x4F`) | Opens the configuration menu | As alone | As alone |
| `:hist_prev` | Home (`0x24`) | One message back | Previous history view | First message of the view |
| `:hist_next` | End (`0x23`) | One message on | Next history view | Last message of the view |
| `:verbosity` | None | Next verbosity scheme | As alone | As alone |
| `:shift` | Shift (`0x10`) | The Shift modifier | | |
| `:ctrl` | Ctrl (`0x11`) | The Ctrl modifier | | |

`:verbosity` ships unassigned because every letter is some game's key. With both modifiers held, Ctrl's action wins
on `:where`, `:route`, `:coords` and the history keys, and Shift's wins on `:info`.

What some rows do in full:

- `:prev` and `:next`: select the previous or next target of the category and say it. With Shift they switch the
  category, say it with its count and select its first target.
- `:where`: says the target's name, its number, its direction and the steps to it. With Ctrl it opens a menu in
  the game's choice window to rename the target, take off its name, change its category or hide it; on a marker it
  opens the marker's menu.
- `:route`: says the route as one line, or why there is none ([World and routes](../architecture/world-and-routes.md)).
- `:info`, the [info key](glossary.md): what it says depends on the screen ([Readers](../architecture/readers.md)).
- `:hp`: in battle, the player's battlers, or the Safari Balls left in the Safari Zone. Out of battle, the party's HP,
  with or without Shift.
- `:field`: in battle, the field effect, the weather, the terrain and each side's conditions. Out of battle, the
  weather, the game's clock and the time of day.
- `:coords` with Ctrl: moves `hide_unreachable` to its next value, saves it and says it
  ([Settings](settings.md#navigation-and-pathfinder-options)).

## Where the mod keys work

- `:prev`, `:next`, `:where` and `:route` are the locator's keys, polled in the `:keys` step of the
  [map frame](../architecture/loading.md#map-frame) (`Locator.poll_keys`). They answer on the map, with the
  configuration menu shut, while nothing locks them (`Control.keys?`). A message leaves them free. A menu, a battle,
  another scene or a screen looping over the map locks them.
- The other keys are polled on every pulse (`Keys.global_poll`), in every scene and modal loop, battles included,
  while the configuration menu is shut. One of them acts per pulse.
- `:coords` answers only with the locator's keys free and outside battle. Ctrl with `:field` sets a marker only on
  the map, under the same conditions, and otherwise says that markers go on the map.
- `:config` opens the menu only on the map scene; elsewhere it says so.

What a key says goes to the message history: the locator's keys, `:coords` and the marker under `:nav`, `:info`,
`:hp` and the field conditions under `:info`, the gestures and the configuration menu under `:system`.

## Region map

While the region map is open, the locator's keys move its cursor to the nearest fly point in a direction
(`TownMap::DIRS`, `TownMap.jump`). With no fly point that way, the mod says so. A profile can turn the jumps off
(`TownMap.jump_enabled`), as Royal's does.

| Action | Default | Moves the cursor |
|---|---|---|
| `:prev` | J | Left |
| `:next` | L | Right |
| `:route` | I | Up |
| `:where` | K | Down |

## Keys in the configuration menu

The menu runs on the game's buttons, so Up, Down, Left, Right, Confirm and Cancel are the engine's keys or their
bindings.

| Key | In a list of the menu | On the remap screen |
|---|---|---|
| Up, Down | Moves one row, wrapping | Moves one entry, wrapping |
| Left, Right | Changes the row's value | Left restores the entry's default |
| Confirm | Enters, toggles or runs the row | Waits for the key to bind |
| Cancel | Goes back; at the top, closes and saves | Goes back |
| `:info` | Says the row's help | Says the entry whole |
| Ctrl with `:info` | Says the row, its value and its help | As `:info` alone |

While the remap screen waits for a key, Cancel cancels and the first key pressed is bound. Alt is taken only when it
is released with nothing pressed beside it, since Alt+Tab, Alt+F4 and Alt+Enter belong to the window and the engine.
After a capture, the screen ignores input until the captured key is released.

## Remap screen

The remap screen ("Remap game controls", `core/menus/config_remap.rb`) lists its entries in this order
(`Remap.buttons`): the game's buttons (`Remap::BUTTONS`), the profile's extras (`Remap.extras`), the mod keys
(`Remap::MOD_KEYS`) and an entry that resets all keys. Each entry says its action and the key it is on.

| Action | Game button | Label |
|---|---|---|
| `:down` | `Input::DOWN` | Down |
| `:left` | `Input::LEFT` | Left |
| `:right` | `Input::RIGHT` | Right |
| `:up` | `Input::UP` | Up |
| `:c` | `Input::C` | Confirm |
| `:b` | `Input::B` | Cancel |
| `:a` | `Input::A` | Action A |
| `:x` | `Input::X` | X button |
| `:y` | `Input::Y` | Y button |
| `:z` | `Input::Z` | Z button |
| `:l` | `Input::L` | Left page |
| `:r` | `Input::R` | Right page |
| `:alt` | `Input::ALT` | Alt (game turbo) |

A game button with no binding stays on the engine's keys. `Input::ALT` is the button the fangames' turbo scripts
read; mkxp-z's own F1 window cannot bind it.

### What a binding changes

- Mod key: the action answers the new key alone. A new `:shift` or `:ctrl` key moves that modifier for every mod
  key.
- Game button: while the mod is on and the game window in front, the button answers only its bound key
  (`Remap.remapped_button?`). With the mod off, the engine's keys work again.
- Direction: the bound key works beside the engine's keys, through `dir4` and `dir8`. Of several bound directions
  held, the one pressed last counts.
- Extra: the bound key takes the place of the raw key the game reads, through `triggerex?` and `pressex?`, on
  engines that have them.
- Repeat: a bound key repeats on the schedule of the input the game reads (`Remap.repeat_schedule`): the game's own
  Ruby input, or mkxp-z's.
- Without `GetAsyncKeyState` (`Keys::GAKS`), no binding applies.

### Keys no entry can take

| Key | Kept for |
|---|---|
| Enter, Space, Escape, the arrows | The engine's own answers |
| F1 | mkxp-z's settings window, which works by mouse only |
| F2 | The engine's frame rate counter |
| F12 | The game reset |
| F8, F9, F10 | The mod's Ctrl+Alt gestures |

The list is `Remap::RESERVED`. A key in it is refused with what keeps it.

### Conflicts and defaults

- A key another entry holds is refused with that entry's name (`Remap.conflict`). An extra still on its default raw
  key holds that key.
- Left on a mod key restores its shipped key, or none for one that ships unassigned. Another entry holding that key
  now blocks it.
- Left on a game button puts it back on the engine's keys, and on an extra back on its default raw key.
- The last entry resets all keys on a second Confirm. It drops every game binding and restores every mod key's
  default.

## Saved keys

`settings.ini` keeps the bindings with the other settings ([The settings file](settings.md#the-settings-file)):

- `bind_<action>=<code>`: a bound game button or extra.
- `key_<action>=<code>`: a mod key moved off its default. A mod key on its default is not written, so a new default
  reaches every player.
- Codes are Windows virtual-key codes, written in decimal.
- At load, a code that is not positive or is reserved is dropped (`Settings.free_code?`).
- A mod key left on a default that a saved binding uses loads unassigned (`Settings.drop_taken_defaults`), so the
  saved binding keeps working.

## Key names

`ConfigMenu.keyname` names a key for speech:

- A key with a word of its own (`ConfigMenu::KEYNAMES`), such as Enter, Home or the arrows, by that word.
- Digits and letters as themselves; numpad digits and F1 to F24 by their number.
- Any other key by the character the game window's keyboard layout types on it (`Keyboard.char_code`), else by its
  code.

A spoken text that names a mod key carries `%{key_<action>}`, which `ConfigMenu.key_vars` fills with the key as bound.

## Key hints the games paint

`KeyHints.localize` says a key hint the game paints, such as "[A] Curar", with the key the player uses now, for the
letters a profile declares with `key_hints` ([Key hints](../architecture/readers.md#key-hints)). The key that
mkxp-z's F1 window gave a button comes from `NativeKeys`, which reads `keybindings.mkxp1` in mkxp-z's data directory,
in a game whose input mkxp-z answers. A game that reads the keyboard in Ruby defines `Input.getstate`, and F1's
bindings do not apply to it. Royal's profile takes the letters from the game's own key menu
(`games/royal/key_hints.rb`).

## Keys a screen takes over

| Call | Effect | Called by |
|---|---|---|
| `Keys.typing!` | The pulse's keys do nothing; the gestures still answer | A text field |
| `Keys.yield_key!(:info)` | The info key does nothing | A game screen that answers that key itself |
| `Keys.menu_lock!` | `:config` does nothing; the other keys still answer | A game menu that reads raw keys |

Each call lasts four pulses, so a caller repeats it on every frame the situation lasts. Reminiscencia's party screen
opens the PC on T, so the info key yields to the game while the player chooses a member
(`games/reminiscencia/party_keys.rb`).

## What a profile can change

| DSL method | Effect |
|---|---|
| `button_labels` | Renames game buttons on the remap screen, such as Pokémon Z's X, Y and Z |
| `remap_extra` | Adds a raw key the game reads to the remap screen |
| `key_hints` | Declares the letters its hints paint and the buttons they stand for |

The methods are described in the [profile DSL reference](profile-dsl.md).
