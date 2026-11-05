# Perseida's Mensa gym (map 157): three rooms of three people each, and only one in each is the one to fight. Every person asks
# whether they are the one. The right ones are Mama (switch 80), Sucellus (switch 81) and Anders (switch 82); a wrong yes counts
# a miss in variable 66 and brings a fight. The assist says the right answer to each question.
PokeAccess::Game.define("perseida") do
  mechanic(:state, 157) do
    auto
    right_choice [29, 30, 31, 33, 34, 35], :avoids => { :var => 66 }
    right_choice 28, :takes => { :switch => 80 }
    right_choice 32, :takes => { :switch => 81 }
    right_choice 36, :takes => { :switch => 82 }
  end
end
