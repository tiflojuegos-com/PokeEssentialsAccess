# The retired teacher's exam on Ruta 8 (map 140, event 4): each right answer adds one to variable 35. The invitation's branch holds
# the whole exam after a transfer, which leaves it out of the answers.
PokeAccess::Game.define("armonia") do
  mechanic(:state, 140) do
    auto
    right_choice 4, :takes => { :var => 35 }, :avoids => :transfer
  end
end
