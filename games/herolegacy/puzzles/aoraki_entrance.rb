# Mt. Aoraki from Paiata (map 358): the only way on from the entrance (8, 61) is a corridor shut by two rows of ice
# blocks. The boulder of (10, 54) on (12, 54) turns switch 147 on and breaks the first row; the one of (7, 49) on
# (5, 49) turns switch 148 on and breaks the second. A broken block stays broken, whatever the boulder does next. The
# rest of the mountain on the Paiata side, its three chambers and Kyurem's cave, lies behind them. The boulders and
# their tiles are given with the assist alone.
PokeAccess::Game.define("herolegacy") do
  broken = lambda { |id| $game_self_switches[[358, id, "A"]] }
  open = lambda { |id| PokeAccess::Puzzles.assist? && !broken.call(id) }
  mechanic(:state, 358) do
    auto
    name(/\AEisblock/, :hl_ice_block)
    phase lambda { open.call(1) }, :quiet => true,
          :hint => [:hl_boulder_to, { :x => 10, :y => 54, :gx => 12, :gy => 54 }],
          :track => { :event => 30, :label => :hl_boulder, :goal => [12, 54, 12, 54], :goal_label => :hl_switch_tile }
    phase lambda { open.call(32) }, :quiet => true,
          :hint => [:hl_boulder_to, { :x => 7, :y => 49, :gx => 5, :gy => 49 }],
          :track => { :event => 33, :label => :hl_boulder, :goal => [5, 49, 5, 49], :goal_label => :hl_switch_tile }
    solved { broken.call(1) && broken.call(32) }
  end
end
