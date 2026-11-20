# Kindle Road's large boulder (map 559): six pieces (events 1 to 6, 14 to 16 by 34 and 35) that fell on the road. Talking to
# the trainer beside it (event 23, switch 506) and then to the top right piece (event 6) pushes it aside together, which
# sets switch 451 and leaves the pieces with no graphic. The boulder over Trapinch's nest (event 46) is pushed with the
# ordinary push of the routes.
PokeAccess::Game.define("infinitefusion") do
  pieces = (1..6).to_a

  mechanic(:state, 559) do
    auto
    name pieces, :ifq_boulder, :grouped => true
    name 23, :ifq_boulder_guy
    spot :event => 6, :label => :ifq_boulder_push, :assist => true
    solved(nil, :quiet => true) { $game_switches[451] }
    active { !$game_switches[451] }
    hint :ifq_boulder_hint
  end
end
