# Baykal Rainforest (map 256): the boulder and the rock at (19 to 20, 40) close the way east until the old silverback
# Empirilla (event 28), asked through the PST once variable 34 reaches 19, throws the boulder aside and breaks the rock.
# The assist tells the option that asks it.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 256) do
    auto
    right_choice 28, :takes => { :self => "A" }
  end
end
