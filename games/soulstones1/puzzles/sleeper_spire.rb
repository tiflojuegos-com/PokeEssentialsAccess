# Sleeper Spire (maps 41, 44, 45 and 46). Five door switches (switches 112, 113, 122, 123 and 124), each worked on its own
# tile, change where the tower's doors lead, and the healing shrines can turn them all off; the summit (map 47) is reached
# with 112 off at map 44's west door (event 9), 122 on at map 46's door (event 7) and 124 on at map 45's door (event 28).
# The entrance (map 41) has three floors of hidden traps that throw the player back to their start until the slab at their
# end (switches 114 to 116) disarms them; the first lies on the way, and past it the scene at (16, 14) opens the north
# door (switch 121). The climb ends with variable 195 at 9.
module PokeAccess
  module SoulstonesSpire
    SWITCHES = [[112, 1], [113, 2], [122, 3], [123, 4], [124, 5]]
    TRAPS = [[/\AWalking Puzzle 1\z/, [7, 33]], [/\AWalking Puzzle 2\z/, [13, 20]], [/\AWalking Puzzle 3\z/, [32, 17]]]
    SWITCH5_ROOM = { 6 => [14..16, 18..20, 22..25], 7 => [14..25], 8 => [13..25], 9 => [12..25],
                     10 => [12..13, 15..22, 24..25], 11 => [11..22, 25..26], 12 => [11..11, 13..18, 21..21, 23..27],
                     13 => [13..16, 22..28], 14 => [15..15, 24..26] }
    SIDE_ROOMS_44 = { 30 => [25..26], 31 => [5..5, 25..28, 33..33], 32 => [5..6, 24..28, 32..33],
                      33 => [5..6, 11..12, 25..29, 31..33], 34 => [5..6, 10..14, 26..29, 32..33],
                      35 => [5..14, 26..30, 32..33], 36 => [5..15, 26..33] }

    # The name of a door switch, by the number its event's name gives.
    def self.switch_label(ev)
      [:ss1_spire_switch, { :n => ev.name.to_s[/\d\z/].to_i }]
    end

    # True when (x, y) lies in a room given as rows of x ranges.
    def self.in_rows?(rows, x, y)
      (rows[y] || []).any? { |r| r.include?(x) }
    end

    # True when the player stands in the box x0..x1, y0..y1.
    def self.inside?(x0, x1, y0, y1)
      x = $game_player.x
      y = $game_player.y
      x >= x0 && x <= x1 && y >= y0 && y <= y1
    end

    # The step toward the summit from where the player stands, as the switches are now: a hint key.
    def self.step
      x = $game_player.x
      y = $game_player.y
      case $game_map.map_id
      when 41
        return :ss1_spire_hint_trap unless $game_switches[114]
        $game_switches[121] ? :ss1_spire_hint_north : :ss1_spire_hint_story
      when 44
        return :ss1_spire_hint_side_room if in_rows?(SIDE_ROOMS_44, x, y)
        $game_switches[112] ? :ss1_spire_hint_off1 : :ss1_spire_hint_door9
      when 45
        return :ss1_spire_hint_maze unless in_rows?(SWITCH5_ROOM, x, y) || [x, y] == [19, 8]
        $game_switches[124] ? :ss1_spire_hint_door28 : :ss1_spire_hint_on5
      when 46
        return($game_switches[122] ? :ss1_spire_hint_door7 : :ss1_spire_hint_on3) if inside?(17, 23, 4, 11)
        return :ss1_spire_hint_summit if inside?(36, 42, 30, 41)
        :ss1_spire_hint_side_room
      end
    end

    # The event the assist points at now: the switch to work or the door to take, or nil.
    def self.right_event
      case step
      when :ss1_spire_hint_story then 135
      when :ss1_spire_hint_north then 3
      when :ss1_spire_hint_off1 then 10
      when :ss1_spire_hint_door9 then 9
      when :ss1_spire_hint_on5 then 33
      when :ss1_spire_hint_door28 then 28
      when :ss1_spire_hint_on3 then 10
      when :ss1_spire_hint_door7 then 7
      when :ss1_spire_hint_summit then 1
      end
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  spire = PokeAccess::SoulstonesSpire

  mechanic(:state, 41, :part => :traps) do
    auto
    spire::TRAPS.each { |pattern, start| sent_back :ss1_spire_trap_back, :to => start, :events => pattern }
    arrival_hint :ss1_spire_traps_rule, :once => true
    solved(nil, :quiet => true) { $game_switches[114] && $game_switches[115] && $game_switches[116] }
  end

  mechanic(:state, [41, 44, 45, 46], :part => :doors) do
    auto
    spire::SWITCHES.each do |sw, n|
      watch :switch => sw, :label => [:ss1_spire_switch, { :n => n }], :on => :ss1_spire_on, :off => :ss1_spire_off
    end
    name(/\ASwitch - Door \d\z/, lambda { |ev| spire.switch_label(ev) })
    name(/\AHealing Shrine\z/, :ss1_spire_shrine)
    [1, 3, 7, 9, 10, 28, 33, 135].each do |id|
      spot(:event => id, :label => :puzzle_right_way, :assist => true, :when => lambda { spire.right_event == id })
    end
    arrival_hint :ss1_spire_rule, :once => true
    hint lambda { spire.step }
    solved { $game_variables[195].to_i >= 9 }
  end
end
