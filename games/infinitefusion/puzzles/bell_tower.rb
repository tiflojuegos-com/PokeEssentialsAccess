# Ecruteak's Bell Tower (maps 649, 653, 652 and 650): hidden switches (variable 206, two presses clear the barriers on
# the central stair) and bell tiles that flip switch 528, which opens one side of the floor and closes the other.
PokeAccess::Game.define("infinitefusion") do
  floors = { 649 => [[4, 10], [1]], 653 => [[4, 7], [1]], 652 => [[4, 7], [11, 12]], 650 => [[4, 7], [11, 9]] }
  switches = lambda { [$game_variables[206], 2].min }

  floors.each do |map, (hidden, bells)|
    mechanic(:state, map) do
      name hidden, :ifo_bt_switch
      name bells, :ifo_bt_bell
      count :ifo_bt_switches, :value => switches, :of => 2, :announce => false, :assist => true
      if map == 650
        auto
      else
        obstacle({ :events => [5, 6, 8, 9] })
        watch :switch => 528, :label => :ifo_bt_side, :on => :ifo_bt_left, :off => :ifo_bt_right
        controls
      end
    end
  end
end
