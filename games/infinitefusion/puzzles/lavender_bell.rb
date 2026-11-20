# Lavender Town's bell (map 50, event 11): a silent action event that opens the Hidden Tomb only while the computer's
# clock reads 3:11 to 3:19, and says nothing useful otherwise.
PokeAccess::Game.define("infinitefusion") do
  open = lambda { $game_switches[159] }

  mechanic(:state, 50) do
    auto
    name 11, :ifo_bell, :when => lambda { |_ev| !open.call }
    hint lambda { open.call ? nil : :ifo_bell_hint }
    active { PokeAccess::Puzzles.assist? && !open.call }
  end
end
