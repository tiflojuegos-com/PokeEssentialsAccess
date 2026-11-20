# Creepy House (map 714): four old dolls appear one at a time, each in a room once its entrance is crossed, and vanish when
# the entrance is crossed again after the doll was found; the fifth one (event 44) wakes Mimikyu (switch 622). Variable 233
# counts them. The entrances are events 7, 11 and 13 (crossed going left, right and left) and 45. The piano of event 19
# tells the count and, at random, a room's name, and it switches off the classroom doll (event 6): when that was the
# chosen doll and not yet found, it is gone and no other is chosen until the house is left and entered again (map 713).
PokeAccess::Game.define("infinitefusion") do
  rooms = [[6, 625, 7, "classroom"], [10, 624, 11, "bathroom"], [12, 623, 13, "library"], [14, 615, 45, "hall"]]
  self_on = lambda { |id, letter| $game_self_switches[[714, id, letter]] }
  found = lambda { $game_variables[233] }

  classroom_doll = rooms.first[0]
  lost = lambda do
    pending = $game_variables[5]
    pending.is_a?(Array) && !pending.include?(classroom_doll) && !self_on.call(classroom_doll, "A") && !self_on.call(classroom_doll, "B")
  end

  advice = lambda do
    if found.call >= 4
      :ifo_doll_last
    elsif rooms.any? { |doll, _s, _e, _n| self_on.call(doll, "B") && !self_on.call(doll, "C") }
      :ifo_doll_leave
    elsif lost.call
      :ifo_doll_lost
    else
      waiting = rooms.detect { |doll, switch, _e, _n| self_on.call(doll, "A") && !self_on.call(doll, "B") && !$game_switches[switch] }
      waiting ? "ifo_doll_wait_#{waiting[3]}".to_sym : nil
    end
  end

  mechanic(:state, 714) do
    auto
    name [6, 10, 12, 14, 44], :ifo_doll
    name [5, 18, 19], :ifo_piano
    count :ifo_dolls, :value => lambda { [found.call, 4].min }, :of => 4, :assist => true
    rooms.each { |_d, _s, entrance, room| spot :event => entrance, :label => "ifo_entrance_#{room}".to_sym, :assist => true }
    hint advice
    active { PokeAccess::Puzzles.assist? && !$game_switches[622] }
  end
end
