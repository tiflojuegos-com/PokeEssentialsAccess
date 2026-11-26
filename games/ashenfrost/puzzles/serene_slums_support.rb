# Serene Slums support: the Innovative Business hipster (map 680, event 45) takes four donations of at least 1, (self
# switches A to D), and runs off with the fourth (variable 268 to 1). A woman (map 679, event 59) points at the door
# blocked by stairs (268 to 2); stepping on it (map 680, event 47, no graphic) gives an Ability Capsule (268 to 3).
module PokeAccess
  module AshenSupport
    INTERIORS = 680
    SLUMS = 679

    # Where the quest stands, variable 268.
    def self.stage
      $game_variables[268].to_i
    end

    # The donations the hipster took so far.
    def self.donations
      %w[A B C D].select { |l| $game_self_switches[[INTERIORS, 45, l]] }.length
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  su = PokeAccess::AshenSupport
  assist = lambda { PokeAccess::Puzzles.assist? }
  mechanic(:state, su::INTERIORS, :part => :support) do
    auto
    name 47, :afg_su_door
    phase lambda { assist.call && su.stage == 0 && su.donations > 0 },
          :hint => lambda { [:afg_su_donate, { :n => su.donations }] }, :spots => [{ :event => 45, :label => :afg_su_hipster }]
    phase lambda { assist.call && su.stage == 1 }, :hint => :afg_su_woman
    phase lambda { assist.call && su.stage == 2 }, :hint => :afg_su_step, :spots => [{ :event => 47, :label => :afg_su_door }]
    solved(nil, :quiet => true) { su.stage >= 3 }
  end
  mechanic(:state, su::SLUMS, :part => :support) do
    auto
    phase lambda { assist.call && su.stage == 1 }, :hint => :afg_su_woman, :spots => [{ :event => 59, :label => :afg_su_lady }]
    phase lambda { assist.call && su.stage == 2 }, :hint => :afg_su_step
    solved(nil, :quiet => true) { su.stage >= 3 }
  end
end
