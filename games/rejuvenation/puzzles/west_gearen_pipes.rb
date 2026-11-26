# West Gearen's sewage plant (map 415): three pipes (events 98, 109, 112) move one tile away from the player when used,
# with the lower level on (switch 2125). The terminals check them and, with the water up (variable 969 at 0), give the
# Murkwater field notes. A wild Muk sits on each until beaten or caught; the south exits put the pipes back.
module PokeAccess
  module RejuvPipes
    MAP = 415
    PIPES = [98, 109, 112]
    START = { 98 => [21, 139], 109 => [22, 130], 112 => [23, 129] }
    GOALS = { 98 => [24, 139], 109 => [18, 131], 112 => [25, 129] }
    MUKS = { 98 => 131, 109 => 132, 112 => 133 }
    DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # [pipe, the way it moves], in order.
    PLAN = [[98, 2], [98, 6], [98, 6], [98, 6], [98, 8], [109, 2], [109, 4], [109, 4], [109, 4], [109, 4], [112, 6],
            [112, 6]]

    # The pipes' tiles before each push of the plan => [index of the push, the pipe's tile then].
    def self.states
      @states ||= begin
        pos = {}
        START.each { |id, xy| pos[id] = xy }
        out = {}
        PLAN.each_with_index do |(id, dir), i|
          out[PIPES.map { |p| pos[p] }] = [i, pos[id]]
          dx, dy = DIRS[dir]
          pos[id] = [pos[id][0] + dx, pos[id][1] + dy]
        end
        out
      end
    end

    # True once a terminal has given the field notes.
    def self.done?
      [134, 135].any? { |id| $game_self_switches[[MAP, id, "A"]] }
    end

    # The pipes' tiles as they stand, or nil without all three.
    def self.tiles
      evs = PIPES.map { |id| $game_map.events[id] }
      evs.include?(nil) ? nil : evs.map { |ev| [ev.x, ev.y] }
    end

    # A Muk still on a pipe's tile.
    def self.muk_left?
      MUKS.values.any? { |id| !$game_self_switches[[MAP, id, "A"]] }
    end

    # What the assist says now: the Muk first, then the next push, the terminal once all are in, or the way back.
    def self.step
      t = tiles
      return nil if t.nil? || done?
      return :muk if muk_left?
      return :terminal if t == PIPES.map { |id| GOALS[id] }
      s = states[t]
      s ? s[0] : :reset
    end

    # The line of the push at index i: which pipe, which way, and from where the player uses it.
    def self.push_line(i)
      id, dir = PLAN[i]
      [:rje_pipes_push, { :n => PIPES.index(id) + 1, :dir => PokeAccess::Puzzles.face_name(dir),
                          :from => PokeAccess::Puzzles.face_name(10 - dir) }]
    end

    # The terminal's line: the water has to be up first.
    def self.terminal_line
      $game_variables[969].to_i == 0 ? :rje_pipes_terminal : :rje_pipes_water
    end

    # The tile the player uses the pipe of push i from.
    def self.stand(i)
      id, dir = PLAN[i]
      xy = states.values.find { |k, _| k == i }[1]
      dx, dy = DIRS[dir]
      [xy[0] - dx, xy[1] - dy]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  pipes = PokeAccess::RejuvPipes
  mechanic(:state, pipes::MAP, :part => :pipes) do
    auto
    name pipes::PIPES, lambda { |ev| [:rje_pipes_pipe, { :n => pipes::PIPES.index(ev.id) + 1 }] }
    name [134, 135], :rje_pipes_console
    pipes::GOALS.each do |id, xy|
      spot :at => xy, :label => [:rje_pipes_goal, { :n => pipes::PIPES.index(id) + 1 }], :onto => true, :assist => true,
           :when => lambda { !pipes.done? }
    end
    avoid [122, 127, 129], :assist => true
    phase(lambda { PokeAccess::Puzzles.assist? && pipes.step == :muk }, :title => :rje_pipes_muk)
    phase(lambda { PokeAccess::Puzzles.assist? && pipes.step == :terminal }, :title => lambda { pipes.terminal_line })
    phase(lambda { PokeAccess::Puzzles.assist? && pipes.step == :reset }, :title => :rje_pipes_reset)
    pipes::PLAN.each_index do |i|
      phase(lambda { PokeAccess::Puzzles.assist? && pipes.step == i }, :title => lambda { pipes.push_line(i) })
      spot :at => pipes.stand(i), :label => :rje_pipes_push_from, :onto => true, :assist => true,
           :when => lambda { pipes.step == i }
    end
    solved(nil, :quiet => true) { pipes.done? }
  end
end
