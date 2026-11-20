# The Chromatic Mine (map 104), the only way from Route 3 to Route 4: its parts are joined only by carts with no sprite
# (EV7 to EV15) that ride the player along the rails, and three levers turn the rails' switches (EV5 the first, S92; EV4
# the second, S93; EV6 and EV24 the third, S94), which change where some carts go. ROOMS holds the boxes of the parts
# reached on foot; NEXT, for each part and the switches turned, the carts or levers that are the first step of a
# shortest way to the exit part (ROOMS[2]), found by riding each cart's move route on the map's passability. The levers
# are named and their switches watched, so the core does not take them for silent controls as well.
module PokeAccess
  module RoyalMine
    MAP = 104
    CARTS = 7..15
    LEVERS = { 5 => 1, 4 => 2, 6 => 3, 24 => 3 }
    SWITCHES = { 92 => :royal_mine_switch1, 93 => :royal_mine_switch2, 94 => :royal_mine_switch3 }
    ROOMS = [[34, 44, 51, 61], [24, 35, 77, 85], [26, 35, 6, 14], [15, 23, 39, 44], [51, 58, 21, 28],
             [39, 55, 42, 45], [15, 23, 28, 33]]
    NEXT = {
      [0, []] => [7], [0, [94]] => [7],
      [1, []] => [14], [1, [92]] => [14], [1, [92, 93]] => [14], [1, [92, 93, 94]] => [24], [1, [92, 94]] => [24],
      [1, [93]] => [14], [1, [93, 94]] => [24, 14], [1, [94]] => [24, 14],
      [3, []] => [9], [3, [94]] => [9],
      [4, []] => [12], [4, [92]] => [11], [4, [92, 93]] => [11], [4, [92, 93, 94]] => [11], [4, [93]] => [12],
      [4, [93, 94]] => [12],
      [5, []] => [4], [5, [92]] => [10], [5, [92, 93]] => [4], [5, [92, 93, 94]] => [4], [5, [92, 94]] => [10],
      [5, [93]] => [10], [5, [93, 94]] => [10], [5, [94]] => [4],
      [6, []] => [5], [6, [92]] => [15], [6, [92, 93]] => [15], [6, [92, 93, 94]] => [15], [6, [92, 94]] => [15],
      [6, [93]] => [5], [6, [93, 94]] => [5], [6, [94]] => [5]
    }

    # The part of the mine the player stands in, by its index in ROOMS, or nil.
    def self.room
      x = $game_player.x
      y = $game_player.y
      ROOMS.index { |x0, x1, y0, y1| x >= x0 && x <= x1 && y >= y0 && y <= y1 }
    end

    # Whether the event is the next step towards the exit from where the player stands.
    def self.next?(ev)
      on = SWITCHES.keys.sort.select { |s| $game_switches[s] }
      (NEXT[[room, on]] || []).include?(ev.id)
    end

    # A cart's name; with the assist, the next step stands out.
    def self.cart_label(ev)
      PokeAccess::Puzzles.assist? && next?(ev) ? :royal_mine_cart_next : :royal_mine_cart
    end

    # A lever's name by the rail switch it turns; with the assist, the next step stands out.
    def self.lever_label(ev)
      key = PokeAccess::Puzzles.assist? && next?(ev) ? :royal_mine_lever_next : :royal_mine_lever
      [key, { :n => LEVERS[ev.id] }]
    end
  end
end

PokeAccess::Game.define("royal") do
  mine = PokeAccess::RoyalMine
  mechanic(:state, mine::MAP) do
    auto
    mine::SWITCHES.each do |switch, label|
      watch :switch => switch, :label => label, :on => :royal_mine_turned, :off => :royal_mine_straight
    end
    name mine::CARTS, lambda { |ev| mine.cart_label(ev) }
    name mine::LEVERS.keys, lambda { |ev| mine.lever_label(ev) }
    not_control mine::LEVERS.keys
    hint :royal_mine_hint
  end
end
