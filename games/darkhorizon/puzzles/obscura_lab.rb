# Obscura Lab on Citadark Isle: its way in is the rock face under a carved Tyranitar head (map 23, event 11), searched with the
# action button from the south to open (switch 117) into the cave by the lab's security door; on the island's east part (x 42 to
# 58), reached across the cave from the west part. No auto there: the door frame drawn as it opens would be heard as ways shut.
# The entrance room's door has no power until the dusty lever (map 83, event 39) is operated (switch 119), and the door at the
# east end (map 84, event 48) is a tile puzzle the game calls a code; the core's tile puzzle reader voices it (the game's win is
# piece n on cell n, turned 0).
PokeAccess::Game.define("darkhorizon") do
  mechanic(:state, 23) do
    name 11, lambda { |_ev| $game_switches[117] ? nil : :dh_pz_tyranitar_wall }, :when => lambda { |_ev| !$game_switches[117] }
    shut = lambda { PokeAccess::Puzzles.assist? && !$game_switches[117] }
    east = at(42, 58, 20, 39)
    phase lambda { shut.call && east.call }, :quiet => true, :hint => :dh_pz_tyranitar_hint_near
    phase shut, :quiet => true, :hint => :dh_pz_tyranitar_hint
  end

  mechanic(:state, 83) do
    auto
    name 39, :dh_pz_lever
    phase lambda { !$game_switches[119] }, :title => :dh_pz_no_power, :quiet => true, :hint => :dh_pz_lever_hint
  end

  mechanic(:state, 84) do
    auto
    on_reach 48, { :text => 1 }, :dh_pz_tile_door
  end
end
