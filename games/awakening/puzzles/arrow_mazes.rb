# The arrow mazes behind the Lens of Truth: the Fire shrine's maps 334 and 341 and the Empyrean's floor 560 (map 514).
# Six crossings each hold an arrow drawn only with the lens; at the end of each arm waits a hidden step that jumps
# elsewhere in the room or a trap that sends the player back to the start (map 334's way out at (8, 4) lands where its
# falls do, and is left out). The arrows' sheet (Flechas) draws, by the event's facing, a left, right, down or up
# arrow, orange in its first column and blue in its second; the blue ones point away from the way on. Each arrow is
# named as it is drawn while the lens is on; with the puzzle assist, the way on as well, and the routes keep off the
# traps.
module PokeAccess
  module AwakeningArrows
    # The way each facing of the sheet draws its arrow.
    DRAWN = { 2 => 4, 4 => 6, 6 => 2, 8 => 8 }
    # The opposite of each way.
    BACK = { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }
    # map => [the arrow events, the trap events]
    MAPS = { 334 => [(1..6).to_a, (14..30).to_a], 341 => [(7..12).to_a, (13..30).to_a],
             514 => [(1..6).to_a, (14..30).to_a] }

    # The arrow's spoken line: its colour and the way it points, and with the assist the way on.
    def self.label(ev)
      drawn = DRAWN[ev.direction] || 2
      column = PokeAccess.ivar(ev, :@original_pattern)
      column = PokeAccess.ivar(ev, :@pattern) if column.nil?
      blue = (column.to_i == 1)
      line = PokeAccess::I18n.t(:awk_arrow, :color => PokeAccess::I18n.t(blue ? :awk_arrow_blue : :awk_arrow_orange),
                                            :dir => PokeAccess::Puzzles.face_name(drawn))
      return line unless PokeAccess::Puzzles.assist?
      way = blue ? BACK[drawn] : drawn
      PokeAccess.sentences([line, PokeAccess::I18n.t(:awk_arrow_way, :dir => PokeAccess::Puzzles.face_name(way))])
    end
  end
end

PokeAccess::Game.define("awakening") do
  arrows = PokeAccess::AwakeningArrows
  arrows::MAPS.each do |map, (marks, traps)|
    mechanic(:state, map, :part => :arrows) do
      auto
      name marks, lambda { |ev| arrows.label(ev) }, :when => lambda { |_ev| PokeAccess::World::Lens.on? }
      avoid traps, :assist => true
      sent_back(:awk_maze_fall, :to => [8, 6], :events => traps) if map == 514
    end
  end

  mechanic(:state, 324, :part => :arrows) do
    auto
    sent_back :awk_maze_fall, :maps => [334], :to => [30, 39], :from => [9, 64, 0, 39]
    sent_back :awk_maze_fall, :maps => [334], :to => [30, 39], :from => [0, 8, 5, 39]
  end

  mechanic(:state, 337, :part => :arrows) do
    auto
    sent_back :awk_maze_fall, :maps => [341], :to => [9, 11]
  end
end
