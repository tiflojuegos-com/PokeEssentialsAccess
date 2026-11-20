# Rustbolt's gym (map 55): the dancer (event 66) waits for four direction presses after her line, and only up, right, down,
# left (variable 130 at 4312) is right. The dance she points to is a sign with no graphic, so no one sees it.
PokeAccess::Game.define("solarlight") do
  mechanic(:state, 55) do
    auto
    on_reach 66, { :text => 0 }, lambda { |ev| PokeAccess::Puzzles.assist? ? :solar_dancer_answer : :solar_dancer_wait }
  end
end
