# Keishou's temple challenges on the map and Mr. Hyper's training in Sakyu Valley, all run by the maps' own events.
# Hanako's Kusa Sprint (Kusa Temple B1F, map 270): three trails, each a start line, a finish line and a parallel timer
# that waits 250, 230 and 200 (12.5, 11.5 and 10 seconds) before time is up, var 139 the tries left. Mei's Bounsweet Hunt
# (Kusa Temple B2F, 269): six Bounsweet (events 11 to 16, var 138 counting the found), with three pupils on patrol, a tile
# every 0.4 seconds, whose sight starts a battle (var 43 counts them; none fought, a reward). Nami's Carvanha Chase (Mizu Temple B1F, 271): three pools crossed while
# Carvanha swim at the player (self switch B on while a pool runs), var 142 the tries left; in the third, Bruxish
# (event 33) is led onto (43, 84). Mr. Hyper's training (Sakyu Valley, 133): three rocks to smash (var 81) before a
# timer waiting 200, then boulder 16 pushed onto (9, 40) before one waiting 470.
module PokeAccess
  module KeishouMini
    TRIES = 3
    # Kusa Sprint trails as [timer, start line, finish line].
    TRAILS = [[1, 9, 19], [28, 20, 27], [29, 39, 38]]
    # Bounsweet Hunt pupils on patrol.
    PUPILS = [17, 18, 19]
    # Seconds of a pupil's patrol the warning looks ahead: time to hear it and step aside.
    HORIZON = 2.0
    # Quarter-pixels to a tile, as Game_Map::REAL_RES_X counts them.
    TILE = 128.0
    # Facing => the word the step guide says it with.
    DIR_WORDS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    # Move route codes: a step down, left, right or up => the facing it leaves; a turn to face => that facing; a quarter
    # turn right or left or a half turn => facing before => facing after.
    STEPS = { 1 => 2, 2 => 4, 3 => 6, 4 => 8 }
    FACES = { 16 => 2, 17 => 4, 18 => 6, 19 => 8 }
    TURNS = { 20 => { 2 => 4, 4 => 8, 6 => 2, 8 => 6 }, 21 => { 2 => 6, 4 => 2, 6 => 8, 8 => 4 },
              22 => { 2 => 8, 4 => 6, 6 => 4, 8 => 2 } }
    # Carvanha Chase pools as [entrance, finish]; the third ends with Bruxish on its tile.
    POOLS = [[11, 12], [23, 24], [32, nil]]
    # Facing => one tile ahead, [dx, dy].
    AHEAD = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

    # A self switch of an event of the current map.
    def self.on?(id, letter)
      $game_self_switches[[$game_map.map_id, id, letter]] ? true : false
    end

    # Seconds the parallel timer event id of the current map has left before time is up: its page's whole wait while
    # its interpreter has not taken it yet, nil once it has run out.
    def self.left(id)
      ev = $game_map.events[id]
      return nil unless ev
      ip = PokeAccess.ivar(ev, :@interpreter)
      index = ip ? PokeAccess.ivar(ip, :@index).to_i : 0
      frames = ip ? PokeAccess.ivar(ip, :@wait_count).to_i : 0
      return frames / (frame_rate * speed) if index == 1 && frames > 0
      return nil unless index == 0
      cmd = (PokeAccess.ivar(ev, :@list) || [])[0]
      cmd && cmd.code == 106 ? cmd.parameters[0] / 20.0 / speed : nil
    end

    # True while timer event id runs: its self switch A on and time not yet up.
    def self.running?(id)
      on?(id, "A") && !left(id).nil?
    end

    def self.frame_rate
      (Graphics.frame_rate rescue 40).to_f
    end

    # How many frames the game runs to one of its normal pace (its Better Speed Up, as Turbo reads it), at least 1.
    def self.speed
      s = PokeAccess::Turbo.multiplier(PokeAccess::Turbo.current_speed).to_f
      s > 0 ? s : 1.0
    end

    # The time timer event id has left, in whole seconds, at least one.
    def self.time_text(id)
      n = (left(id) || 0).floor
      PokeAccess::I18n.t(:ks_mini_time_left, :n => n < 1 ? 1 : n)
    end

    # The try under way, from the tries left in var.
    def self.attempt(var)
      n = TRIES + 1 - $game_variables[var].to_i
      n < 1 ? 1 : (n > TRIES ? TRIES : n)
    end

    # A running trail's line: which, the try and the time left.
    def self.trail_line(n, timer)
      PokeAccess.sentences([PokeAccess::I18n.t(:ks_mini_trail_run, :n => n, :try => attempt(139), :of => TRIES),
                            time_text(timer)])
    end

    def self.pool_line(n)
      PokeAccess::I18n.t(:ks_mini_pool_run, :n => n, :try => attempt(142), :of => TRIES)
    end

    # True while the Bounsweet Hunt runs: Mei has told it and a Bounsweet is still hidden.
    def self.hunting?
      on?(10, "A") && $game_variables[138].to_i < 6
    end

    # One pulse of the hunt: for each pupil whose sight will take in the player's tile, or the one they face, within
    # HORIZON seconds of its patrol, says once what to do, cutting what is being said; again only once the threat
    # changes or after it passed.
    def self.tick
      @warned ||= {}
      return @warned.clear unless $game_map && $game_map.map_id == 269 && hunting?
      return unless PokeAccess::Control.free?
      sights = {}
      PUPILS.each { |id| sights[id] = sights_of($game_map.events[id], id) }
      PUPILS.each do |id|
        kind = threat(sights[id])
        PokeAccess.speak(advice(kind, sights), true) if kind && kind != @warned[id]
        @warned[id] = kind
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What pupil id will look along, as [the event, its sight, [x, y, facing] now, then those its patrol checks within
    # HORIZON]; nil once fought or gone.
    def self.sights_of(ev, id)
      return nil if ev.nil? || on?(id, "A")
      [ev, ev.name.to_s[/trainer\((\d+)\)/i, 1].to_i, [ev.x, ev.y, ev.direction], checks(ev)]
    end

    # :here when the pupil will see the player's tile, :ahead when only the one they face, nil when neither or when
    # it sees them already (the battle is the game's then).
    def self.threat(sight)
      return nil unless sight
      here = [$game_player.x, $game_player.y]
      front = PokeAccess::Control.front_tile
      return nil if sees?(sight, sight[2], here)
      return :here if sight[3].any? { |at| sees?(sight, at, here) }
      return :ahead if front != here && ([sight[2]] + sight[3]).any? { |at| sees?(sight, at, front) }
      nil
    end

    # The line for a threat: not to step on, or the way off the tile: back where the player came from, else to either
    # side of the pupil's look, else farther along it, the first tile that can be walked onto and that no sight takes in.
    def self.advice(kind, sights)
      return PokeAccess::I18n.t(:ks_mini_pupil_stop) if kind == :ahead
      here = [$game_player.x, $game_player.y]
      back = TURNS[22][$game_player.direction]
      ways = [back]
      sights.each_value do |s|
        at = s && s[3].find { |pt| sees?(s, pt, here) }
        next unless at
        ways.concat(at[2] == 2 || at[2] == 8 ? [4, 6, at[2]] : [8, 2, at[2]])
        break
      end
      way = ways.compact.find { |d| clear?(here, d, sights) }
      return PokeAccess::I18n.t(:ks_mini_pupil_back) if way.nil? || way == back
      PokeAccess::I18n.t(:ks_mini_pupil_dodge, :dir => PokeAccess::I18n.t(DIR_WORDS[way]))
    end

    # Whether the player can step from here toward dir onto a tile no pupil's sight takes in, now or within HORIZON.
    def self.clear?(here, dir, sights)
      return false unless $game_player.passable?(here[0], here[1], dir)
      to = [here[0] + AHEAD[dir][0], here[1] + AHEAD[dir][1]]
      sights.each_value { |s| return false if s && ([s[2]] + s[3]).any? { |at| sees?(s, at, to) } }
      true
    end

    # Whether a pupil's sight, from at ([x, y, facing]), takes in tile: in line within its range with nothing it
    # cannot cross between them, as the game's pbEventCanReachPlayer? reads it.
    def self.sees?(sight, at, tile)
      x, y, dir = at
      step = AHEAD[dir]
      return false unless step
      dx = tile[0] - x
      dy = tile[1] - y
      d = step[0] != 0 ? dx * step[0] : dy * step[1]
      return false unless d > 0 && d <= sight[1] && (step[0] != 0 ? dy == 0 : dx == 0)
      ev = sight[0]
      (d - 1).times do |i|
        next unless ev.respond_to?(:can_move_from_coordinate?)
        return false unless ev.can_move_from_coordinate?(x + i * step[0], y + i * step[1], dir)
      end
      true
    end

    # Where ev's patrol leaves it each time the game checks its sight within HORIZON seconds, as [x, y, facing]: the
    # end of each step and each turn, timed as Game_Character runs a custom route (a tile at its speed, its frequency's
    # pause after each step or turn, each wait), from where the route stands now and at the game's speed-up. A move
    # it picks by itself (random, toward the player) ends the reading.
    def self.checks(ev)
      route = PokeAccess.ivar(ev, :@move_route)
      list = route && PokeAccess.ivar(ev, :@move_type).to_i == 3 ? route.list : nil
      return [] unless list
      fr = frame_rate
      tile = (TILE / step_real(ev, fr)).ceil
      rest = rest_real(ev, fr)
      limit = HORIZON * fr * speed
      t = lead(ev, rest, fr)
      i = PokeAccess.ivar(ev, :@move_route_index).to_i
      x = ev.x
      y = ev.y
      dir = ev.direction
      out = []
      200.times do
        break if t > limit
        cmd = list[i]
        if cmd.nil? || cmd.code == 0
          break unless route.repeat
          i = 0
          t += 1
          next
        end
        i += 1
        code = cmd.code
        if STEPS[code] || code == 12
          dir = STEPS[code] || dir
          x += AHEAD[dir][0]
          y += AHEAD[dir][1]
          out.push([x, y, dir]) if t + tile <= limit
          t += tile + rest
        elsif FACES[code] || TURNS[code]
          dir = FACES[code] || TURNS[code][dir] || dir
          out.push([x, y, dir])
          t += 1 + rest
        elsif code == 15
          t += cmd.parameters[0].to_i * fr / 20.0
        elsif code <= 26
          break
        end
      end
      out
    end

    # Frames before ev takes its next route command: the rest of a wait, of a step and the pause after it, or of a
    # pause.
    def self.lead(ev, rest, fr)
      wait = PokeAccess.ivar(ev, :@wait_count).to_i
      return wait + 1 if wait > 0
      if ev.respond_to?(:moving?) && ev.moving?
        left = [(PokeAccess.ivar(ev, :@real_x).to_f - ev.x * TILE).abs, (PokeAccess.ivar(ev, :@real_y).to_f - ev.y * TILE).abs].max
        return (left / step_real(ev, fr)).ceil + rest
      end
      stop = PokeAccess.ivar(ev, :@stop_count).to_i
      rest > stop ? rest - stop : 0
    end

    # Quarter-pixels ev walks a frame: what Game_Character#move_speed= keeps, else worked out from its speed.
    def self.step_real(ev, fr)
      real = PokeAccess.ivar(ev, :@move_speed_real)
      return real.to_f if real && real.to_f > 0
      v = (PokeAccess.ivar(ev, :@move_speed) || 3).to_i
      (v == 6 ? 64 : (v == 5 ? 32 : (2**(v + 1)) * 0.8)) * 40.0 / fr
    end

    # Frames ev pauses after a step or a turn: what Game_Character#move_frequency= keeps, else worked out from its
    # frequency.
    def self.rest_real(ev, fr)
      real = PokeAccess.ivar(ev, :@move_frequency_real)
      return real.to_f if real
      f = (PokeAccess.ivar(ev, :@move_frequency) || 6).to_i
      (40 - f * 2) * (6 - f) * fr / 40.0
    end

    # Whether an entrance or finish event's live page is the one that starts or ends a pool: on with every letter in
    # on, off with the rest of A to D.
    def self.page?(id, on)
      %w[A B C D].all? { |l| on?(id, l) == on.include?(l) }
    end

    PokeAccess::Frame.each_pulse { PokeAccess::KeishouMini.tick } unless @pulsing
    @pulsing = true
  end
end

PokeAccess::Game.define("keishou") do
  mini = PokeAccess::KeishouMini

  mechanic(:state, 270, :part => :sprint) do
    auto
    mini::TRAILS.each_with_index do |trail, i|
      name trail[1], [:ks_mini_trail_start, { :n => i + 1 }]
      name trail[2], [:ks_mini_trail_goal, { :n => i + 1 }]
      phase lambda { mini.running?(trail[0]) }, :title => lambda { mini.trail_line(i + 1, trail[0]) }
    end
  end

  mechanic(:state, 269, :part => :hunt) do
    auto
    name 11..16, :ks_mini_bounsweet
    count :ks_mini_bounsweet_found, :var => 138, :of => 6
    phase lambda { mini.hunting? }, :quiet => true
  end

  mechanic(:state, 271, :part => :chase) do
    auto
    obstacle({ :events => [10, 18..22, 25..31, 36..42] }, :moving => true, :label => :ks_mini_carvanha)
    name 33, :ks_mini_bruxish
    mini::POOLS.each_with_index do |pool, i|
      first = i == 0 ? [] : ["D"]
      name pool[0], [:ks_mini_pool_entrance, { :n => i + 1 }], :when => lambda { |ev| mini.page?(ev.id, first) }
      name pool[1], [:ks_mini_pool_goal, { :n => i + 1 }], :when => lambda { |ev| mini.page?(ev.id, ["A"]) } if pool[1]
    end
    phase lambda { mini.on?(33, "B") }, :title => lambda { mini.pool_line(3) },
          :track => { :event => 33, :label => :ks_mini_bruxish, :goal => [43, 84, 43, 84], :goal_label => :ks_mini_bruxish_goal },
          :spots => [{ :at => [43, 84], :label => :ks_mini_bruxish_goal, :onto => true }]
    phase lambda { mini.on?(25, "B") }, :title => lambda { mini.pool_line(2) }
    phase lambda { mini.on?(10, "B") }, :title => lambda { mini.pool_line(1) }
  end

  mechanic(:state, 133, :part => :training) do
    auto
    name [3, 14, 15], :ks_mini_training_rock, :when => lambda { |ev| mini.on?(ev.id, "B") && !mini.on?(ev.id, "C") }
    phase lambda { mini.running?(19) }, :title => lambda { mini.time_text(19) },
          :progress => { :var => 81, :of => 3, :label => :ks_mini_rocks, :announce => true, :reset => false }
    phase lambda { mini.running?(20) }, :title => lambda { mini.time_text(20) },
          :track => { :event => 16, :label => :ks_mini_boulder, :goal => [9, 40, 9, 40], :goal_label => :ks_mini_boulder_goal },
          :spots => [{ :at => [9, 40], :label => :ks_mini_boulder_goal, :onto => true }]
  end
end
