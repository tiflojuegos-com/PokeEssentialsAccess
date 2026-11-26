# The Strange House (map 560): the hook 19 at (32,14) takes the family portrait at stage 8 of the quest (variable 588)
# with the portrait in the bag; hung, the way up opens and 588 goes to 9 and 10, and page 2 draws it. Pages 3 and 4
# follow the Sprigacocoly quest (932): at 9 Venam takes the painting down and the empty hook takes it again.
module PokeAccess
  module RejuvStrangeHouse
    # True while the hook's live page is an empty hook: page 3 from the Sprigacocoly quest's stage 9 until it hangs at
    # 11, else page 1 until the house quest hangs it at 9.
    def self.empty?
      quest = $game_variables[932].to_i
      quest >= 9 ? quest < 11 : $game_variables[588].to_i < 9
    end

    # True while the empty hook is the next step of a quest: the house's at stage 8, or the Sprigacocoly one's.
    def self.wants_portrait?
      empty? && ($game_variables[932].to_i >= 9 || $game_variables[588].to_i == 8)
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  house = PokeAccess::RejuvStrangeHouse
  mechanic(:state, 560, :part => :hook) do
    auto
    name 19, lambda { |_ev| house.empty? ? :rj_hook : :rj_hook_portrait }, :when => lambda { |_ev| house.empty? }
    active { PokeAccess::Puzzles.assist? && house.wants_portrait? }
    hint :rj_hook_hint
  end
end
