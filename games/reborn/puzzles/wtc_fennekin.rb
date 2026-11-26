# The Water Treatment Center's storage room (map 477), Fennekin: the computer at (10, 7) does not respond while the
# machines are off. The item ball at (13, 4) is an Electrode at level 65 on re-entering, fought on the Short-Circuit
# field. A battle ending on the Factory field restarts the machines (switch 570) and the computer gives Fennekin (571).
module PokeAccess
  module RebornWtcFennekin
    MAP = 477
    BALL = 2
    COMPUTER = 5
    MACHINES = 570
    TAKEN = 571

    # True once the item ball, picked up, hides the Electrode.
    def self.electrode?
      $game_self_switches[[MAP, BALL, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("reborn") do
  wtc = PokeAccess::RebornWtcFennekin
  mechanic(:state, wtc::MAP, :part => :fennekin) do
    auto
    name wtc::COMPUTER, lambda { |_ev| $game_switches[wtc::MACHINES] ? :rbj_wtc_computer_on : :rbj_wtc_computer },
         :when => lambda { |_ev| !$game_switches[wtc::TAKEN] }
    name wtc::BALL, :rbj_wtc_electrode, :assist => true, :when => lambda { |_ev| wtc.electrode? }
    hint :rbj_wtc_hint
    active { PokeAccess::Puzzles.assist? && !$game_switches[wtc::TAKEN] }
    solved(nil, :quiet => true) { $game_switches[wtc::TAKEN] }
  end
end
