# Reminiscencia's dungeon rooms ($dungeon_maps) have no exit events: stepping onto a border opens the next room
# (Events.onStepTaken, 2450 Map Scroll.rb:598). The edges are the sides whose room pbSetTeleports set (-1 for none),
# except the one the party came in by.
PokeAccess::Game.define("reminiscencia") do
  script_edges do |id|
    g = $PokemonGlobal
    next nil unless g && ($dungeon_maps || []).include?(id)
    rooms = { 4 => g.leftMap, 6 => g.rightMap, 8 => g.topMap, 2 => g.bottomMap }
    rooms.keys.reject { |way| rooms[way].nil? || rooms[way] == -1 || g.lastDir == 10 - way }
  end
end
