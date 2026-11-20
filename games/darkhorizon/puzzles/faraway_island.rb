# Faraway Island: the clearing's north exit (map 160, event 5) opens once both sides are done, the east one (switch 344, set
# in map 164) and the west one (switch 345, which the stone tablet's map 165 brings: the tile puzzle, then Mew's vision, then
# Cody's talk). Each map reads its own switches when it is entered, so the clearing answers only the info key, and the tablet's
# map says its side's state as it changes. The tablet has no graphic and answers only to a player facing up.
PokeAccess::Game.define("darkhorizon") do
  mechanic(:state, 160) do
    auto
    watch :switch => 344, :label => :dh_pz_east, :on => :dh_pz_side_done, :off => :dh_pz_side_left
    watch :switch => 345, :label => :dh_pz_west, :on => :dh_pz_side_done, :off => :dh_pz_side_left
    solved { $game_switches[344] && $game_switches[345] }
    hint lambda {
      left = []
      left.push(:dh_pz_faraway_h_east) unless $game_switches[344]
      left.push(:dh_pz_faraway_h_west) unless $game_switches[345]
      left.empty? ? :dh_pz_faraway_h_exit : PokeAccess.sentences(left.map { |k| PokeAccess::I18n.t(k) })
    }
  end

  mechanic(:state, 165) do
    auto
    name 4, :dh_pz_tablet
    watch :switch => 345, :label => :dh_pz_west, :on => :dh_pz_side_done, :off => :dh_pz_side_left
    solved { $game_switches[345] }
    hint :dh_pz_tablet_hint
  end
end
