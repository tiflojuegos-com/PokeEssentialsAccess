# Larkspur's trap on Route 19's bridge (map 221): the middle plank (event 59, at 19,73) gives way under the player and
# drops them under the water (map 222) each time until variable 117 reaches 7; the first two falls count toward the
# Garlikid sidequest (variable 135). Named once it has given way, or with the assist before; with the assist, walks keep off it while its
# page runs and another way exists (the bridge is the only way to the pocket east of it, so a walk there still crosses).
module PokeAccess
  module UraniumBridgeTrap
    def self.known?
      $game_self_switches[[221, 59, "A"]] || PokeAccess::Puzzles.assist?
    end

    def self.live?
      $game_variables[117].to_i < 7
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 221, :part => :trap) do
    auto
    name 59, lambda { |ev| PokeAccess::UraniumBridgeTrap.known? ? :ura_r3_bridge_trap : nil },
         :when => lambda { |ev| PokeAccess::UraniumBridgeTrap.live? && PokeAccess::UraniumBridgeTrap.known? }
    avoid 59, :assist => true
  end
end
