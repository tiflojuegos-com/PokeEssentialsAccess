# The old man of Northallow Village (map 711, EV17, variable 295 at 9): he asks the ghost's name (passCheck "Avon") and
# two menus; a wrong option asks to revise, the right ones lead to the battle that sets 295 to 10, so the assist reads
# them from that.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 711, :part => :avon) do
    auto
    right_choice 17, :takes => { :var => 295 }
  end
end
