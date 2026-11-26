# Room II of the Eastridge Escape Room (map 136): six alike rooms, five with three doors with no graphic (left, top and
# right of a crossing), each opening only while its key is held. The right doors are left, right, up, left and left; the
# sixth room holds the way out (event 24).
module PokeAccess
  module AshenDoorRoom
    MAP = 136
    DOORS = { 9 => :left, 10 => :up, 11 => :right, 12 => :left, 13 => :up, 14 => :right, 15 => :left, 16 => :up,
              17 => :right, 18 => :left, 19 => :right, 20 => :up, 21 => :left, 22 => :up, 23 => :right }
    LABELS = { :left => :afg_er2_door_left, :up => :afg_er2_door_up, :right => :afg_er2_door_right }
    # Each room with a choice, as [x0, x1, y0, y1], its right door and the hint said in it.
    ROOMS = [[[3, 9, 4, 12], 9, :afg_er2_left], [[20, 28, 4, 12], 14, :afg_er2_right], [[39, 50, 4, 12], 16, :afg_er2_up],
             [[0, 11, 23, 31], 18, :afg_er2_left], [[20, 28, 23, 31], 21, :afg_er2_left]]

    # A door's name, by the side of the crossing it stands on.
    def self.label(ev)
      side = DOORS[ev.id]
      side ? LABELS[side] : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  dr = PokeAccess::AshenDoorRoom
  mechanic(:state, dr::MAP, :part => :doors) do
    auto
    name dr::DOORS.keys, lambda { |ev| dr.label(ev) }
    arrival_hint :afg_er2_rule
    dr::ROOMS.each do |room|
      box = at(*room[0])
      phase lambda { PokeAccess::Puzzles.assist? && box.call }, :hint => room[2], :hidden => right_way(room[1])
    end
    phase lambda { true }
  end
end
