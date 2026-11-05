# The lift of Sede Nytia: its code, which the core says with the assist where map 200 asks for it, comes from a scientist of map 197
# (event 29), who gives it right away for the berry another scientist names and after a fight for any other; two of the wrong
# berries jump to that fight, so the right branch is the one that ends his page without one.
PokeAccess::Game.define("armonia") do
  mechanic(:state, 197) do
    auto
    right_choice 29, :takes => { :self => "A" }, :avoids => :battle
  end
end
