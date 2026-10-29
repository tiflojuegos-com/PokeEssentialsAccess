# Guide and sound

This page explains how the mod leads a player who cannot see the map: the locator's targets and categories, the two
guides toward a target, the positional sounds around the player and the sounds of the player's own moves. The keys
are listed in the [keys reference](../reference/keys.md) and the settings in the
[settings reference](../reference/settings.md).

## Stages of the map frame

The guides and the sounds run in the [map frame](loading.md#map-frame), once per `Game_Player#update`. Its `:nav`
stage places the positional engine's listener on the player's tile (`:listener`), plays the sounds of the player's
own moves (`:feedback`), says the ground underfoot and the water ahead (`:surfaces`), runs the two guides (`:guide`)
and polls the locator's keys (`:keys`). Its `:sound` stage runs the soundscape on every map frame, so it also silences
the sounds when the map stops listening.

Most of this waits for free control. `Control.free?` is false while something holds the player: a message, a menu, a
battle, an event's script, another scene or a screen looping over the map (`core/input/control.rb`). The cues, the
guides and the soundscape stay quiet meanwhile. The locator's keys follow `Control.keys?` instead, which a message
leaves free.

## Targets and categories

The locator (`core/nav/locator.rb`) lists the targets of one category at a time and keeps one of them selected,
`Locator.target`. Both guides lead to that target. Naming lives in `core/nav/locator_naming.rb`, and the targets the
locator makes itself, such as surfaces and map edges, in `core/nav/locator_surfaces.rb`.

The player cycles the categories of `Config.categories`. `:puzzles`, `:lens` and `:marks` join them only while the
map has something of their kind (`Locator.active_categories`). What each category lists:

- `:all`: every event with a sprite, every transfer, every examinable event and every lens tile, and the map edges
  the player can step off.
- `:people` and `:objects`: events with a sprite that are not exits, split by `Locator.event_category`. A hazard, an
  item ball, a lever or a container is an object.
- `:exits`: transfer events, a wide doorway as one target, and the map edges that lead to a connected map.
- `:signs`: events without a sprite that show text when examined and do not transfer.
- `:extras`: the other examinable events without a sprite.
- `:surfaces`: the nearest tile of each kind of ground the player can reach (`Locator.surface_targets`).
- `:puzzles`: the targets of the map's puzzle (`Puzzles.category_targets`), while it has any.
- `:lens`: the Lens of Truth tiles (`#EOT` events), on a map that holds one.
- `:marks`: the player's own markers, on a map that carries one.

Rules come before detection. A [profile](../reference/glossary.md) files events with its `event_category` rules
and hides them with `event_hidden` ([profile DSL](../reference/profile-dsl.md)). The category the player gives an
event in the Ctrl+K menu (`PokeAccess::Tags`) wins over the profile's and the detected one. An event the player or
the profile hides is left out of the locator and the sonar.

`hide_noninteractive` and `hide_unreachable` filter the event categories. The categories the locator makes itself
are never hidden by reach (`Locator::SYNTHETIC`). `target_order` sorts a list by distance, by the presses to walk
there or in a fixed order. Each target keeps an identity across rebuilds, an event's id or a synthetic target's key,
so the selection survives a rebuilt list (`Locator.identity`).

Selecting a target turns on, in silence, the guides that `auto_guide` and `auto_steps` ask for (`Guide.arm`).

## The route both guides follow

The cane and the step guide share one route and its bookkeeping (`core/nav/guide.rb`). `Locator.route_plan` asks the
route planner for a plan toward the target ([World and routes](world-and-routes.md)). The plan's kind says what the
guides do with it: walk its presses, stop at an obstacle (`:assisted`) or at the water's edge (`:surf`), or tell
why there is no way.

`Guide.track` replays the plan's presses from the player's state with `Routes::Moves.trace`. The result is the
track: the state each press reaches, as a tile and a bridge level. An index from state to presses walked lets
`Guide.locate` find the player on the track after every step, forward or back.

`Guide.follow` keeps the route current on each map frame. It plans again in these cases:

- The target changes, or the player leaves the track.
- The target moves. The guide plans at most every `RECHECK_SEC` (half a second), and at once when the route has run
  out.
- An event's change touches a tile of the route, or the event epoch moves, and the rest of the route stops
  replaying.
- The next press, or the next `WINDOW` presses, stop replaying. Each is checked every `RECHECK_SEC`.

A route replays when tracing its presses again from the player's state lands on the track's tiles
(`Guide.replays?`). A change the route's tiles do not show, such as a felled tree, reaches the guide through
`Guide.event_ended`: an event that ends drops a plan with no way or one held at an obstacle.

Without a route the guides say why once (`Routes::Text.none`), unless the line that selected the target already
said it. The verdict holds while the regions stay the same and the player stays in the zone it was told in. A
verdict from a search that ran out of budget (`:cut`), or for a target beyond `route_reach` (`:far`), is tried again
after `CUT_TILES` tiles or `CUT_SEC`.

When no presses are left, `Guide.arrive` decides what follows:

- Where the route stops short of the target, at an obstacle or a shore, the guides stay on. They say what to do
  there once per tile (`Routes::Text.hold`, `Routes::Text.surf_hold`).
- On a puzzle goal that holds its piece, they stop and say the piece's line.
- Otherwise they stop with `Locator.arrived_line`, which also names a dive spot's action or a map edge's way off.

`Guide.tick` does nothing while the engine carries the player (`Control.carried?`: an ice slide, a forced movement or
a plugin's carrier). It also waits while the [passability probe](world-and-routes.md#passability-probe) cannot keep
its answers (`World::Probe.stable?`), partway up a side stair. The guides take the route up again where the player
lands.

## The cane

The cane chimes toward the next press (`Guide.cane`). The chime is the `:guide` sound, placed by its catalog entry
([The sound catalog](#the-sound-catalog)).

- The rhythm comes from `guide_freq`. With `guide_rhythm` at `:distance`, the gap grows with the Manhattan distance
  to the target, up to twice as long at `FALLOFF` tiles.
- A turn in the route chimes at once, `CHIME_GAP` after the last chime at the soonest.
- The volume is `event_volume` times one less the distance to the target over `FALLOFF`, never below 35 %.

Some ground lets the player on only with the direction key held down (`Routes::Moves.held?`). When the next press
lands on such ground, the cane says so once, unless the step guide is on, whose leg says it. With the positional
engine, the cane also plays the `:guide_hold` loop toward the next step in place of the chimes.

Both guides play the `:jump` cue once before a press that jumps, such as a ledge or an event that hops the player
over what it stands on. The cane alone also says the jump in words, since the step guide says it as a leg.

With no way to the target, the cane chimes straight toward it once per tile and direction (`Guide.straight_dir`). It
takes the longer axis if a step that way is open, else the other axis, else whichever way leads into water to surf.

## The step guide

The step guide says the route leg by leg (`Guide.say_leg`). `Routes::Text.legs` cuts the presses left into runs of
one direction. A press that cannot be undone, a jump or a slide, is a leg of its own, and ground where the key must
be held is said with its leg. A leg is said when it is new: another direction or kind, a longer count, or the next
run past a transfer. A count that falls as the player walks stays silent.

## Turning the guides on and off

- Shift+I turns the cane on or off and Ctrl+I the step guide (`Guide.toggle`). Each says the target's name, or that
  it is off. Turned on, a guide says again what to do at an obstacle and the jump ahead.
- With no target selected, the toggle says so and turns nothing on.
- The cane's row among the sound switches of the configuration menu toggles the same state
  (`ConfigMenu::GUIDE_ROW`). The state is never saved.
- A map change or a load turns both guides off in silence, and so does a category switched to an empty list.
- A target that stops applying, such as an item ball picked up, ends both guides with "Target lost".

Most of the guides' lines wait in the speech queue. Turning a guide on or off interrupts what is being said. A new
leg interrupts the step guide's last leg while nothing else was said after it. The line that stops the guides
interrupts only while nothing was said since their last frame (`Guide.fresh?`), so a forced move's notice in the same
frame is kept.

## Positional audio

The positional engine is `PA3D_steam.dll`, built from `native/pa3d_steam.c`. It places each source with Steam Audio's
HRTF, or in plain stereo with `audio3d_hrtf` off, and mixes and plays the sources through miniaudio. The repository carries one build per architecture in
`assets/x86/` and `assets/x64/`, each with Steam Audio's `phonon.dll` beside it. The launcher installs the one that
matches the game into `Paths::LIB` ([Installed layout](loading.md#installed-layout)), which `core/speech/backend.rb`
adds to the DLL search path.

`Sound::Native` binds the dll's entry points with `Win32API` on first use and leaves out the ones the dll lacks.
`Native.available?` asks only for the entry points the engine cannot run without (`Native::NEEDED`). In the suite,
`Sound::Native.shadow` takes the dll's place (`test/support/sound_helpers.rb`).

`Sound::Pa3d.boot` runs once per session, on the first map frame with sound navigation on. It starts the device,
reads its sample rate and loads one channel per catalog sound with a file. At a 48000 Hz device it loads the copies
in `assets/sounds/48000/`. A boot that fails is written to the marker file and said once, queued: the sonar, the
water and the winds fall silent, and the other cues play flat. After the first boot the scheduler plays the game's
current BGM and BGS again (`Scheduler.replay_music`).

Positions are tiles, scaled by `Pa3d::TILE_UNITS`. The listener moves to the player's tile on each map frame with
control free. It always faces north, whatever way the player faces, so a sound east of the player is heard to the
right. A source's volume falls linearly from one tile away to the reach, the distance at which it goes silent. The
scheduler sets the reach `Scene::FADE` tiles past the largest of the sonar's range, the wall range and the guide's
distance (`Scheduler.reach`).

`Sound.engine_tile` sends the sounds placed to the side, the guide's chime and the jump, through the engine only toward
the left or the right, `guide_distance` tiles to that side. Ahead and behind they play flat from the centre, pitched
high ahead and low behind (`Catalog::GUIDE_FLAT`).

- Each channel plays at its family's tone (`Mixer.pitch3d`), which `Scheduler.tones` sets while the soundscape plays.
  The sounds placed to the side or by heading set theirs as they play.
- `PA3D_Occl` muffles a channel: the lows pass and the highs are cut, so a source behind a wall stays audible.
- `PA3D_Air` takes treble off distant sources while `audio3d_air` is on.
- `PA3D_Hrtf` puts the engine in plain stereo while `audio3d_hrtf` is off. A channel pans between the left and the
  right by the left-right part of its direction, and plays up to 20 % higher straight ahead and as much lower
  straight behind, the pitches of the flat wall cue (`Catalog::WALL_FLAT`). A sound on the player keeps its pitch.
- `Pa3d` sends an order only when it changes what the engine holds.

## The flat channel

`Sound::Flat` plays through the game's sound effect channel (`Audio.se_play`), with files already panned (`_l`, `_c`,
`_r`) at a pitch from 50 to 150. It carries the earcons that never use the engine: the radar's tick, the minigames'
gauge (`Sound.gauge`) and the puzzle grid's cells (`Sound.cell`). It also stands in for the engine's one-shot cues
while the engine is down or `sound_nav` is off. Loops and sonar pings have no stand-in.

## The sound catalog

`Sound::Catalog` declares every sound of the mod in one table (`core/sound/catalog.rb`). A family carries the
settings its sounds share: a volume, a frequency, a tone and an on switch. `Config` builds the menu's rows and
their `settings.ini` keys from the families (`Catalog.rows`). A family can take a setting it lacks from another one
(`:from`).

A sound names its family, the file the engine loads, a role, a place and its flat stand-in. The roles:

- `:ping`: an emitter the sonar pings; `rank` orders the ping kinds.
- `:loop`: a sound held while its source lasts, such as the water, the winds and the guide's held tone.
- `:cue`: a one-shot its caller places.
- `:earcon`: a sound that always plays flat.

The places of a cue or a held loop:

- `:side`: `guide_distance` tiles to the left or right, flat ahead and behind.
- `:heading`: to the side, or on the player ahead and behind.
- `:front`: the tile the player pushes into.
- `:player`: the player's tile.

```ruby
# core/sound/catalog.rb
sound(:guide, :guide, :file => "pa3d_guide", :place => :side, :flat => GUIDE_FLAT, :clamp => [70, 140],
      :glossary => [:snd_guide, :snd_guide_help, "pa3d_guide", 100])
```

Callers name a sound, never a file. `Sound.cue` plays a one-shot through the engine where its place allows and the
channel starts, else its flat stand-in. `Sound.hold` keeps a loop toward a direction, and `Sound.earcon` plays a flat
sound. `:clamp` keeps a tone inside the flat channel's range. `:glossary` gives the sound's row in the sound glossary
of the configuration menu (`Sound::Glossary`), which plays a sample of each.

## Sound navigation modes

`sound_nav` sets how much plays:

- `:off`: no steps, bumps or soundscape. The scheduler stops before booting the engine. The guides' chimes, the
  minigames' gauge and the puzzle grid still play, flat.
- `:basic`: the engine plays the steps, the bumps and the guides' sounds. The sonar, the water, the winds and the
  shore stay silent (`Scheduler.silence_emitters`).
- `:full`: all of it, the radar included.

Settings that only the engine plays show in the menu only where it can play (`Config.capability(:positional)`).

## The soundscape

`Sound::Scheduler.tick` is the sound stage's one step. On each map frame it does the following, in order:

1. With no map or player, it silences what plays.
2. With the mod off, it stops every channel, the guide's held tone too.
3. With `sound_nav` off, it silences what plays and stops.
4. It boots the engine if it has not tried yet, and plays the game's music again after the first boot. Without a
   ready engine it stops here.
5. While a hold reason applies (`Control.reason(:hold)`), it silences the soundscape and forgets the tile it read
   last, so the loops come back without a step.
6. It sets the master volume, the reach, the channels' tones and the air.
7. In `:basic` it silences the emitters once and stops there.
8. In `:full` it reads the scene and pings (`Scheduler.scan_and_ping`).

The scene is read again on each tile change, except during an ice slide, which is read once where it stops. A
reading takes the emitters, the walls on each side, the winds, the water loop and, afloat, the shore. With the player
still, the emitters are read again when an event that walks changes tile within range, or one comes, goes or changes
there (`Scene.moved?`). `MOVER_GAP` separates two such readings at least.

Each part of the frame runs on its own (`Scheduler.step`): a failure is written once to the marker file and the other
parts go on. `Scheduler.gate` counts why each map frame played or fell silent, and the diagnostic dump prints the count
([Diagnostics](diagnostics.md)).

## Sonar

The sonar pings the emitters near the player. `Sound::Scene.scan` reads them within `audio3d_range` tiles, as
Manhattan distance: events, the player's markers and the map's edge exits, one per connected map
(`Locator.connection_edges`).

`Scene.family_of` gives an event its ping kind. The first rule that matches wins:

1. An event the player or a profile hid does not ping.
2. The player's category from the Ctrl+K menu decides: exits ping as doors, people as people and objects as objects.
   Any other category, such as signs, does not ping.
3. A puzzle piece pings by its role: an obstacle as a hazard, or as a trap when it moves, and a control as a control.
4. A hazard (`:hazard`), a boulder to push (`:push`), a push tile (`:belt`), a teleporter (`:teleporter`) and a
   transfer (`:door`) each have a ping of their own.
5. Any other event needs a graphic and something to do with it. A lever pings as a control, a person as a person
   and the rest as an object.

With `sonar_only_locatable` on, a plain person or object pings only if the locator's lists hold it.

Touching tiles that share a sprite ping once, from the tile nearest the player (`Scene.cluster`). Each kind keeps its
`Scene::NEAR_MAX` nearest emitters.

`audio3d_occlusion` decides what a wall between the player and an emitter does. `:hear` ignores the wall, and
`:occlude` muffles the ping by `Scheduler::OCCLUDE_AMOUNT`. `:hide` drops the emitter from the reading, except a
service desk within `audio3d_desk_range` tiles. The line of sight is a ray stepped along the axis with more distance
left, each step asked of `World::Probe.step?` (`Scene.line_clear?`). It is not a path search.

`Scheduler.ping` plays one ping per map frame at most. Each kind is due once its family's interval has passed
(`Mixer.ping_seconds`). Of the kinds due, the one that has waited longest pings, taking its nearest tiles in turn.
For `PING_GAP` after a ping, a tile within `audio3d_alt_dist` of it waits, so two close sources sound apart. A kind
switched off or at volume 0 takes no turn.

## Water, walls and the shore

- The `:water` loop plays on the nearest water tile within the sonar's range, searched ring by ring
  (`Scene.nearest_water`).
- Four wind loops stand for the walls, one per side (`:wind_n`, `:wind_e`, `:wind_s`, `:wind_w`). Each plays on the
  first closed step within `audio3d_wall_range` on its side. Its volume is divided by the distance raised to
  `audio3d_wall_falloff / 50`.
- While the player surfs, the `:shore` cue plays on the nearest tile they can land on, every `SHORE_PERIOD` at most
  (`Scene.nearest_shore`). The debug setting `revert_surf_sound` turns it off.

## Sounds of the player's moves

`Sound::Feedback.tick` runs in the `:feedback` step with control free:

- A step sounds on each new tile: water while surfing or diving, grass on grass, else the ground. A tile slid on ice
  gives none.
- A bump sounds when the player holds a direction toward a closed step without moving: `:interact` when facing
  something to interact with, else `:wall`. It sounds on the push, on turning to another wall and every
  `bump_cooldown` frames while the push lasts.
- The radar ticks when something to interact with comes right in front of the player, once until that changes. It
  needs `proximity_radar` and full sound navigation, and it reaches across a counter as the engine does.
- The ledge tick sounds when the player comes to face a ledge they can jump. `sound_ledges`, on by default, switches
  it.

The mod's bump replaces the game's own. A `pbSEPlay` hook (`Hooks.wrap_kernel`, `:around`) skips the game's bump
while the mod's bump answers the same push, unless `game_bump` is on (`Feedback.mute_game_bump?`). The game's bump
is the file `bump` in gen-6 and `Player bump` from v18 on ([Engine eras](engine-eras.md)).

## Surface cues

`Surfaces.tick` runs in the `:surfaces` step with control free (`core/nav/surfaces.rb`). With `surface_cues` on, it
says the ground under the player when it changes (`World::Terrain.label`), and "under the bridge" where the player
passes under one. On foot, it also says the water right ahead, once until the tile ahead changes. The water is
surfable where the game would let the player start Surf there. It is plain water on a bike-only map, without a way to
use Surf, or with company the game's Surf refuses.

Whatever the setting, arriving on a Lens of Truth tile says "Hidden area".

## Silence and resets

- Losing control (`:control_lost`) suspends the soundscape at once (`Scheduler.suspend`). The feedback forgets the
  player's tile, so a move the game makes meanwhile gives no step.
- A map change or a load (`Caches.reset_all`) drops what the soundscape, the feedback and the surface cues read of
  the last map, and turns the guides off.
- A change of tags or markers reads the scene again on the next frame (`:tags_changed`).
