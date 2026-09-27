module PokeAccess
  # Insurgence's water. Its Game_Map#passable? lets a surfing player onto water only on the tile it stands on and the
  # one it faces (009_Game_Map_.rb), so asked about any other water tile it answers wall and no route is found afloat:
  # the route search asks it as if the player stood on the tile it asks from, facing the way it asks. And its still
  # water (tag 6) is sludge while the map's autotile slot for it is named "slime", until Seed Flare turns that slot to
  # water for the visit (useShayminAbility and pbSlimeCheck, 179_ChallengeChampionship.rb).
  module InsurgenceWater
    # The autotile slot that holds sludge, by the tileset name the game checks.
    SLIME_SLOTS = { "ins_outside" => 6, "interior_main" => 0, "ins_black" => 1, "DeepSeaBase" => 4 }
    # PBTerrain::StillWater.
    STILL_WATER = 6

    # Runs the block with the surfing player placed on (x, y) facing d, put back afterwards whatever happens; on foot,
    # or already there, the block runs as it is. Answers the block's value.
    def self.as_if_at(x, y, d)
      pl = $game_player
      return yield if pl.nil? || !($PokemonGlobal.surfing rescue false)
      was = [pl.x, pl.y, pl.direction]
      return yield if was == [x, y, d]
      begin
        pl.x = x
        pl.y = y
        pl.direction = d
        yield
      ensure
        pl.x = was[0]
        pl.y = was[1]
        pl.direction = was[2]
      end
    end

    # True while this map's sludge slot still holds sludge.
    def self.sludge_map?
      i = SLIME_SLOTS[($game_map.tileset_name rescue nil).to_s]
      !i.nil? && ($game_map.autotile_names[i] rescue nil).to_s == "slime"
    end

    # True for a sludge tile: still water on a map whose slot is still sludge.
    def self.sludge_at?(x, y)
      sludge_map? && PokeAccess::Terrain.number_at(x, y) == STILL_WATER
    rescue StandardError
      false
    end
  end
end

PokeAccess::Game.define("insurgence") do
  override("PokeAccess::Pathfinder", :player_passable?) do |_mod, original, args|
    PokeAccess::InsurgenceWater.as_if_at(args[0], args[1], args[2]) { original.call }
  end
  override("PokeAccess::Terrain", :label) do |_mod, original, args|
    PokeAccess::InsurgenceWater.sludge_at?(args[0], args[1]) ? :ins_surf_sludge : original.call
  end
end
