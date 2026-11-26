# Tourmaline Desert (maps 694, 703, 704 and 705, four takes on one desert): each holds a light shard (event 69) that
# adds one to variable 359 (back to 0 at the fourth) and sends the player to the same tile of a random take. With 359 at
# 3 the mirage tower shows on the horizon and the north exits lead to the desert with the tower.
module PokeAccess
  module RebornDesert
    MAPS = [694, 703, 704, 705]

    # Shards touched in a row.
    def self.shards
      $game_variables[359].to_i
    end
  end
end

PokeAccess::Game.define("reborn") do
  desert = PokeAccess::RebornDesert
  mechanic(:state, desert::MAPS) do
    auto
    watch :var => 359, :quiet => true
    name 69, :rbf_oasis_shard
    name(/mirage smoller/, :rbf_oasis_tower_sign)
    hide 69, :assist => true, :when => lambda { |_ev| desert.shards >= 3 }
    sent_back :rbf_oasis_shift, :maps => desert::MAPS
    count :rbf_oasis_count, :var => 359, :of => 3, :assist => true, :reset => :rbf_oasis_reset
    phase lambda { PokeAccess::Puzzles.assist? && desert.shards < 3 }, :quiet => true, :hint => :rbf_oasis_touch
    phase lambda { PokeAccess::Puzzles.assist? && desert.shards >= 3 }, :quiet => true, :hint => :rbf_oasis_north
  end
end
