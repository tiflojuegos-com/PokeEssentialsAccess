# The map name is announced once per map change, and again only when the map id changes.
Suite.define("field: map name announced once per map, not spammed") do
  $game_map.map_id = 35
  PokeAccess::Locator.forget_map
  10.times { PokeAccess::Locator.announce_map_change }
  spoke_once "same map announced exactly once over 10 frames", /Mapa 35/

  SpeakCapture.clear
  $game_map.map_id = 40
  5.times { PokeAccess::Locator.announce_map_change }
  spoke_once "new map announced once after the id changes", /Mapa 40/
end

# map_name of an id with no MapInfos row and no saved override is nil.
Suite.define("field: map_name of an unknown id falls back to nil") do
  eq "unknown map id has no name", PokeAccess::Locator.map_name(999999), nil
  eq "a known id still resolves from MapInfos", PokeAccess::Locator.map_name(35), "Mapa 35"
end

# A load onto the same map id is announced and resets every cache through announce -> :map_changed ->
# Caches.reset_all, with no load screen involved: a new $game_map object is what marks a load.
Suite.define("field: loading re-announces even on the same map") do
  PokeAccess::Locator.forget_map
  $game_map.map_id = 35
  PokeAccess::Locator.announce_map_change
  spoke "map announced on entry", /Mapa 35/

  SpeakCapture.clear
  3.times { PokeAccess::Locator.announce_map_change }
  silent "standing still on it says nothing more"

  SpeakCapture.clear
  reset_runs = 0
  PokeAccess::Caches.register(:spec_load_probe) { reset_runs += 1 }
  begin
    $game_map = $game_map.dup
    PokeAccess::Locator.announce_map_change
    spoke "a rebuilt $game_map on the same id is a load, and it is announced", /Mapa 35/
    eq "and every cache was reset with it", reset_runs, 1
    SpeakCapture.clear
    PokeAccess::Locator.announce_map_change
    silent "the frame after the load is quiet again"
    eq "and nothing was reset a second time", reset_runs, 1
  ensure
    PokeAccess::Caches.register(:spec_load_probe) { }
  end

  SpeakCapture.clear
  PokeAccess::Locator.forget_map
  PokeAccess::Locator.announce_map_change
  spoke "forget_map still works for the classic screens that call it", /Mapa 35/
end

# A map name goes through the speech cleaner: a \PN control code becomes the player's name.
Suite.define("field: a map name with a control code is spoken cleaned") do
  who = (defined?($player) && $player) ? $player : $Trainer
  eq "the player-name code becomes the player's name", PokeAccess::Locator.map_name(36), "Casa de #{who.name}"
end
