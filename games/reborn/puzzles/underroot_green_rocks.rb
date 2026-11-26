# The Underroot (map 153), the way to Axew's egg: three green rocks, action events with no graphic (62 at (65, 57) for
# switch 1791, 78 at (74, 60) for 1792, 79 at (79, 53) for 1793), answer a Crystal Key by lighting five crystals each so
# Rock Smash breaks them; trees for Cut stand behind, each cut drawing a vine back (variable 658).
module PokeAccess
  module RebornUnderrootGreenRocks
    MAP = 153
    GREEN = { 62 => 1791, 78 => 1792, 79 => 1793 }
    CRYSTALS = { 1791 => (63..67).to_a, 1792 => (68..72).to_a, 1793 => (73..77).to_a }
    VINES = (53..57).to_a + (59..61).to_a + (81..86).to_a + (88..91).to_a + (93..96).to_a
    CUTS = 658
    EGG = 127
    PLATE = 131

    # True once a crystal's green rock is lit, so Rock Smash breaks it.
    def self.lit?(ev)
      sw = CRYSTALS.keys.find { |s| CRYSTALS[s].include?(ev.id) }
      sw && $game_switches[sw]
    end

    # How many of the four trees on the way are cut, by the count the last one cut leaves.
    def self.cuts
      $game_variables[CUTS].to_i
    end

    # True once the egg is taken.
    def self.done?
      $game_self_switches[[MAP, EGG, "A"]]
    end

    # True while the way can be followed, with the assist: a Crystal Key the green rocks answer in the bag, or one lit.
    def self.on?
      return false unless PokeAccess::Puzzles.assist?
      GREEN.values.any? { |sw| $game_switches[sw] } ||
        [2, 3, 4].any? { |n| ($PokemonBag.pbQuantity("CRYSTALPLUG#{n}".to_sym) rescue 0).to_i > 0 }
    end
  end
end

PokeAccess::Game.define("reborn") do
  gr = PokeAccess::RebornUnderrootGreenRocks
  lit = lambda { |sw| $game_switches[sw] }
  mechanic(:state, gr::MAP, :part => :green_rocks) do
    auto
    name gr::GREEN.keys, lambda { |ev| $game_switches[gr::GREEN[ev.id]] ? nil : :rbj_ur_green_rock },
         :when => lambda { |ev| !$game_switches[gr::GREEN[ev.id]] }
    name gr::CRYSTALS.values.flatten, lambda { |ev| gr.lit?(ev) ? :rbj_ur_crystal_lit : :rbj_ur_crystal }
    name gr::VINES, :rbj_ur_vine, :grouped => true
    gr::GREEN.values.each { |sw| watch :switch => sw, :say => :rbj_ur_crystals_lit }
    phase(lambda { gr.on? && !lit.call(1791) }, :quiet => true, :hint => :rbj_ur_gr_first, :hidden => right_way(62))
    phase(lambda { gr.on? && gr.cuts < 6 }, :quiet => true, :hint => :rbj_ur_gr_tree, :hidden => right_way(65, 80))
    phase(lambda { gr.on? && !lit.call(1792) }, :quiet => true, :hint => :rbj_ur_gr_next, :hidden => right_way(78))
    phase(lambda { gr.on? && gr.cuts < 10 }, :quiet => true, :hint => :rbj_ur_gr_tree, :hidden => right_way(72, 87))
    phase(lambda { gr.on? && gr.cuts < 14 }, :quiet => true, :hint => :rbj_ur_gr_tree, :hidden => right_way(92))
    phase(lambda { gr.on? && !lit.call(1793) }, :quiet => true, :hint => :rbj_ur_gr_next, :hidden => right_way(79))
    phase(lambda { gr.on? && gr.cuts < 15 }, :quiet => true, :hint => :rbj_ur_gr_east, :hidden => right_way(77, 58))
    phase(lambda { gr.on? && gr.cuts >= 15 }, :quiet => true, :hint => :rbj_ur_gr_egg,
          :hidden => right_way(gr::EGG, gr::PLATE))
    solved(nil, :quiet => true) { gr.done? }
  end
end
