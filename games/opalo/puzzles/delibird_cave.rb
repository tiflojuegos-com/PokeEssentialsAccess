# Opalo's Cueva Sospechosa (map 196): the panel by the door of the Delibird hideout (event 4, no graphic) asks a code of six
# digits, which the core says with the assist; a right one opens the door (switch 902).
PokeAccess::Game.define("opalo") do
  mechanic(:state, 196) do
    auto
    name 4, :op_code_panel, :when => lambda { |_ev| !$game_switches[902] }
  end
end
