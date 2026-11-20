# Route 19's surf race (map 56): from the rival's "GO" (switch 619) to the finish, the player hears each lap as the line
# counts it (variable 26, two laps), a crossing the wrong way, who leads, and each turn of the course two tiles before
# it, cutting whatever is being said and with the turn after it when that one comes within two tiles more. The course
# is the rival's own move route (event 19, page 2): the rival's place on it is the step it has reached, and the
# player's the nearest point of it a little ahead of the last one. The lap and the lead stay on the info key.
module PokeAccess
  module IFSurfRace
    MAP = 56
    RACING = 619
    LAP_VAR = 26
    LAPS = 2
    RIVAL = 19
    LEAD = 2
    TURN_AHEAD = 2
    BACK = 3
    WINDOW = 12
    NEAR = 6
    STEPS = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1] }
    WORDS = { [0, 1] => :dir_down, [-1, 0] => :dir_left, [1, 0] => :dir_right, [0, -1] => :dir_up }

    @state = nil

    # Per-frame entry point: follows the race while it runs on its map, and forgets it after.
    def self.poll
      return reset unless $game_map && $game_map.map_id == MAP && $game_switches[RACING]
      rival = $game_map.events[RIVAL]
      @state ||= start(rival) if rival
      return unless @state
      tile = [$game_player.x, $game_player.y]
      if tile != @state[:tile]
        @state[:tile] = tile
        follow(tile)
        turn
      end
      laps
      lead(rival)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The course once the rival runs its race route: its points from the rival's place in the editor, and for each
    # command of the route the point reached before it; nil while the route is not the race's yet.
    def self.start(rival)
      return nil unless PokeAccess.ivar(rival, :@move_type) == 3
      list = (PokeAccess.ivar(rival, :@move_route).list rescue nil)
      rpg = PokeAccess.ivar(rival, :@event)
      return nil unless list.is_a?(Array) && rpg
      path = [[rpg.x, rpg.y]]
      before = []
      list.each do |c|
        before.push(path.length - 1)
        step = STEPS[(c.code rescue 0)]
        path.push([path[-1][0] + step[0], path[-1][1] + step[1]]) if step
      end
      before.push(path.length - 1)
      { :path => path, :before => before, :prog => 0, :laps => $game_variables[LAP_VAR].to_i, :lead => nil,
        :turned => -1, :tile => nil }
    end

    # Forgets a finished or abandoned race and its line on the info key.
    def self.reset
      return unless @state
      @state = nil
      PokeAccess::Info.clear_text
    end

    # Says each lap as the line counts it, or a crossing the wrong way.
    def self.laps
      n = $game_variables[LAP_VAR].to_i
      return if n == @state[:laps]
      up = n > @state[:laps]
      @state[:laps] = n
      if !up
        PokeAccess.speak(PokeAccess::I18n.t(:if_sr_back), false)
      elsif n.between?(1, LAPS)
        PokeAccess.speak(PokeAccess::I18n.t(:if_sr_lap, :n => n, :total => LAPS), false)
      end
      publish
    end

    # Moves the player's place to the nearest point of the course from a little behind to a little ahead of it, when
    # one is close enough.
    def self.follow(tile)
      path = @state[:path]
      lo = [@state[:prog] - BACK, 0].max
      hi = [@state[:prog] + WINDOW, path.length - 1].min
      best = (lo..hi).min_by { |k| (path[k][0] - tile[0]).abs + (path[k][1] - tile[1]).abs }
      return unless best
      @state[:prog] = best if (path[best][0] - tile[0]).abs + (path[best][1] - tile[1]).abs <= NEAR
    end

    # The rival's place on the course: the point reached before the command its route runs.
    def self.rival_place(rival)
      before = @state[:before]
      before[[PokeAccess.ivar(rival, :@move_route_index).to_i, before.length - 1].min]
    end

    # Says who leads once the gap reaches LEAD points, and each change after.
    def self.lead(rival)
      gap = @state[:prog] - rival_place(rival)
      side = gap >= LEAD ? :if_sr_ahead : (gap <= -LEAD ? :if_sr_behind : nil)
      return if side.nil? || side == @state[:lead]
      @state[:lead] = side
      PokeAccess.speak(PokeAccess::I18n.t(side), false)
      publish
    end

    # The direction from point k of the course to the next, or nil at its end.
    def self.heading(k)
      path = @state[:path]
      return nil if k + 1 >= path.length
      [path[k + 1][0] - path[k][0], path[k + 1][1] - path[k][1]]
    end

    # Says the course's next turn once, when it comes within TURN_AHEAD points of the player's place, joined with the
    # turn after it when that one follows within TURN_AHEAD points; it cuts what is being said.
    def self.turn
      k = @state[:prog]
      now = heading(k)
      (1..TURN_AHEAD).each do |n|
        j = k + n
        dir = heading(j)
        next if dir.nil? || dir == now
        return if j <= @state[:turned]
        line = turn_words(dir, n)
        after = next_turn(j)
        if after
          line = PokeAccess::I18n.t(:if_sr_then, :first => line, :second => turn_words(heading(after), after - j))
          j = after
        end
        @state[:turned] = j
        return PokeAccess.speak(line, true)
      end
    end

    # The turn after the one at point j, within TURN_AHEAD points of it, or nil.
    def self.next_turn(j)
      dir = heading(j)
      (1..TURN_AHEAD).each do |m|
        h = heading(j + m)
        return nil if h.nil?
        return j + m if h != dir
      end
      nil
    end

    # A turn as said: its direction and how many tiles before it.
    def self.turn_words(dir, n)
      PokeAccess::I18n.t(:if_sr_turn, :dir => PokeAccess::I18n.t(WORDS[dir]), :n => n)
    end

    # The race's line on the info key: the lap and who leads.
    def self.publish
      parts = []
      n = @state[:laps]
      parts.push(PokeAccess::I18n.t(:if_sr_lap, :n => n, :total => LAPS)) if n.between?(1, LAPS)
      parts.push(PokeAccess::I18n.t(@state[:lead])) if @state[:lead]
      PokeAccess::Info.set_info(:text, PokeAccess.sentences(parts)) unless parts.empty?
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  poll_each_frame { PokeAccess::IFSurfRace.poll }
end
