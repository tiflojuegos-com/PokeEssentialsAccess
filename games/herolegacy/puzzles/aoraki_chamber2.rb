# Mt. Aoraki, chamber 2 (map 361, the floor below is 364): five Strength boulders each go down their own hole, and a
# parallel event per hole turns its switch on (162 to 166) and shows the boulder below, where the floor is ice and a
# fallen boulder stops a slide. A sixth boulder on (24, 12) turns switch 167 on and breaks three ice blocks. The engine
# keeps a pushed event off ice, so boulders only move over rock. Frigometri (map 364, 21, 8) ends the chamber
# (switch 145); the boulders of switches 162, 163, 164 and 166 have to be below to reach him.
module PokeAccess
  module HeroLegacyHoleChamber
    # Each boulder, where it starts, the tile it goes to, its switch and its hint, in an order whose every push plan was
    # found against the map: the fifth boulder is reached from the ladders of the floor below, the sixth once the fifth
    # is down.
    STEPS = [[4, [13, 7], [14, 7], 162, :hl_q2_hole], [8, [26, 6], [25, 6], 163, :hl_q2_hole],
             [32, [29, 16], [29, 17], 165, :hl_q2_hole], [25, [27, 12], [24, 12], 167, :hl_q2_crack],
             [28, [22, 23], [15, 17], 164, :hl_q2_far], [18, [21, 10], [23, 16], 166, :hl_q2_hole]]
    BELOW = [162, 163, 164, 166]
    FALLEN = [5, 8, 10, 11, 13]

    # True once the boulders that reach Frigometri are down.
    def self.below_ready?
      BELOW.all? { |sw| $game_switches[sw] }
    end
  end
end

PokeAccess::Game.define("herolegacy") do
  chamber = PokeAccess::HeroLegacyHoleChamber
  frigometri = lambda { PokeAccess::Data.species_name(:CRYOGONAL).to_s }
  mechanic(:state, 361) do
    auto
    name(/\AHole\z/, :hl_hole)
    name(/\AEisblock/, :hl_ice_block)
    chamber::STEPS.each do |step|
      ev, from, goal, sw, key = step
      phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[sw] && !$game_switches[145] }, :quiet => true,
            :hint => [key, { :x => from[0], :y => from[1], :gx => goal[0], :gy => goal[1] }],
            :track => { :event => ev, :label => :hl_boulder, :goal => [goal[0], goal[1], goal[0], goal[1]],
                        :goal_label => sw == 167 ? :hl_switch_tile : :hl_hole }
    end
    arrival_hint :hl_q2_rule
    solved { $game_switches[145] }
  end

  mechanic(:state, 364) do
    auto
    name chamber::FALLEN, :hl_fallen_boulder
    arrival_hint :hl_q2_below_rule
    phase lambda { !$game_switches[145] }, :quiet => true,
          :hint => lambda {
            [chamber.below_ready? ? :hl_q2_below_ready : :hl_q2_below_missing, { :name => frigometri.call }]
          }
    solved { $game_switches[145] }
  end
end
