# The fires Ryland asks to put out (variable 837, "FlameCount"): on Route 9 (map 273), Sheridan (38), Terajuma (46) and
# the District of Hope (650), each fire walked into goes out and adds one if a party Pokemon knows a Water move, and
# burns and sends the player back if none does. Ryland (map 650, event 16) joins at 40, setting switch 1917.
module PokeAccess
  module RejuvRylandFires
    MAPS = [38, 46, 273, 650]
    NEEDED = 40

    # The fires out so far, no more than Ryland asks for.
    def self.out
      [$game_variables[837].to_i, NEEDED].min
    end

    # True while a fire burns, as the game draws it.
    def self.burning?(ev)
      !ev.character_name.to_s.empty?
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  fires = PokeAccess::RejuvRylandFires
  mechanic(:state, fires::MAPS, :part => :fires) do
    auto
    name(/\Afire\z/i, :rjg_fl_fire, :when => lambda { |ev| fires.burning?(ev) })
    count :rjg_fl_count, :value => lambda { fires.out }, :of => fires::NEEDED, :hide_zero => true, :assist => true
    active { PokeAccess::Puzzles.assist? && !$game_switches[1917] }
    hint :rjg_fl_hint
  end
end
