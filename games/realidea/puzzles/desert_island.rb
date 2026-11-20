# The Desert Island and its ruins, on the way to the Radiant Talisman (switch 146). The island (map 149): a photo taken
# with the game's camera (the P key) standing on the flower at (32, 34) turns switch 313 on, and a stair to the ruins
# shows. Its three mossy rocks, whose figure an inscription of the ruins gives to the trap tile, are named by the free
# camera on their tiles and listed among the puzzles. The first ruins (map 150): its slabs are engraved with a triangle, a circle or a square, each named by it; a
# step on terrain 25, the triangles, sends an arrow that halves the party's HP; with the puzzle assist routes keep off
# it and it is named as a trap. The last ruins (map 151): stepping on (9, 99) facing up arms switch 180, and while it is
# on, leaving column 9 sends the player back to (9, 100) with half their HP. The inscriptions of the three maps read
# only with switch 232.
module PokeAccess
  module RealideaIsland
    ISLAND = 149
    TRAP_RUINS = 150
    ARROW_RUINS = 151
    FLOWER = [32, 34]
    STAIRS = 313
    TRAP_TAG = 25
    ISLAND_SIGNS = [1, 11, 12]
    TRAP_SIGNS = [5, 7, 8]
    ARROW_SIGNS = [9, 11, 12]
    ARROW_START = [9, 100]
    SLABS = { 500 => :rea_island_triangle_slab, 501 => :rea_island_circle_slab, 494 => :rea_island_square_slab }
    # The top left tile of each mossy rock of the island, two tiles by two; each is listed by its lower left tile, open
    # below.
    ROCKS = [[29, 20], [15, 39], [44, 39]]

    # True where (x, y) is a tile of a mossy rock of the island.
    def self.rock?(x, y)
      $game_map.map_id == ISLAND && ROCKS.any? { |rx, ry| (x - rx).between?(0, 1) && (y - ry).between?(0, 1) }
    end

    # True where (x, y) is a trap tile of the first ruins.
    def self.trap?(x, y)
      $game_map.map_id == TRAP_RUINS && PokeAccess::World::Terrain.number(x, y) == TRAP_TAG
    end

    # The engraving of the slab on (x, y) of the first ruins, as its label key, or nil off the slabs.
    def self.slab(x, y)
      $game_map.map_id == TRAP_RUINS ? SLABS[$game_map.data[x, y, 1]] : nil
    end

    # The surface label of (x, y) in the first ruins: its engraving, and with the puzzle assist the trap as such.
    def self.label(x, y)
      return :rea_island_trap_tile if PokeAccess::Puzzles.assist? && trap?(x, y)
      slab(x, y)
    end
  end
end

PokeAccess::Game.define("realidea") do
  isle = PokeAccess::RealideaIsland
  assist = lambda { PokeAccess::Puzzles.assist? }

  mechanic(:state, isle::ISLAND) do
    auto
    name isle::ISLAND_SIGNS, :rea_island_inscription
    spot :at => isle::FLOWER, :label => :rea_island_flower, :assist => true, :onto => true
    isle::ROCKS.each { |x, y| spot :at => [x, y + 1], :label => :rea_island_mossy_rock }
    watch :switch => isle::STAIRS, :say => :rea_island_stairs
    active { !$game_switches[isle::STAIRS] && assist.call }
    solved { $game_switches[isle::STAIRS] }
    hint :rea_island_photo_hint
  end

  camera_tile(:maps => [isle::ISLAND], :tiles => lambda { |x, y| isle.rock?(x, y) }) do |_x, _y|
    PokeAccess::I18n.t(:rea_island_mossy_rock)
  end

  terrain_rule(:tags => [isle::TRAP_TAG], :assist => true) { |x, y, _d| isle.trap?(x, y) ? false : nil }
  PokeAccess::World::Terrain.label_rule { |x, y| isle.label(x, y) }
  mechanic(:state, isle::TRAP_RUINS) do
    auto
    name isle::TRAP_SIGNS, :rea_island_inscription
  end

  mechanic(:state, isle::ARROW_RUINS) do
    auto
    name isle::ARROW_SIGNS, :rea_island_inscription
    sent_back :rea_island_column_back, :to => isle::ARROW_START
    active { !$game_switches[146] && assist.call }
    solved { $game_switches[146] }
    hint :rea_island_column_hint
  end
end
