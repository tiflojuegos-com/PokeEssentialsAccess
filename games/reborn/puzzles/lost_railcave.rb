# Lost Railcave (map 251): each door sends the player back in by the opposite one. Variable 146 counts doors in a row:
# the door the rails point to (147) adds one, the one the rocks gather at (148) takes one, any other resets; ten in a
# row reach map 252. Without the assist the rails and rocks are named as drawn; with it, the door to take.
module PokeAccess
  module RebornRailcave
    MAP = 251
    DOORS = { 3 => 1, 2 => 2, 4 => 3, 1 => 4 }
    WORDS = { 1 => :rbd_rc_north, 2 => :rbd_rc_east, 3 => :rbd_rc_south, 4 => :rbd_rc_west }
    # The door the rails point to and the one the rocks gather at, for each count of variable 146.
    TABLE = {
      0 => [1, 4], 1 => [2, 0], 2 => [2, 0], 3 => [1, 0], 4 => [4, 0], 5 => [1, 0], 6 => [2, 0], 7 => [3, 0],
      8 => [2, 0], 9 => [1, 0], -1 => [0, 4], -2 => [0, 1], -3 => [0, 4], -4 => [0, 1], -5 => [0, 2],
      -6 => [0, 1], -7 => [0, 4], -8 => [0, 3], -9 => [0, 4]
    }
    STEPS = 10

    # The name of a door, by its side.
    def self.door(ev)
      [:rbd_rc_door, { :side => PokeAccess::I18n.t(WORDS[DOORS[ev.id]]) }]
    end

    # The count of doors walked through, up or down.
    def self.count
      $game_variables[146].to_i
    end

    # Where the rails point now, as drawn.
    def self.rails
      side = WORDS[$game_variables[147].to_i]
      side ? [:rbd_rc_rails, { :side => PokeAccess::I18n.t(side) }] : nil
    end

    # Which door the rocks gather at now, as drawn; nil while one stands by each door.
    def self.rocks
      side = WORDS[$game_variables[148].to_i]
      side ? [:rbd_rc_rocks, { :side => PokeAccess::I18n.t(side) }] : nil
    end

    # What the room shows: the rails and the rocks.
    def self.view
      parts = [rails, rocks].compact.map { |line| PokeAccess::Puzzles.label_of(line) }
      parts.empty? ? nil : PokeAccess.sentences(parts)
    end

    # The assisted hint: the door to take next, or the two ways at the start.
    def self.hint
      up, down = TABLE.fetch(count, [0, 0])
      return :rbd_rc_hint_start if count == 0
      side = count > 0 ? up : down
      return nil if side == 0
      [:rbd_rc_hint_next, { :side => PokeAccess::I18n.t(WORDS[side]), :n => count.abs + 1, :of => STEPS }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  rc = PokeAccess::RebornRailcave
  mechanic(:state, rc::MAP, :part => :rails) do
    auto
    name rc::DOORS.keys, lambda { |ev| rc.door(ev) }
    watch :var => 147, :say => lambda { rc.rails }
    watch :var => 148, :say => lambda { rc.rocks }
    watch :var => 146, :say => lambda { PokeAccess::Puzzles.assist? ? rc.hint : nil }
    info { rc.view }
    arrival_hint lambda { PokeAccess::Puzzles.assist? ? rc.hint : nil }
    active { PokeAccess::Puzzles.assist? || rc.view }
  end
end
