# The arrow floor of Sede Nytia N.3 (map 200), between the stairs and the lift's keypad (event 26). Each arrow is a touch event with
# no graphic over a drawn arrow, whose next page moves the player its way; a step that lands on another arrow takes that one's
# move instead, as the engine starts it. The arrows are named by their way, the rule is said on arriving and, with the assist,
# the four that lead to the keypad, until the lift is used. The routes ride them by arrow_floor.rb.
module PokeAccess
  module ArmoniaArrows
    MAP = 200
    KEYPAD = 26
    # Each arrow by event id: its tile, its way, and the tile the player ends on, chains taken.
    ARROWS = {
      1 => [9, 28, 2, 9, 34], 2 => [10, 29, 2, 10, 34], 3 => [11, 38, 2, 11, 41], 4 => [10, 39, 4, 6, 39],
      5 => [12, 41, 6, 20, 35], 6 => [6, 41, 8, 10, 34], 7 => [10, 41, 4, 10, 34], 8 => [13, 40, 6, 10, 34],
      9 => [18, 40, 8, 10, 34], 10 => [18, 34, 4, 10, 34], 11 => [15, 34, 4, 10, 34], 12 => [6, 40, 6, 10, 34],
      13 => [17, 41, 8, 20, 35], 14 => [17, 35, 6, 20, 35], 15 => [14, 29, 4, 10, 34], 16 => [17, 28, 4, 10, 34],
      17 => [15, 28, 2, 10, 34], 18 => [16, 29, 4, 10, 34], 19 => [14, 25, 8, 14, 19], 20 => [19, 25, 4, 14, 19],
      21 => [20, 24, 4, 10, 34], 22 => [15, 24, 2, 10, 34], 23 => [17, 23, 2, 10, 34], 35 => [8, 29, 8, 8, 28]
    }
    WAYS = { 2 => :arm_nytia_arrow_down, 4 => :arm_nytia_arrow_left, 6 => :arm_nytia_arrow_right, 8 => :arm_nytia_arrow_up }
    # The arrows the way to the keypad takes, in order: down from the left corridor, down the narrow one, right along the bottom
    # and, past the walk up the right side, left onto the one that goes up.
    RIGHT_WAY = [2, 3, 5, 20]
    @at = {}
    ARROWS.each { |id, a| @at[[a[0], a[1]]] = id }

    # The arrow's id at (x, y) of map 200, its event still standing there, or nil.
    def self.at(x, y)
      return nil unless ($game_map.map_id rescue nil) == MAP
      id = @at[[x, y]]
      ev = id && ($game_map.events[id] rescue nil)
      ev && ev.x == x && ev.y == y ? id : nil
    end

    # Where stepping onto the arrow at (x, y) leaves the player, or nil off the arrows.
    def self.landing(x, y)
      id = at(x, y)
      id ? ARROWS[id][3, 2] : nil
    end

    # The name of an arrow by its way.
    def self.label(ev)
      a = ARROWS[ev.id]
      a ? WAYS[a[2]] : nil
    end

    # Whether the lift's keypad has let the player through.
    def self.done?
      $game_self_switches[[MAP, KEYPAD, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("armonia") do
  arrows = PokeAccess::ArmoniaArrows
  mechanic(:state, arrows::MAP) do
    auto
    name arrows::ARROWS.keys, lambda { |ev| arrows.label(ev) }
    arrival_hint :arm_nytia_arrows_rule
    phase lambda { !arrows.done? }, :quiet => true, :hint => :arm_nytia_arrows_hint, :hidden => right_way(*arrows::RIGHT_WAY)
    solved { arrows.done? }
  end
end
