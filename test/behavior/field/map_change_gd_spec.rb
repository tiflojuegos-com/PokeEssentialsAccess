# Map naming on the modern path. This file exists because its absence was itself the bug: map_change_spec
# carries no _gd suffix, so it only ever ran in the gen-6 pass, where the stub happens to define the gen-6
# loader. Locator.map_name asked for pbLoadRxData, which v19+ removed in favour of pbLoadMapInfos, and six
# of the thirteen games have only the latter. The failure is memoised on first use, so those six lost every
# map name for the whole session -- zone, exits, coordinates, renaming -- with the suite fully green.
#
# Any reader resting on an API only one engine ships needs a twin like this, or the green tick means nothing.

Suite.define("field (gamedata): map_name resolves through the modern MapInfos loader") do
  eq "a known id is named without the gen-6 loader", PokeAccess::Locator.map_name(35), "Mapa 35"
  eq "an unknown id still has no name", PokeAccess::Locator.map_name(999999), nil
end

Suite.define("field (gamedata): the map is announced once per change, as in gen-6") do
  $game_map.map_id = 35
  PokeAccess::Locator.forget_map
  10.times { PokeAccess::Locator.announce_map_change }
  spoke_once "same map announced exactly once over 10 frames", /Mapa 35/

  SpeakCapture.clear
  $game_map.map_id = 40
  5.times { PokeAccess::Locator.announce_map_change }
  spoke_once "new map announced once after the id changes", /Mapa 40/
end
