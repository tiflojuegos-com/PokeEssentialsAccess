# Ashen Frost's stuck locker at Blackthorne Academy (map 698, Case Eighteen): Henry's locker (EV51), a sparkle, opens a
# tile puzzle the core reads and sets its self switch A once solved. It is only named until then, since a sparkle reads
# as a hidden item.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 698, :part => :afd_locker) do
    auto
    name 51, :afd_locker, :when => lambda { |_ev| !$game_self_switches[[698, 51, "A"]] }
    solved(nil, :quiet => true) { $game_self_switches[[698, 51, "A"]] }
  end
end
