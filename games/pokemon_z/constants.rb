# Pokemon Z 2.18 profile: only what differs from core/foundation/config.rb. Everything generic (keys,
# categories, volumes, astar_max, status/weather tables) lives in core, so a per-game file cannot shadow
# it with stale values. Expressed through the adapter API (PokeAccess::Game).
PokeAccess::Game.define("pokemon_z") do
  # Per-game button relabels for the remap menu (Z maps X/Y/Z to its field actions); added to the core
  # defaults, never replacing them.
  button_labels :x => "Pokevial", :y => "PokeRider", :z => "DexNav"

  # The gym beam puzzle uses beam sprites as impassable barriers, caught as a family rather than listed one
  # by one. Registered as a hazard so they read as "beam" (not a generic npc) and the positional audio gives
  # them the zap cue.
  #
  # rayosLegend is excluded by name: it shares the prefix but it is the graphic of the legendary encounter
  # events, which are not barriers and are not something to walk around -- announcing one as a beam, with the
  # zap cue, would send the player away from the thing they came for.
  hazard(/rayos(?!Legend)/i, :loc_beam)

  # Z adds two statuses past the vanilla five, so a Pokemon carrying either had no condition spoken at all.
  # The ids are the game's own, from its PBStatuses; the capitalised wording is this file's, since the game
  # writes them lowercase.
  names(:status_names, 6 => "Caduco", 7 => "Hemorragia")
end
