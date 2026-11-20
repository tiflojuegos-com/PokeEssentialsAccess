# Perseida's Regi chambers, rooms behind a door the Dark Gem shows (Mina Sculpta, map 62; Cueva del Lago, map 22;
# Caverna Castigo, map 154): seven hidden tiles each light up once stepped on, adding one to the chamber's variable, and
# with seven its Regi shows up to fight. The variable goes to 10 once the Regi is caught.
module PokeAccess
  module PerseidaRegi
    TILES = 7
    CHAMBERS = {
      62 => [79, [14, 22, 25, 28, 29, 30, 31], [2, 10, 4, 13], 379],
      22 => [78, [3, 9, 10, 11, 12, 13, 14], [3, 11, 39, 47], 378],
      154 => [81, [42, 43, 44, 45, 46, 47, 48], [47, 57, 49, 57], 894]
    }

    # How many of a chamber's tiles are lit, up to seven.
    def self.lit(map)
      [$game_variables[CHAMBERS[map][0]].to_i, TILES].min
    end

    # True once a tile has been stepped on and shows lit.
    def self.lit?(map, ev)
      $game_self_switches[[map, ev.id, "A"]] ? true : false
    end

    # A tile's name: lit, or with the assist one still to step on; nil leaves it unnamed.
    def self.tile_label(map, ev)
      return :perseida_regi_tile_lit if lit?(map, ev)
      PokeAccess::Puzzles.assist? ? :perseida_regi_tile_hidden : nil
    end

    # True while a tile is listed: lit, or with the assist.
    def self.tile_listed?(map, ev)
      lit?(map, ev) || PokeAccess::Puzzles.assist?
    end

    # The line as a tile lights up, nothing once the Regi is caught.
    def self.step_line(map)
      $game_variables[CHAMBERS[map][0]].to_i <= TILES ? :perseida_regi_step : ""
    end

    # True while the player stands in the chamber and its tiles are not all lit.
    def self.inside?(map)
      x0, x1, y0, y1 = CHAMBERS[map][2]
      px = $game_player.x
      py = $game_player.y
      lit(map) < TILES && px >= x0 && px <= x1 && py >= y0 && py <= y1
    end
  end
end

PokeAccess::Game.define("perseida") do
  regi = PokeAccess::PerseidaRegi
  regi::CHAMBERS.each do |map, row|
    species = row[3]
    mechanic(:state, map, :part => :regi) do
      auto
      watch :var => row[0], :say => lambda { regi.step_line(map) }
      name row[1], lambda { |ev| lambda { regi.tile_label(map, ev) } }, :when => lambda { |ev| regi.tile_listed?(map, ev) }
      count :perseida_regi_tiles, :value => lambda { regi.lit(map) }, :of => regi::TILES, :assist => true
      phase lambda { regi.inside?(map) }, :quiet => true,
            :title => lambda { PokeAccess::Puzzles.assist? ? "" : [:perseida_regi_title, { :n => regi.lit(map) }] },
            :hint => lambda { [:perseida_regi_hint, { :species => PokeAccess::Data.species_name(species) }] }
      solved { regi.lit(map) >= regi::TILES }
    end
  end
end
