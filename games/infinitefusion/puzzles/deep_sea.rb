# The Deep Sea's underwater rooms (maps 679 to 684, 687 to 689 and 691, off the map 560): near-identical rooms whose exits,
# four events side by side each, are Kernel.pbTransferUnderwater to another room. Walking the graph of those transfers, the
# sapphire room (685, switch 522 at event 1) is reached from 560 by 679, then 680 or 681, then 683 or 684; the exits listed
# here are those that do not get any nearer to it, left out of the lists with the assist alone until the sapphire is taken.
PokeAccess::Game.define("infinitefusion") do
  away = {
    560 => [50, 51, 52, 53],
    679 => [1, 13, 14, 15],
    680 => [1, 2, 4, 11, 12, 13, 17, 18, 19, 21, 22, 23],
    681 => [3, 8, 10, 11, 12, 13, 14, 15],
    682 => [11, 15, 16, 17],
    683 => [5, 6, 14, 15, 16, 17, 18, 19],
    684 => [2, 13, 14, 15],
    691 => [2, 27, 30, 31]
  }
  rooms = [679, 680, 681, 682, 683, 684, 687, 688, 689, 691]
  line = lambda { PokeAccess::Puzzles.assist? ? :ifq_deep_assist : :ifq_deep_rule }

  away.each do |map, ids|
    mechanic(:state, map) do
      auto
      hide ids, :assist => true, :when => lambda { |_ev| !$game_switches[522] }
      solved(nil, :quiet => true) { $game_switches[522] }
      arrival_hint line, :once => true if rooms.include?(map)
    end
  end

  (rooms - away.keys).each do |map|
    mechanic(:state, map) do
      auto
      solved(nil, :quiet => true) { $game_switches[522] }
      arrival_hint line, :once => true
    end
  end
end
