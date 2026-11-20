# The Trick House of Route 110 (maps 563 to 568): each room is left by a warp tile at its far end. The second one (map
# 564) keeps that tile off until the four switches under the boxes (EV2 to EV5, switches 243 to 246) and the switch on
# the wall (EV18, switch 242, "Warp tile activated!") are pressed; each box switch moves a hole (EV1, EV6, EV7, EV8).
module PokeAccess
  module SeviiTrickHouse
    BOXES_ROOM = 564
    # Box events and the switch each one presses.
    BOXES = { 2 => 243, 3 => 244, 4 => 245, 5 => 246 }
  end
end

PokeAccess::Game.define("sevii") do
  house = PokeAccess::SeviiTrickHouse

  mechanic(:state, house::BOXES_ROOM) do
    auto
    name house::BOXES.keys, lambda { |ev| $game_switches[house::BOXES[ev.id]] ? :sevii_box_pressed : :sevii_box }
    name 18, :sevii_box_warp_switch
    count :sevii_box_count, :switches => house::BOXES.values
    house::BOXES.each do |ev, switch|
      spot :event => ev, :label => :sevii_box_next, :assist => true, :when => lambda { !$game_switches[switch] }
    end
    spot :event => 18, :label => :sevii_box_next, :assist => true,
         :when => lambda { house::BOXES.values.all? { |s| $game_switches[s] } && !$game_switches[242] }
    hint :sevii_box_hint
    solved(nil, :quiet => true) { $game_switches[242] }
  end
end
