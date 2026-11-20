# The warp tiles of Sevii (events named "Warp Tile" on a drawn pad, common events 5 and 6): stepping on one sends the
# player to another pad, most of them on the same map, which the routes already take. Named on every map that has them;
# the Team Rocket Labs of Six Island (map 250) is left only by the pad EV4, to the lab's last room (map 314).
module PokeAccess
  module SeviiWarps
    MAPS = [99, 234, 235, 250, 314, 514, 520, 521, 561, 563, 564, 565, 566, 567, 568]
    LABS = 250
  end
end

PokeAccess::Game.define("sevii") do
  warps = PokeAccess::SeviiWarps

  mechanic(:state, warps::MAPS, :part => :warps) do
    auto
    name(/^Warp Tile$/, :sevii_warp_tile)
  end

  mechanic(:state, warps::LABS, :part => :way_on) do
    auto
    spot :event => 4, :label => :sevii_labs_way_on, :assist => true, :onto => true
    hint :sevii_labs_hint
    solved(nil, :quiet => true) { $game_switches[133] }
  end
end
