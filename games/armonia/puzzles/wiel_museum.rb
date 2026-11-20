# Museo Wiel (map 81): a pot with no graphic (event 66) hides a lever, and pulling it opens a hole far off (event 71, by its self
# switch A), the way down to the secret room of map 89. The pot among the others and where the hole opened, which the game only
# hints at, come with the puzzle assist; the hole, once there, is named for what it leads to.
module PokeAccess
  module ArmoniaMuseum
    HOLE = [74, 44]

    # Where the hole opened, from the player.
    def self.hole_line
      dist = PokeAccess::Puzzles.offset_phrase(HOLE[0] - $game_player.x, HOLE[1] - $game_player.y)
      [:arm_wiel_hole_at, { :dist => dist }]
    end
  end
end

PokeAccess::Game.define("armonia") do
  mechanic(:state, 81) do
    auto
    name 66, :arm_wiel_pot, :assist => true
    name 71, :arm_wiel_hole
    on_reach 66, { :choice => 0 }, lambda { PokeAccess::ArmoniaMuseum.hole_line }, :assist => true
  end
end
