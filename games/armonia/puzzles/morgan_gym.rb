# Morgan's gym at Ciudad Wiel (maps 103 and 105): barmen offer what his cocktail needs. Those whose offer is wrong answer a yes
# with a fight, so with the assist they get a no; those with the right one, and the cook of map 106, have no wrong answer to warn of.
PokeAccess::Game.define("armonia") do
  [[103, [5, 8]], [105, [5, 7]]].each do |map, barmen|
    mechanic(:state, map) do
      auto
      right_choice barmen, :avoids => :battle
    end
  end
end
