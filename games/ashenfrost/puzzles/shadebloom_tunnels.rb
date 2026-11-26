# Severn's Story, the flashback the Fogdale librarian tells (Shadebloom Tunnels, map 677): Severn reaches the way on
# (event 2) past the spikes of event 9, lowered through its self switch A by a switch with no graphic (event 10) pressed
# on its tile. Event 4 is a door that only turns Severn back.
PokeAccess::Game.define("ashenfrost") do
  down = lambda { $game_self_switches[[677, 9, "A"]] ? true : false }
  mechanic(:state, 677, :part => :spikes) do
    auto
    obstacle({ :events => 9 }, :label => :afg_sv_spikes)
    name 10, :afg_sv_switch, :assist => true, :when => lambda { |_ev| !down.call }
    hint :afg_sv_hint
    solved(nil, :quiet => true) { down.call }
    active { PokeAccess::Puzzles.assist? && !down.call }
  end
end
