# Palacio del Gran Sol: fountains with no sprite ask to look into their reflection, and each first look adds 1 to var 117
# and turns on one of its own self switches, the scene told by how far the count has gone. The ground floor's three
# (map 134) bring a chest at 3 that opens the way up; the second floor's two (map 155), live from 3, bring another
# chest at 5.
module PokeAccess
  module RevivalPalace
    # Map => [its fountains, the count var 117 reaches once all are looked into].
    FOUNTAINS = { 134 => [[35, 36, 37], 3], 155 => [[4, 9], 5] }

    # Whether the player has looked into a fountain of this map already.
    def self.looked?(ev)
      %w[A B C].any? { |letter| $game_self_switches[[$game_map.map_id, ev.id, letter]] }
    end
  end
end

PokeAccess::Game.define("revival") do
  palace = PokeAccess::RevivalPalace
  palace::FOUNTAINS.each do |map, (fountains, done_at)|
    mechanic(:state, map) do
      auto
      name fountains, :rv_palace_fountain, :when => lambda { |ev| !palace.looked?(ev) }
      hint(map == 134 ? :rv_palace_hint_ground : :rv_palace_hint_top)
      solved { $game_variables[117] >= done_at }
    end
  end
end
