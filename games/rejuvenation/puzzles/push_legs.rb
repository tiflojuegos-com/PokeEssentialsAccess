# Push plans written as legs, for the rooms whose pieces move one tile per push (The Three Trials' statues, the stones
# of Aquamarine Depths): from where a piece stands on its planned path, what is left to push, each leg said as how many
# pushes, which way and where the player stands for its first. Off the path, the room's way to put the pieces back.
module PokeAccess
  module RejuvPushLegs
    STEPS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    WORDS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # The legs left from at on the path from start, each [direction, pushes, x, y the player stands on]; nil off it.
    def self.left(start, legs, at)
      x, y = start
      legs.each_with_index do |(dir, n), i|
        dx, dy = STEPS[dir]
        n.times do |k|
          return [[dir, n - k, x - dx, y - dy]].concat(after(legs, i + 1, x + dx * (n - k), y + dy * (n - k))) if [x, y] == at
          x += dx
          y += dy
        end
      end
      [x, y] == at ? [] : nil
    end

    # The whole legs from index i on, the piece standing at (x, y) as the first starts.
    def self.after(legs, i, x, y)
      legs[i..-1].map do |dir, n|
        dx, dy = STEPS[dir]
        leg = [dir, n, x - dx, y - dy]
        x += dx * n
        y += dy * n
        leg
      end
    end

    # Where an event stands, or nil.
    def self.at(id)
      ev = $game_map.events[id]
      ev ? [ev.x, ev.y] : nil
    end

    # A piece's hint: where it goes and, on its path, the pushes left; off it, reset (a label) tells how to start over.
    # piece is [event, start, goal, legs, its label, its goal's label].
    def self.hint(piece, reset)
      id, start, goal, legs, label, goal_label = piece
      head = PokeAccess::I18n.t(:rj_push_goal, :name => PokeAccess::Puzzles.label_of(label),
                                               :goal => PokeAccess::Puzzles.label_of(goal_label), :x => goal[0], :y => goal[1])
      rest = left(start, legs, at(id))
      return PokeAccess.sentences([head, PokeAccess::Puzzles.label_of(reset)]) if rest.nil?
      PokeAccess.sentences([head].concat(rest.map do |dir, n, x, y|
        PokeAccess::I18n.t(:rj_push_leg, :n => n, :dir => PokeAccess::I18n.t(WORDS[dir]), :x => x, :y => y)
      end))
    end
  end
end
