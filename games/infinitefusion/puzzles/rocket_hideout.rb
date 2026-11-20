# Team Rocket Hideout (maps 449, 455 and 456): Erika splits the way once the player passes her (switch 145). Each side has
# a strip of two tiles that asks to confirm (events 9 and 10 on the right, 11 and 12 on the left) in front of the doors
# (5 and 6, 7 and 8); choosing writes switch 147 and Erika goes the other way. The locator lists one point per side while
# the choice is open. Rooms 455 and 456 are floors of arrows that push the player.
PokeAccess::Game.define("infinitefusion") do
  choosing = lambda { $game_switches[145] && !$game_switches[147] }

  mechanic(:state, 449, :part => :way) do
    auto
    spot :event => 9, :label => :if_jo_rocket_right, :onto => true, :when => choosing
    spot :event => 11, :label => :if_jo_rocket_left, :onto => true, :when => choosing
  end

  mechanic(:state, [455, 456]) do
    auto
    arrival_hint :if_jo_arrows_rule
  end
end
