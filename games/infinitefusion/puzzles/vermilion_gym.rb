# Vermilion City Gym (map 24): 17 trash cans (events 17-33, three rows of six, the first of the top row missing) hide two
# locks in turn. Var 36 holds the event with the button; after the first lock it moves to a neighbouring can. The stairs
# to the leader come down once both locks are open; a wrong can with the first lock open resets both.
PokeAccess::Game.define("infinitefusion") do
  can_label = lambda do |ev|
    place = { :row => (ev.id - 16) / 6 + 1, :col => (ev.id - 16) % 6 + 1 }
    marked = PokeAccess::Puzzles.assist? && ev.id == $game_variables[36]
    [marked ? :ifk_vm_can_button : :ifk_vm_can, place]
  end
  solvable_round = lambda { $game_variables[36].to_i >= 17 && $game_variables[36].to_i <= 33 }

  mechanic(:state, 24) do
    name 17..33, can_label, :when => lambda { |_ev| !$game_switches[91] }
    count :ifk_vm_locks, :switches => [90, 91], :of => 2, :announce => false, :reset => false
    arrival_hint :ifk_vm_rule
    hint lambda { solvable_round.call ? :ifk_vm_hint : :ifk_vm_dead }
    solved { $game_self_switches[[24, 35, "A"]] ? true : false }
  end
end
