# Mount Combretum's turning rooms (maps 46, 47, 50, 54 and 55). The story goes on in the east room of map 55 (the fight
# that sets variable 130 to 6), reached only through the passage at (42, 2) of map 47 with switch 78 on. The glow of
# the wall inscriptions at (6, 5) of map 55 toggles 78, and its room is reached only from the west of map 46: with the
# lever of map 47 (switch 71) the passage leads to the part of map 50 whose glow at (37, 8) drops the player into map 54
# (variable 131 to 3), whose way out at (21, 29) comes up there. With 131 at 3, walking right from (13, 22) of map 46
# into (14, 22) jumps back east, toward (37, 16) and map 47. The glow is named; with the puzzle assist, before
# that fight, each map says its step of the way.
module PokeAccess
  module AwakeningCombretum
    # Map 46's west part, where the inscriptions' room opens.
    WEST = [4, 13, 7, 28]

    # True with the puzzle assist between the mountain's opening (variable 130 at 4, map 100's sealed door) and the fight
    # that moves the story on.
    def self.ahead?
      v = $game_variables[130].to_i
      PokeAccess::Puzzles.assist? && v >= 4 && v < 6
    end

    # True while the inscriptions still point the passage elsewhere.
    def self.unturned?; !$game_switches[78]; end

    # True on map 46's west part.
    def self.west?
      x0, x1, y0, y1 = WEST
      p = $game_player
      p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1
    end

    # Map 47's step: the way in once turned, else the lever first, else the drop toward the inscriptions.
    def self.lever_room_hint
      return :awk_comb_exit_hint unless unturned?
      $game_switches[71] ? :awk_comb_glow_far : :awk_comb_lever_hint
    end
  end
end

PokeAccess::Game.define("awakening") do
  comb = PokeAccess::AwakeningCombretum

  mechanic(:state, 47, :part => :glow) do
    auto
    phase lambda { comb.ahead? }, :quiet => true, :hint => lambda { comb.lever_room_hint }
  end

  mechanic(:state, 50, :part => :glow) do
    auto
    phase lambda { comb.ahead? && comb.unturned? && $game_variables[131].to_i < 3 }, :quiet => true,
          :hint => lambda { $game_switches[71] ? :awk_comb_fall_hint : :awk_comb_lever_first }
  end

  mechanic(:state, 54, :part => :glow) do
    auto
    phase lambda { comb.ahead? && comb.unturned? }, :quiet => true, :hint => :awk_comb_up_hint
  end

  mechanic(:state, 46, :part => :glow) do
    auto
    phase lambda { comb.ahead? && comb.unturned? && comb.west? }, :quiet => true, :hint => :awk_comb_west_hint
    phase lambda { comb.ahead? && !comb.unturned? && comb.west? }, :quiet => true, :hint => :awk_comb_back_hint
    phase lambda { comb.ahead? && !comb.unturned? }, :quiet => true, :hint => :awk_comb_east_hint
  end

  mechanic(:state, 55, :part => :glow) do
    auto
    name 1, :awk_wall_glow
    phase lambda { comb.ahead? && comb.unturned? && $game_player.x < 20 }, :quiet => true,
          :hint => :awk_comb_glow_hint
  end
end
