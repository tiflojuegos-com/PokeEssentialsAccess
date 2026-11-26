# The briefcase of Goldenwood Forest (map 50, event 14), opened facing it from below: 6489 gives the Snag Machine
# (variable 325 to 15); 3845 gives an Ability Capsule and then leaves it taking 6489 alone (self switch A). Its first
# page compares the entry with both, so the core says no answer there; once A is on, the core says 6489.
module PokeAccess
  module RejuvBriefcase
    CODE = "6489"

    # True while the briefcase's first page, the one comparing two codes, is the one that runs.
    def self.two_codes?
      $game_variables[325].to_i < 15 && !$game_self_switches[[50, 14, "A"]]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  briefcase = PokeAccess::RejuvBriefcase
  mechanic(:state, 50, :part => :briefcase) do
    auto
    on_use 14, lambda { |_ev| briefcase.two_codes? ? [:puzzle_answer, { :a => briefcase::CODE }] : nil }, :assist => true
  end
end
