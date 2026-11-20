# The crystals of Meteor Falls (map 434): eight crystals, each counting its touches in a variable (V74 to V81) from 0 to
# 7 and back to 0, the count drawn on it. A parallel event (EV16) opens the way to Meteor Village (switch 185) once they
# read red 3, green 4, yellow 2, grey 0, dark blue 5, ocean blue 2, sky blue 1 and pink 6.
module PokeAccess
  module SeviiMeteorFalls
    MAP = 434
    # Event => [variable, colour, count asked].
    CRYSTALS = { 1 => [74, :sevii_crystal_red, 3], 2 => [75, :sevii_crystal_green, 4], 3 => [76, :sevii_crystal_yellow, 2],
                 4 => [77, :sevii_crystal_grey, 0], 5 => [78, :sevii_crystal_dark_blue, 5],
                 8 => [79, :sevii_crystal_ocean_blue, 2], 6 => [80, :sevii_crystal_sky_blue, 1],
                 7 => [81, :sevii_crystal_pink, 6] }

    # The assisted line: each crystal off its count with how many more touches it needs, a touch past 7 wrapping to 0.
    def self.hint
      off = CRYSTALS.keys.sort.map do |ev|
        var, colour, want = CRYSTALS[ev]
        have = $game_variables[var].to_i
        next nil if have == want
        [:sevii_crystal_touches, { :crystal => PokeAccess::I18n.t(colour), :n => (want - have) % 8 }]
      end.compact
      return :sevii_crystals_set if off.empty?
      [:sevii_crystals_hint, { :list => off.map { |k, v| PokeAccess::I18n.t(k, v) }.join(", ") }]
    end
  end
end

PokeAccess::Game.define("sevii") do
  falls = PokeAccess::SeviiMeteorFalls

  mechanic(:state, falls::MAP) do
    auto
    falls::CRYSTALS.each do |ev, spec|
      name ev, spec[1]
      watch :var => spec[0], :label => spec[1], :number => true, :from => 0
    end
    hint lambda { falls.hint }
    solved(nil, :quiet => true) { $game_switches[185] }
  end
end
