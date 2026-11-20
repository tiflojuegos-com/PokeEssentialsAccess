# Ishizu. The temple (map 299): with Sorano's translation legend (variable 320 at 1), five sprite-less tablets (events 24
# to 28) raise it to 6, and Sorano then opens the stairs down. The Jade Catacombs (map 479): with the quest on (variable 321
# from 1), each of five good pots knocked over (events 4, 8, 14, 19 and 24, switches 201 to 205) withdraws the trap of its
# number, in that order across the catacombs, and seven pots alike to them start a battle.
module PokeAccess
  module SoulstonesIshizu
    GOOD_POTS = { 4 => 1, 8 => 2, 14 => 3, 19 => 4, 24 => 5 }
    TRAP_POTS = [12, 13, 18, 23, 34, 35, 36]
    POT_SWITCH = 200

    # The label of a pot: plain without the assist; with it, the trap it withdraws or that it is a trap.
    def self.pot_label(ev)
      return :ss1_jade_pot unless PokeAccess::Puzzles.assist?
      n = GOOD_POTS[ev.id]
      n ? [:ss1_jade_pot_good, { :n => n }] : :ss1_jade_pot_trap
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  ish = PokeAccess::SoulstonesIshizu

  mechanic(:state, 299) do
    auto
    name 24..28, :ss1_ishizu_tablet, :when => lambda { |_ev| (1..5).include?($game_variables[320].to_i) }
    count :ss1_ishizu_tablets, :value => lambda { [[$game_variables[320].to_i - 1, 0].max, 5].min }, :of => 5,
                               :assist => true, :hide_zero => true
    hint :ss1_ishizu_hint
    solved(nil, :quiet => true) { $game_variables[320].to_i >= 6 }
  end

  mechanic(:state, 479) do
    auto
    name ish::GOOD_POTS.keys, lambda { |ev| ish.pot_label(ev) },
         :when => lambda { |ev| !$game_switches[ish::POT_SWITCH + ish::GOOD_POTS[ev.id]] }
    name ish::TRAP_POTS, lambda { |ev| ish.pot_label(ev) }
    count :ss1_jade_traps, :value => lambda { [[$game_variables[321].to_i - 1, 0].max, 5].min }, :of => 5,
                           :assist => true, :hide_zero => true
    hint :ss1_jade_hint
    solved(nil, :quiet => true) { $game_variables[321].to_i >= 6 }
  end
end
