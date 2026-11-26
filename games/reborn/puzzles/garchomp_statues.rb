# The Sugiline Ruin (map 660): Garchomp statues in four rows. Floor sensors with no graphic set variable 382 to their
# row; the statues of that row and the rows before then walk toward the player and battle on touch, and a beaten one is
# gone (self switch A). The way in from map 654 resets 382; the Arceus button (map 661, switch 885) opens the pits.
module PokeAccess
  module RebornGarchompStatues
    # Per row, its statues and the variable that counts the beaten ones.
    ROWS = [[(3..10).to_a, 387], [(22..26).to_a, 388], [(27..30).to_a, 389], [(31..36).to_a, 390]]

    # The row of a statue, from 1, or nil.
    def self.row_of(id)
      i = ROWS.index { |ids, _| ids.include?(id) }
      i && i + 1
    end

    # True while the statue walks toward the player.
    def self.awake?(ev)
      row = row_of(ev.id)
      row && $game_variables[382].to_i >= row
    end

    # The line as a row wakes: said only while one of its statues still stands, as the game plays the cry.
    def self.waking_line
      row = $game_variables[382].to_i
      ids, beaten = ROWS[row - 1]
      return nil unless ids && $game_variables[beaten].to_i < ids.length
      :rbe_sr_waking
    end
  end
end

PokeAccess::Game.define("reborn") do
  statues = PokeAccess::RebornGarchompStatues
  mechanic(:state, 660, :part => :statues) do
    auto
    all = statues::ROWS.map { |ids, _| ids }.flatten
    name all, lambda { |ev| statues.awake?(ev) ? :rbe_sr_statue_awake : :rbe_sr_statue }
    watch :var => 382, :say => lambda { statues.waking_line }
    arrival_hint lambda { PokeAccess::Puzzles.assist? ? :rbe_sr_hint : nil }
    solved(nil, :quiet => true) { statues::ROWS.all? { |ids, beaten| $game_variables[beaten].to_i >= ids.length } }
  end

  mechanic(:state, 661, :part => :arceus_button) do
    auto
    name 40, :rbe_sr_button, :when => lambda { |_ev| !$game_switches[885] }
  end
end
