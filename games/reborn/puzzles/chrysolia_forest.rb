# Chrysolia Forest (map 234): touch tiles with no sprite set variable 145 to a value of their own and the trees fade by
# it. The way to Spinel Town (the exits of events 10 and 52, north-east) takes it from 0 to 8 tile by tile, an earlier
# tile setting it back. With the assist the next tile is listed and the walks keep off the others.
module PokeAccess
  module RebornChrysolia
    TILES = [21, 22, 23, 24, 26, 28, 86, 87, 88, 89, 120, 121, 123, 124, 133, 134, 135, 136, 173, 174, 177, 178,
             217, 218, 219, 220]
    NEXT = [88, 28, 135, 26, 219, 178, 123, 174]

    # The forest's state, variable 145.
    def self.value; $game_variables[145].to_i; end

    # True once the way out is open.
    def self.open?; value >= NEXT.length; end
  end
end

PokeAccess::Game.define("reborn") do
  forest = PokeAccess::RebornChrysolia
  mechanic(:state, 234) do
    auto
    not_control forest::TILES
    avoid forest::TILES, :assist => true
    watch :var => 145, :say => :rba_cf_changed
    forest::NEXT.each_with_index do |id, v|
      spot :event => id, :label => :rba_cf_next, :assist => true, :onto => true, :when => lambda { forest.value == v }
    end
    hint :rba_cf_hint
    active { !forest.open? }
    solved { forest.open? }
  end
end
