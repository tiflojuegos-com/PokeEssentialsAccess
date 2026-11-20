# Cinnabar Island Gym (map 221): six quiz computers with no graphic, each across two tiles but the fifth. A wrong answer
# only starts a fight and the room opens either way, so the assist just gives the option whose branch counts the answer
# as right (var 117).
PokeAccess::Game.define("infinitefusion") do
  computers = [[17, 34], [18, 35], [28, 36], [30, 37], [31], [38, 39]]
  mechanic(:state, 221) do
    computers.each_with_index { |ids, i| name ids, [:ifk_cg_question, { :n => i + 1 }] }
    right_choice computers.flatten, :takes => { :var => 117 }
  end
end
