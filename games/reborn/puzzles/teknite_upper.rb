# Teknite Cave 3F (map 640, 648 with crystals) and 3-4F (645, 649): a wild battle leaving the Crystal Cavern field
# (Power Gem) turns the floor into its crystal take, Earthquake back. On 3F the red crystal of event 8 (23,27), used
# from anywhere but below, sets switch 845 and breaks the rock at (22,19) (846).
module PokeAccess
  module RebornTekniteUpper
    ROCK_WORDS = { 1 => :rbf_teknite_reacted, 2 => :rbf_teknite_cracked, 3 => :rbf_teknite_open }
    EDGES = { 645 => [6, 7, 8, 9, 10, 11, 12, 13, 26, 27, 28, 29, 30, 31, 32],
              649 => [6, 7, 8, 9, 10, 11, 12, 13, 27, 28, 29, 30, 31, 32, 33] }

    # The stairs rock's state, variable 376, set to 1 by the red crystal of event 7 (23,10): the rock at (24,9) breaks
    # with Rock Smash at once in 648, twice in 640; at 3 it is the stairs up.
    def self.stairs; $game_variables[376].to_i; end

    # True with the rock at (22,19) broken.
    def self.side_open?; $game_switches[846] ? true : false; end

    # True in the pocket by the stairs rock, which the crystals of 648 cut off from the rest of the floor.
    def self.by_stairs?; $game_player.y <= 12 && $game_player.x >= 21; end

    # The assist's step on 3F, by the floor shown, the two rocks and where the player stands; the field goes back to the
    # cave to walk up, and to crystals again by the stairs.
    def self.hint(crystals)
      return :rbk_tk3_hint_smash if stairs >= 1
      if crystals
        return :rbk_tk3_hint_stairs_crystal if by_stairs?
        return :rbk_tk3_hint_quake if side_open?
        return $game_switches[845] ? :rbk_tk3_hint_side_rock : :rbk_tk3_hint_side_crystal
      end
      return :rbk_tk3_hint_gem unless side_open?
      by_stairs? ? :rbk_tk3_hint_gem_here : :rbk_tk3_hint_north
    end

    # The assist's step on 3-4F: the crystals, the blue crystal of event 5 (24,28) used facing it from any side (the
    # river's current carries the player south), then the bridge (switch 849) to the stairs on the west bank.
    def self.river_hint(crystals)
      return :rbk_tk34_hint_bridge if $game_switches[849]
      crystals ? :rbk_tk34_hint_crystal : :rbk_tk34_hint_gem
    end
  end
end

PokeAccess::Game.define("reborn") do
  upper = PokeAccess::RebornTekniteUpper
  [[640, false], [648, true]].each do |map, crystals|
    mechanic(:state, map, :part => :stairs) do
      auto
      watch :var => 376, :label => :rbf_teknite_rock, :words => upper::ROCK_WORDS
      if crystals
        watch :switch => 845, :label => :rbk_tk3_side_rock, :on => :rbf_teknite_reacted, :off => :rbk_tk3_whole
        name [7, 8], :rbf_teknite_crystal
      end
      hint lambda { upper.hint(crystals) }
      solved(nil, :quiet => true) { upper.stairs >= 3 }
    end
  end
  [[645, false], [649, true]].each do |map, crystals|
    mechanic(:state, map, :part => :river) do
      auto
      watch :switch => 849, :label => :rbk_tk34_bridge, :on => :rbk_tk34_bridge_on, :off => :rbk_tk34_bridge_off
      name 5, :rbk_tk34_blue_crystal if crystals
      not_control upper::EDGES[map]
      arrival_hint :rbk_tk34_current_rule, :once => true
      hint lambda { upper.river_hint(crystals) }
    end
  end
end
