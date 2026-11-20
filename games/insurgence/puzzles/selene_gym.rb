# Selene Gym (maps 286 and 682): twenty-four invisible bands (invisi) in groups of three tiles hide the player (opacity 0,
# switch 151) while they cross the trainers' lanes and show them again at the far end of each lane. The way is the
# straight column of the middle, with no puzzle in the layout: both ends join the entrance and the door to the leader.
PokeAccess::Game.define("insurgence") do
  [286, 682].each do |map|
    mechanic(:state, map) do
      auto
      name(/\Ainvisi\z/, :ins_u1_shade_band, :grouped => true)
      watch :switch => 151, :label => :ins_u1_invisible, :on => :ins_u1_invisible_on, :off => :ins_u1_invisible_off
      info { $game_switches[151] ? :ins_u1_invisible_now : nil }
      active { true }
      hint :ins_u1_selene_hint
    end
  end
end
