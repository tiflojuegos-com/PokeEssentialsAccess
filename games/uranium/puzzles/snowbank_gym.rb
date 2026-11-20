# Snowbank Town's gym trials. Map 137 holds the boulder trial (events 17 to 25, west) and the hidden path trial (east):
# a button (events 8 and 38) turns switch 79 on and the path's tiles, events 37 and 40 to 82, flash for a moment; the
# traps around them (83 to 147) send the player back to (67, 62). The acolytes 13, 27 and 34 reset the room or leave the trials.
# Map 141 is the adaptability trial: ice, and a touch tile (event 17) that makes the player jump five tiles to the left and
# step a sixth, with its own acolyte (event 12) to reset or leave.
module PokeAccess
  module UraniumSnowbank
    # The named points of the hidden path's tiles, events 37 and 40 to 82, listed with the assist alone.
    def self.path_spots
      ([37] + (40..82).to_a).map { |id| { :event => id, :label => :ura_pz_vino_way, :onto => true, :assist => true } }
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 137) do
    auto
    name [13, 27, 34], :ura_pz_snow_reset
    name [8, 38], :ura_pz_button
    phase at(0, 20, 52, 70), :title => :ura_pz_snow_rocks_title
    phase at(61, 73, 40, 64), :title => :ura_pz_snow_path_title, :hint => :ura_pz_snow_path_hint,
          :spots => PokeAccess::UraniumSnowbank.path_spots
    sent_back :ura_pz_snow_sent, :to => [67, 62], :events => 83..147
  end

  mechanic(:state, 141) do
    auto
    arrival_hint :ura_pz_snow_ice_rule, :once => true
    name 12, :ura_pz_snow_reset
    name 17, lambda { |ev| PokeAccess::Puzzles.assist? ? :ura_pz_snow_jump_to : :ura_pz_snow_jump }
  end
end
