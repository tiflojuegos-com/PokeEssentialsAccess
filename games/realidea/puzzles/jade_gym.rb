# The coloured floor of Jade City's gym (map 114): pink, blue, green, yellow, red and white tiles, each named by its
# colour. Terrain 29, a clear tile over those not of the colours of the Pokémon whose cry a zone plays, gives a status to
# a Pokémon of the party; with the puzzle assist routes keep off it and it is named as what it does.
module PokeAccess
  module RealideaJadeFloor
    MAP = 114
    TAG = 29
    COLOURS = { 844 => :rea_jade_pink_tile, 845 => :rea_jade_blue_tile, 846 => :rea_jade_green_tile,
                847 => :rea_jade_yellow_tile, 852 => :rea_jade_red_tile, 854 => :rea_jade_white_tile }

    # True where (x, y) is floor that gives a status.
    def self.wrong?(x, y)
      $game_map.map_id == MAP && PokeAccess::World::Terrain.number(x, y) == TAG
    end

    # The colour of the tile on (x, y) of the gym, as its label key, or nil off the coloured floor.
    def self.colour(x, y)
      $game_map.map_id == MAP ? COLOURS[$game_map.data[x, y, 0]] : nil
    end

    # The surface label of (x, y): its colour, and with the puzzle assist the floor that gives a status as such.
    def self.label(x, y)
      return :rea_jade_wrong_tile if PokeAccess::Puzzles.assist? && wrong?(x, y)
      colour(x, y)
    end
  end
end

PokeAccess::Game.define("realidea") do
  floor = PokeAccess::RealideaJadeFloor
  terrain_rule(:tags => [floor::TAG], :assist => true) { |x, y, _d| floor.wrong?(x, y) ? false : nil }
  PokeAccess::World::Terrain.label_rule { |x, y| floor.label(x, y) }
end
