# Deoxys's meteors in the New World Crash (map 884): four meteors (events 8, 12, 13, 14), actions with no graphic, past
# the row where Ciel speaks (variable 650 at 3); each adds 1 to it and turns its self switch A on, in any order, and the
# fourth (650 at 7) puts Deoxys at (35, 12). After the battle (650 from 8) a meteor changes a Deoxys's form.
module PokeAccess
  module RebornDeoxysMeteors
    METEORS = [8, 12, 13, 14]
    QUEST = 650

    # True while the meteor still has something to give: untouched once Ciel has spoken, or Deoxys already caught. A
    # touch before Ciel would spend it, as she then sets the count to 3.
    def self.live?(ev)
      v = $game_variables[QUEST].to_i
      v >= 8 || (v >= 3 && !$game_self_switches[[884, ev.id, "A"]])
    end

    # True while the hunt is on: Ciel has spoken and Deoxys has not come down.
    def self.hunting?
      $game_variables[QUEST].to_i.between?(3, 6)
    end
  end
end

PokeAccess::Game.define("reborn") do
  meteors = PokeAccess::RebornDeoxysMeteors
  mechanic(:state, 884, :part => :meteors) do
    auto
    name meteors::METEORS, :rbe_meteor, :when => lambda { |ev| meteors.live?(ev) }
    count :rbe_meteors, :selfs => [meteors::METEORS, "A", 884]
    active { meteors.hunting? }
    solved(nil, :quiet => true) { $game_variables[meteors::QUEST].to_i >= 7 }
  end
end
