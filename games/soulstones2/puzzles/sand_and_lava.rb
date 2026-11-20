# Ground that drops the player, in Soulstones 2:
# - Sand traps: rings of four sprite-less "Sand Trap" events round a pit, in thirteen maps, that turn the player, drag them in
#   and transfer them to a cave below. The pit is drawn, so it is named and told on arriving; as a trap, the routes keep off it
#   with the puzzle assist alone.
# - Mt. Oberon (maps 173 and 174): each Strength boulder goes down the hole beside it, which a parallel event checks by the
#   boulder's place and marks with S65 to S69; the hole still drops the player after. Below, on maps 174 and 175, the
#   dropped boulders let the lava hops of S65's page be taken. The routes push the boulders and take the hops by themselves.
module PokeAccess
  module SS2Drops
    SAND_MAPS = [44, 45, 46, 47, 49, 74, 75, 139, 186, 187, 512, 513, 540]
    OBERON = { 173 => [[16, 15, [39, 14], 65], [19, 18, [37, 44], 66]],
               174 => [[31, 32, [12, 65], 67], [34, 35, [25, 33], 68], [37, 38, [48, 67], 69]] }
  end
end

PokeAccess::Game.define("soulstones2") do
  mechanic(:state, PokeAccess::SS2Drops::SAND_MAPS) do
    auto
    name(/Sand Trap/, :ss2_pz_sand_trap, :grouped => true)
    arrival_hint :ss2_pz_sand_rule, :once => true
    avoid(/Sand Trap/, :assist => true)
    on_use(/Sand Trap/, :ss2_pz_sand_dragged)
  end

  PokeAccess::SS2Drops::OBERON.each do |map, rocks|
    rocks.each do |boulder, hole, at, switch|
      mechanic(:state, map, :part => "rock#{boulder}".to_sym) do
        auto
        name hole, :ss2_pz_oberon_hole
        watch :switch => switch, :say => :ss2_pz_oberon_rock_in
        phase(lambda { !$game_switches[switch] }, :quiet => true, :hint => :ss2_pz_oberon_hint,
              :track => { :event => boulder, :label => :ss2_pz_oberon_rock, :goal => [at[0], at[1], at[0], at[1]],
                          :goal_label => :ss2_pz_oberon_hole })
        solved { $game_switches[switch] }
      end
    end
  end
end
