module PokeAccess
  # Insurgence's water. Its Game_Map#passable? lets a surfer onto water only on the tile it stands on or faces, so the
  # probe asks it from the tile it asks from, facing the way it asks (World::Probe.place_player_when); still water
  # (tag 6) is sludge while the map's autotile slot for it is named "slime", until Seed Flare turns it to water.
  module InsurgenceWater
    # The autotile slot that holds sludge, by the tileset name the game checks.
    SLIME_SLOTS = { "ins_outside" => 6, "interior_main" => 0, "ins_black" => 1, "DeepSeaBase" => 4 }
    # PBTerrain::StillWater.
    STILL_WATER = 6

    # True while this map's sludge slot still holds sludge.
    def self.sludge_map?
      i = SLIME_SLOTS[($game_map.tileset_name rescue nil).to_s]
      !i.nil? && ($game_map.autotile_names[i] rescue nil).to_s == "slime"
    end

    # True where the game offers Surf on still water: a map whose sludge slot Seed Flare has turned to water
    # (pbSlimeCheck).
    def self.cleaned_map?
      i = SLIME_SLOTS[($game_map.tileset_name rescue nil).to_s]
      !i.nil? && ($game_map.autotile_names[i] rescue nil).to_s != "slime"
    end

    # True for a sludge tile: still water on a map whose slot is still sludge.
    def self.sludge_at?(x, y)
      sludge_map? && PokeAccess::World::Terrain.number(x, y) == STILL_WATER
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

# With Mode 7 off for good (hm7.rb), the passability reads nothing else an event sets, so an event's end keeps the
# probe's answers.
PokeAccess::Game.define("insurgence") do
  PokeAccess::World::Probe.place_player_when { ($PokemonGlobal.surfing rescue false) ? true : false }
  plain_passability
  PokeAccess::World::Terrain.label_rule { |x, y| PokeAccess::InsurgenceWater.sludge_at?(x, y) ? :ins_surf_sludge : nil }
  PokeAccess::World::Terrain.surf_rule do |n|
    n == PokeAccess::InsurgenceWater::STILL_WATER && PokeAccess::InsurgenceWater.cleaned_map?
  end
end
