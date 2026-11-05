# Opalo's riddle in a house of Galerna City (map 108, event 13): a menu of three berries whose right option sets the event's
# self switch A as it gives the reward. The assist says that option in the game's own words.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 108) do
    auto
    right_choice 13, :takes => { :self => "A" }
  end
end
