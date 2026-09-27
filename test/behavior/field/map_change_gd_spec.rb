# Map naming in the gamedata pass, which has pbLoadMapInfos and not the gen-6 pbLoadRxData (map_change_spec runs only
# in the gen-6 pass).

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

# A map name goes through the speech cleaner: a \PN control code becomes the player's name.
Suite.define("field: a map name with a control code is spoken cleaned") do
  who = (defined?($player) && $player) ? $player : $Trainer
  eq "the player-name code becomes the player's name", PokeAccess::Locator.map_name(36), "Casa de #{who.name}"
end
