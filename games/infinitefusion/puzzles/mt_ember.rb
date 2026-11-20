# Mt. Ember: the switch of map 756 (event 3) sets switch 641, which lets the barrier of map 754 (event 6) through. The
# switch's own words name the state the other way round: the first press opens the barrier and the next closes it. The
# barrier is out of sight from the switch's room, so the state is kept for the assisted routes and the hint.
PokeAccess::Game.define("infinitefusion") do
  [754, 756].each do |map|
    mechanic(:state, map) do
      watch :switch => 641, :quiet => true
      controls
      hint lambda { $game_switches[641] ? :ifk_em_leave : :ifk_em_press }
      active { PokeAccess::Puzzles.assist? }
      if map == 756
        name 3, :ifk_em_switch
      else
        obstacle({ :events => 6 }, :label => :ifk_em_wall)
      end
    end
  end
end
