# Opalo's Voodoo Hall (maps 284, 285 and 287): 13 pokedolls to take with a yes or no, 4 safe (switches 525 to 528) and 9 that
# attack. The taken ones stand as statues in map 284 and go on the four altar slots (events 16 to 19) for the ritual
# (event 24, switch 529), in an order only the assist tells.
PokeAccess::Game.define("opalo") do
  placed = lambda do |taken, statue, slot|
    lambda do
      doll = $game_map.events[statue]
      place = $game_map.events[slot]
      PokeAccess::Puzzles.assist? && $game_switches[taken] && doll && place && (doll.x != place.x || doll.y != place.y)
    end
  end

  mechanic(:state, 284) do
    auto
    name 12, :op_g10_doll_safe, :assist => true
    name 13..15, :op_g10_doll_bites, :assist => true
    name 16..19, :op_g10_slot, :numbered => true
    obstacle(/fuego/, :label => :op_g10_fire)
    count :op_g10_taken, :switches => 525..528, :assist => true
    phase placed.call(525, 20, 16), :title => :op_g10_gardevoir, :hint => :op_g10_hint_1,
          :track => { :event => 20, :label => :op_g10_gardevoir, :goal => [30, 19, 30, 19], :goal_label => :op_g10_goal_1 }
    phase placed.call(527, 23, 17), :title => :op_g10_empoleon, :hint => :op_g10_hint_2,
          :track => { :event => 23, :label => :op_g10_empoleon, :goal => [31, 19, 31, 19], :goal_label => :op_g10_goal_2 }
    phase placed.call(526, 22, 18), :title => :op_g10_alakazam, :hint => :op_g10_hint_3,
          :track => { :event => 22, :label => :op_g10_alakazam, :goal => [33, 19, 33, 19], :goal_label => :op_g10_goal_3 }
    phase placed.call(528, 21, 19), :title => :op_g10_duraludon, :hint => :op_g10_hint_4,
          :track => { :event => 21, :label => :op_g10_duraludon, :goal => [34, 19, 34, 19], :goal_label => :op_g10_goal_4 }
  end

  mechanic(:state, 285) do
    auto
    name 16..17, :op_g10_doll_safe, :assist => true
    name 18..22, :op_g10_doll_bites, :assist => true
  end

  mechanic(:state, 287) do
    auto
    name 17, :op_g10_doll_safe, :assist => true
    name 18, :op_g10_doll_bites, :assist => true
  end
end
