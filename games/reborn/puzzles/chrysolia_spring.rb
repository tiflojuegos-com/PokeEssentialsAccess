# Chrysolia Spring (1F map 238, B1F map 545): a geyser throws the player up and over while a boulder plugs its nozzle;
# taking the boulder off shuts it, and a fall or leaving shuts them all. On 1F the boulders on the five nozzles light
# switches 661 to 665; the way on is the hole of event 7 down to B1F, where no boulder reaches a nozzle.
module PokeAccess
  module RebornSpring
    GEYSERS = { 25 => 661, 33 => 662, 34 => 663, 35 => 664, 36 => 665 }
    NOZZLES = [[39, 15], [17, 23], [47, 16], [49, 34], [18, 45]]
    HOLE_DOWN = 7
    HOLE_BOULDER = 6
    FELL = 683
    RETURN_GEYSER = 12

    # A 1F geyser by whether its boulder plugs it.
    def self.label(ev)
      sw = GEYSERS[ev.id]
      sw && $game_switches[sw] ? :rbf_geyser_on : :rbf_geyser_off
    end
  end
end

PokeAccess::Game.define("reborn") do
  spring = PokeAccess::RebornSpring
  assist = lambda { PokeAccess::Puzzles.assist? }
  mechanic(:state, 238, :part => :geysers) do
    auto
    name spring::GEYSERS.keys, lambda { |ev| spring.label(ev) }
    spring::NOZZLES.each { |at| spot :at => at, :label => :rbf_geyser_nozzle, :assist => true }
    arrival_hint :rbf_geyser_rule, :once => true
    phase lambda { assist.call && !$game_switches[spring::FELL] }, :hint => :rbn3_spring_down,
          :hidden => right_way(spring::HOLE_BOULDER, spring::HOLE_DOWN)
    phase lambda { assist.call }, :hint => :rbn3_spring_hole, :hidden => right_way(spring::HOLE_DOWN)
  end
  mechanic(:state, 545, :part => :geysers) do
    auto
    name(/Geyser/, :rbf_geyser)
    arrival_hint :rbf_geyser_rule, :once => true
    phase lambda { assist.call }, :hint => :rbn3_spring_b1, :hidden => right_way(spring::RETURN_GEYSER)
  end
end
