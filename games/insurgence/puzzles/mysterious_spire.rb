# Mysterious Spire, SPIRETech (map 742): four shelves (events 9 to 12, at 59 to 62,28) read, when asked, the password of
# the portal terminal (event 7, at 34,12), "chandrasekhar". Switch 599 is the portal turned on and switch 600 opens the
# Hoopa ring (event 6).
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 742) do
    auto
    name 7, :ins_u1_portal_terminal
    name 9..12, :ins_u1_password_shelf, :grouped => true
    answer 7, "chandrasekhar"
    active { !$game_switches[599] }
    solved(nil, :quiet => true) { $game_switches[599] }
  end
end
