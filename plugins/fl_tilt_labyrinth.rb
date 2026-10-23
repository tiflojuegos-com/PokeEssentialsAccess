# FL's Tilt Labyrinth (TiltLabyrinth::Scene, the original plugin and Royal's copy): a tone toward the goal while the ball
# rolls, the opening, the holes and the end, and the info key's time, balls and goal.
module PokeAccess
  module FLTilt
    # Seconds between the goal's tones while the ball stays on its tile, and the seconds left that are said.
    PERIOD = 0.4
    WARNINGS = [30, 10, 5]

    # The goal sounds from the middle while it lies within SIDE_MIN tiles across, or that share of its distance.
    SIDE_MIN = 0.5
    SIDE_RATIO = 0.2

    # The time the game paints, and the pre-panned chime of each side.
    TIME = /\A\d+:\d\d\z/
    GUIDE = { :left => "pa_guide_l", :center => "pa_guide_c", :right => "pa_guide_r" }

    # The four tiles a ball rolls to from one.
    STEPS = [[1, 0], [-1, 0], [0, 1], [0, -1]]

    # What the reader keeps on the scene: the painted time and balls, the tone's tile and clock, the seconds left and the
    # labyrinth's route map with the longest way in it.
    Run = Struct.new(:time_text, :balls_text, :tile, :tone_at, :remaining, :route, :reach)

    @scene = nil

    # Holds the scene while its loop runs, for the per-frame tone; its info line leaves with it.
    def self.playing(scene)
      prev = @scene
      @scene = scene
      yield
    ensure
      @scene = prev
      PokeAccess::Info.clear_text
    end

    # What the reader keeps on a scene.
    def self.state(scene)
      PokeAccess.ivar(scene, :@access_tilt) || scene.instance_variable_set(:@access_tilt, Run.new)
    end

    # The game's screen of a scene, or nil.
    def self.screen_of(scene); PokeAccess.ivar(scene, :@screen); end

    # The board of a scene's screen, or nil.
    def self.board_of(scene)
      s = screen_of(scene)
      s ? s.board : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The ball on the board, or nil once it has reached the goal.
    def self.ball_of(scene)
      b = board_of(scene)
      b ? b.ball : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Keeps what draw_text painted: the time ("1:05") and, with a ball limit, the balls as the game words them.
    # param rows the painted rows as PaintCapture.sample gives them
    def self.painted(scene, rows)
      texts = rows.map { |r| PokeAccess.clean(r[0]) }.reject { |t| t.empty? }
      time = texts.find { |t| t =~ TIME }
      balls = texts.find { |t| t != time }
      run = state(scene)
      run.time_text = time if time
      run.balls_text = balls if balls
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True when the game runs against a time limit.
    def self.timed?(scene)
      screen_of(scene).has_time_limit? ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Says the opening, queued: the time of a timed game, the balls, where the goal lies and, with hints, how to play.
    def self.opened(scene)
      run = state(scene)
      across, down = bearing(scene)
      hint = PokeAccess::Verbosity.hints? ? PokeAccess::I18n.t(:tilt_hint) : nil
      PokeAccess.speak(PokeAccess.sentences([timed?(scene) ? time_line(scene, run) : nil, run.balls_text,
                                             across ? goal_line(across, down) : nil, hint]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Where the goal lies from the ball as the screen shows it, the board's turn included: [across, down, straight], the
    # offsets in tiles (right and down positive) and the straight distance; nil without a ball.
    def self.bearing(scene)
      board = board_of(scene)
      pos = board.ball.grid_pos
      goal = target(scene, board.labyrinth, pos)
      dx = goal[0] - pos[0]
      dy = goal[1] - pos[1]
      turn = board.angle.to_f * Math::PI / 180.0
      [dx * Math.cos(turn) + dy * Math.sin(turn), dy * Math.cos(turn) - dx * Math.sin(turn), Math.sqrt(dx * dx + dy * dy)]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The exit the ball's way leads to, else the nearest in a straight line.
    def self.target(scene, lab, pos)
      known = route(scene)[[pos[0].round, pos[1].round]]
      return lab.exit_pos_array[known[1]] if known
      lab.exit_pos_array.min_by { |e| (e[0] - pos[0]) ** 2 + (e[1] - pos[1]) ** 2 }
    end

    # The labyrinth's route map, drawn the first time it is asked.
    def self.route(scene)
      run = state(scene)
      unless run.route
        run.route = route_map(board_of(scene).labyrinth)
        run.reach = run.route.values.map { |v| v[0] }.max.to_f
      end
      run.route
    end

    # Every tile the ball can roll to as [steps to the nearest exit, which exit], walls and holes left out, found by
    # spreading from the exits.
    def self.route_map(lab)
      holes = {}
      lab.hole_pos_array.each { |h| holes[[h[0], h[1]]] = true }
      map = {}
      queue = []
      lab.exit_pos_array.each_with_index do |e, i|
        map[[e[0], e[1]]] = [0, i]
        queue.push([e[0], e[1]])
      end
      until queue.empty?
        x, y = queue.shift
        steps, gate = map[[x, y]]
        STEPS.each do |dx, dy|
          t = [x + dx, y + dy]
          next if map.key?(t) || holes[t] || !lab.passable?(t[0], t[1])
          map[t] = [steps + 1, gate]
          queue.push(t)
        end
      end
      map
    end

    # How near the goal the ball is, 0.0 as far as the labyrinth reaches to 1.0 on it: by the way it rolls, or in a
    # straight line where no way leads from its tile.
    def self.closeness(scene, straight)
      lab = board_of(scene).labyrinth
      pos = ball_of(scene).grid_pos
      steps = route(scene)[[pos[0].round, pos[1].round]]
      far = steps ? state(scene).reach : Math.sqrt(lab.width * lab.width + lab.height * lab.height)
      gone = steps ? steps[0] : straight
      far > 0 ? 1.0 - [gone.to_f / far, 1.0].min : 1.0
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The side the goal sounds from: where it lies across the screen, the middle when it is nearly in line.
    def self.side(across, straight)
      dead = [SIDE_MIN, SIDE_RATIO * straight].max
      return :center if across.abs <= dead
      across < 0 ? :left : :right
    end

    # The goal's tone: higher the nearer, from its side, at the minigame's volume.
    def self.tone(closeness, side)
      pitch = PokeAccess::Sound::GAUGE_LOW + (closeness * PokeAccess::Sound::GAUGE_SPAN).to_i
      PokeAccess::Sound::Flat.play(GUIDE[side], PokeAccess::Sound::Mixer.volume(:minigame), pitch)
    end

    # The legs from the ball to the goal as [direction word, tiles], the longer first, the vertical one first when equal;
    # a leg that rounds to no tile is left out.
    def self.legs(across, down)
      h = across.round
      v = down.round
      out = []
      out.push([v < 0 ? :dir_up : :dir_down, v.abs]) unless v == 0
      out.push([h < 0 ? :dir_left : :dir_right, h.abs]) unless h == 0
      out.reverse! if out.length == 2 && out[1][1] > out[0][1]
      out
    end

    # Where the goal lies in the mod's words for directions, one leg after the other.
    def self.goal_line(across, down)
      parts = legs(across, down)
      return PokeAccess::I18n.t(:tilt_goal_close) if parts.empty?
      where = parts.map { |dir, n| PokeAccess::I18n.t(:tilt_leg, :dir => PokeAccess::I18n.t(dir), :n => n) }.join("; ")
      PokeAccess::I18n.t(:tilt_goal, :where => where)
    end

    # The painted time under its label: the time left of a timed game, else the time spent.
    def self.time_line(scene, run)
      return nil unless run.time_text
      if timed?(scene)
        PokeAccess::I18n.t(:tilt_time_left, :t => run.time_text)
      else
        PokeAccess::I18n.t(:tilt_time_spent, :t => run.time_text)
      end
    end

    # The info key's line: the time, the balls as painted and where the goal lies.
    def self.status(scene, run, across, down)
      PokeAccess.sentences([time_line(scene, run), run.balls_text, goal_line(across, down)])
    end

    # True while a message (the exit question) is on the screen, which a tone would talk over.
    def self.prompt?
      PokeAccess::Control.flag($game_temp, :message_window_showing)
    end

    # Says the seconds left as each of WARNINGS is crossed while a time limit runs.
    def self.warn_time(scene, run)
      screen = screen_of(scene)
      return unless screen.has_time_limit?
      left = screen.max_time - screen.time_count
      was = run.remaining
      run.remaining = left
      return unless was
      WARNINGS.each do |n|
        PokeAccess.speak(PokeAccess::I18n.t(:tilt_warn, :n => n), true) if was > n && left <= n
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # One pulse of the loop: the time's warnings, and the goal's tone and the info line when the ball has reached a new
    # tile or PERIOD seconds have passed.
    def self.poll
      scene = @scene
      return unless scene && !prompt?
      run = state(scene)
      warn_time(scene, run)
      pos = ball_of(scene).grid_pos
      tile = [pos[0].round, pos[1].round]
      now = PokeAccess.clock
      return unless run.tone_at.nil? || tile != run.tile || now - run.tone_at >= PERIOD
      run.tile = tile
      run.tone_at = now
      guide(scene, run)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Sounds the goal's tone and keeps the info key's line current.
    def self.guide(scene, run)
      across, down, straight = bearing(scene)
      return unless across
      near = closeness(scene, straight)
      tone(near, side(across, straight)) if near
      PokeAccess::Info.set_info(:text, status(scene, run, across, down))
    end

    # The ball into a hole, as the game plays its drop: the balls left as painted, cutting in. The last ball's fall is the
    # end, said by finished.
    def self.sounds(scene)
      ball = ball_of(scene)
      return unless ball && ball.at_hole_this_frame
      return if screen_of(scene).ball_limit_triggered?
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:tilt_hole), state(scene).balls_text]), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # How the loop ended: the goal, the time or the balls running out; nil for an exit the player chose.
    def self.ending(screen)
      return PokeAccess::I18n.t(:tilt_win) if screen.completed
      return PokeAccess::I18n.t(:tilt_time_up) if screen.time_limit_triggered?
      screen.ball_limit_triggered? ? PokeAccess::I18n.t(:tilt_no_balls) : nil
    end

    # Says how the loop ended, cutting in; the game ends silently.
    def self.finished(scene)
      text = ending(screen_of(scene))
      PokeAccess.speak(text, true) if text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("TiltLabyrinth::Scene", :start, :optional => true) do |scene, nxt, _a|
  r = nxt.call
  PokeAccess::FLTilt.opened(scene)
  r
end
PokeAccess::Hooks.around_hook("TiltLabyrinth::Scene", :draw_text, :optional => true) do |scene, nxt, _a|
  r = nil
  rows = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLTilt.painted(scene, rows)
  r
end
PokeAccess::Hooks.around_hook("TiltLabyrinth::Scene", :main, :optional => true) do |scene, nxt, _a|
  r = PokeAccess::FLTilt.playing(scene) { nxt.call }
  PokeAccess::FLTilt.finished(scene)
  r
end
PokeAccess::Hooks.after_hook("TiltLabyrinth::Scene", :update_sounds, :optional => true) do |scene, _r, _a|
  PokeAccess::FLTilt.sounds(scene)
end
PokeAccess::Frame.each_pulse { PokeAccess::FLTilt.poll }
