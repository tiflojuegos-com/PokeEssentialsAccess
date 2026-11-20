# Tunia's hacking (Tuniatruco 1 to 12): a terminal hacked with Tunia leads to a level where the player walks to a breach
# with no sprite (event touch) while marcianitos on fixed rounds send them back to the start on touching them. The five
# levels of Viejo Roble Radiante add to var 114, whose teleporter (map 140) works at 5; the four of the Black Rose
# Tower's laboratory add to var 124, which a counter on its wall (map 247) shows and its way on waits at 4.
# With the puzzle assist, each level has stations: stopped on one, the player hears the way on to the next and, where
# that way crosses the marcianitos' rounds, to wait until a start keeps clear of them, then to go; a tight crossing
# says so, and walking onto a spot with a round right past it, stop.
module PokeAccess
  module RevivalHack
    # Level map => [the breach's event, the start the marcianitos send the player back to].
    LEVELS = { 15 => [1, [16, 22]], 16 => [1, [14, 22]], 17 => [1, [14, 22]], 158 => [1, [14, 24]],
               159 => [2, [14, 24]], 160 => [1, [20, 25]], 161 => [1, [20, 24]], 162 => [1, [19, 23]],
               248 => [1, [21, 36]], 249 => [1, [8, 38]], 250 => [1, [29, 36]], 251 => [1, [29, 36]] }
    # Level map => its stations in walking order, from the start: [x, y, the way on to the next station (the last
    # onto the breach) as legs [direction code, tiles], the start window in seconds the go cue keeps clear, or nil for
    # a way that crosses no round], planned against each level's rounds at the pace and margins below. Each way is
    # then spelled out a direction code a step.
    STATIONS = {
      15 => [[16, 22, [[8, 3]], nil], [16, 19, [[8, 1], [4, 2], [8, 10]], 0.75]],
      16 => [[14, 22, [[8, 3], [4, 2], [8, 3]], 0.75], [12, 16, [[8, 1], [6, 2], [8, 3]], 0.75],
             [14, 12, [[8, 4]], 0.75]],
      17 => [[14, 22, [[8, 14]], 0.75]],
      158 => [[14, 24, [[8, 7]], 0.75], [14, 17, [[8, 9]], 0.75]],
      159 => [[14, 24, [[8, 2], [6, 1], [8, 1]], 0.75],
              [15, 21, [[2, 1], [6, 3], [8, 4], [4, 1]], 0.07], [17, 18, [[6, 1], [8, 4], [4, 1]], 0.75],
              [17, 14, [[6, 1], [8, 4], [4, 3], [2, 1]], 0.07], [15, 11, [[8, 1], [4, 1], [8, 2]], 0.75]],
      160 => [[20, 25, [[8, 2], [6, 2], [8, 6], [4, 1]], 0.75], [21, 17, [[6, 1], [8, 6], [4, 1]], 0.75],
              [21, 11, [[6, 1], [8, 3], [4, 8]], 0.75]],
      161 => [[20, 24, [[8, 2], [4, 3], [8, 6]], 0.75], [17, 16, [[8, 2]], 0.75], [17, 14, [[8, 6], [4, 3]], nil]],
      162 => [[19, 23, [[8, 9]], 0.75], [19, 14, [[8, 6], [4, 5]], nil]],
      248 => [[21, 36, [[8, 4]], nil], [21, 32, [[8, 1], [4, 4], [8, 1]], 0.75],
              [17, 30, [[2, 1], [4, 4], [8, 8]], 0.75], [13, 23, [[8, 1], [6, 2], [8, 1]], 0.75],
              [15, 21, [[2, 1], [6, 3], [2, 1]], 0.75], [18, 23, [[2, 1], [6, 8], [8, 1]], 0.75],
              [26, 23, [[8, 6], [4, 5], [8, 3], [4, 5], [8, 5]], nil]],
      249 => [[8, 38, [[6, 4]], nil], [12, 38, [[6, 4], [8, 1]], 0.75],
              [16, 37, [[2, 1], [6, 3], [8, 4], [4, 1]], 0.48], [18, 34, [[6, 1], [8, 8]], 0.75],
              [19, 26, [[8, 1], [6, 5], [8, 5], [4, 1]], 0.75], [23, 20, [[6, 3], [8, 10]], 0.75]],
      250 => [[29, 36, [[8, 2], [4, 10], [8, 7], [6, 3], [8, 1]], 0.75],
              [22, 26, [[2, 1], [6, 3], [2, 4], [6, 5], [8, 3], [6, 1]], 0.75],
              [31, 28, [[4, 1], [8, 7], [4, 11], [2, 1]], 0.75],
              [19, 22, [[8, 1], [4, 3], [2, 3], [4, 2], [2, 3], [4, 1]], 0.75],
              [13, 27, [[6, 1], [2, 6], [4, 6], [8, 3], [6, 1]], 0.75],
              [9, 30, [[4, 1], [8, 12], [6, 5], [8, 3], [6, 4], [8, 1]], 0.75],
              [17, 14, [[2, 1], [6, 4], [8, 4], [4, 5], [8, 4]], 0.75]],
      251 => [[29, 36, [[8, 4], [4, 11], [8, 5]], nil], [18, 27, [[8, 1], [4, 1]], 0.75],
              [17, 26, [[4, 4], [8, 13]], nil], [13, 13, [[8, 4], [4, 4]], 0.35]]
    }
    STATIONS.each_value { |list| list.each { |s| s[2] = s[2].map { |d, n| [d] * n }.flatten } }
    # Seconds a tile takes at the walking pace (the level takes the running shoes away).
    PACE = 0.25
    # The soonest a start follows the go cue, and what each turn of the way may add, in seconds.
    REACTION = 0.25
    TURN = 0.2
    # Seconds kept clear of a marcianito on each side of its stay on a tile.
    MARGIN = 0.05
    # The frame each step or wait may run over: the engine ends one on the first frame past its time.
    FRAME = 1.0 / 60
    # Move route command => the step it takes, [dx, dy].
    MOVES = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1] }
    # Direction code => [dx, dy].
    DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # Level map => the waiting spots with a round one step past them, the way the player walks in: on the way in,
    # stop is said in time to stop on them or on the tile before, which waits as they do.
    BRAKES = { 15 => [[16, 19]], 16 => [[12, 16], [14, 12]], 158 => [[14, 17]], 161 => [[17, 16]],
               248 => [[21, 32], [13, 23]], 249 => [[12, 38], [19, 26]], 251 => [[18, 27], [13, 13]] }
    # Seconds left before the step onto a braking spot starts when stop is said: a held key let go 0.25 to 0.75
    # seconds after stops the player on the spot or on the tile before.
    BRAKE_LEAD = 0.5
    # A go window shorter than this, in seconds, makes a tight crossing, said on arriving to wait for it.
    TIGHT = 0.5
    # Legs from which a crossing's way is said with its first wait, and its go alone.
    LONG = 4
    # Seconds after coming onto a station before a go: at least HOLD_MIN, then until what the mod has sent has been
    # heard, but no more than HOLD_MAX past the last line it sent.
    HOLD_MIN = 0.3
    HOLD_MAX = 10.0
    # Characters a second a reader takes at a slow default rate, and the seconds each line adds: when it cannot tell
    # whether it still talks, what it was sent is taken as heard by then.
    READ_CPS = 12.0
    READ_GAP = 0.3
    # Level map => [[a braking spot, the direction the player walks onto it, the tile before as a station of its own,
    # one step longer; a tight window a MARGIN shorter for the step more]].
    APPROACHES = {}
    BRAKES.each do |map, spots|
      APPROACHES[map] = spots.map do |x, y|
        list = STATIONS[map]
        here = list.find { |s| s[0] == x && s[1] == y }
        d = list[list.index(here) - 1][2].last
        window = here[3] < TIGHT ? here[3] - MARGIN : here[3]
        [here, d, [x - DELTA[d][0], y - DELTA[d][1], [d] + here[2], window]]
      end
    end

    # One pulse: stopped on a new station, its way on, or on a crossing wait; go once a start keeps clear of the
    # marcianitos; a go not taken within its window turns back into wait. Nothing before a map frame has run on the
    # station, so what the mod says of the move that brought the player there comes first, nor a go before that has
    # been heard (settled?). Before all, stop on the way onto a braking spot.
    def self.tick
      follow
      brake
      here = station
      return @stay = nil unless here
      unless @stay && @stay[:station].equal?(here)
        @stay = { :station => here, :frame => PokeAccess::Frame.serial, :since => clock }
      end
      return if PokeAccess::Frame.serial == @stay[:frame]
      return lead(here) unless here[3]
      @stay[:heard] = true if @stay[:told] && !@stay[:cut] && read?(@stay[:told])
      room = slack(here)
      if @stay[:state] == :go
        tell(:wait, true) if (room.nil? || room < 0) && clock - @stay[:at] > REACTION
      elsif room && room >= here[3] && settled?
        tell(:go, true)
      elsif @stay[:state].nil?
        tell(:wait, false)
        tight(here)
      end
    end

    # True once what was being said as the player came onto the station has been heard: not before HOLD_MIN seconds,
    # then as the reader falls quiet, or, when it cannot tell, once what the mod sent it has been read (heard); at
    # HOLD_MAX seconds past the last line sent whatever it says.
    def self.settled?
      now = clock
      return false if now - @stay[:since] < HOLD_MIN
      return true if @last_line && now - @last_line >= HOLD_MAX
      read?(@read_until)
    end

    # True once the reader is quiet, or, when it cannot tell, once the moment `till` has come.
    def self.read?(till)
      talking = PokeAccess.speaking?
      talking.nil? ? till.nil? || clock >= till : !talking
    end

    # Notes a line the mod sends the reader: by when all it has been sent, this one too, will have been read; and that
    # it cuts the way told with the wait, if it interrupts before that has been heard.
    def self.heard(msg)
      now = clock
      @stay[:cut] = true if msg.interrupt && @stay && @stay[:told] && !@stay[:heard]
      start = msg.interrupt || @read_until.nil? || @read_until < now ? now : @read_until
      @read_until = start + READ_GAP + msg.text.to_s.length / READ_CPS
      @last_line = now
    end

    # Says once a session for each tight crossing (a station whose window is under TIGHT, or the tile before it, by
    # where its way ends) that it is tight.
    def self.tight(here)
      key = [$game_map.map_id, steps_end(here)]
      return if here[3] >= TIGHT || (@tight ||= {})[key]
      @tight[key] = true
      PokeAccess.speak(PokeAccess::I18n.t(:rv_hack_tight), false)
    end

    # The tile a station's way ends on.
    def self.steps_end(here)
      here[2].inject(here[0, 2]) { |(x, y), d| [x + DELTA[d][0], y + DELTA[d][1]] }
    end

    # Forgets the go's way once the player is off it.
    def self.follow
      return unless @route
      at = [$game_player.x, $game_player.y]
      @route = nil unless @route.include?(at) || at == @route_from
    end

    # The station the player stands still on, the tile before a braking spot among them, on a level with the assist
    # and the player free, or nil.
    def self.station
      list = $game_map && STATIONS[$game_map.map_id]
      return nil unless list && PokeAccess::Puzzles.assist? && PokeAccess::Control.free? && !$game_player.moving?
      return nil unless PokeAccess::World::Mechanics.instances.any? { |i| i.spec[:arrival_hint] == :rv_hack_rule }
      x = $game_player.x
      y = $game_player.y
      list.find { |s| s[0] == x && s[1] == y } ||
        (APPROACHES[$game_map.map_id] || []).map { |a| a[2] }.find { |s| s[0] == x && s[1] == y }
    end

    # Says stop once an arrival as the player walks onto a braking spot, when what is left before the step onto it
    # starts falls to BRAKE_LEAD; not for a spot a go's way runs over on to farther. Stepping off its line, not the
    # still pulse between two steps of a held key, ends the arrival.
    def self.brake
      list = $game_map && APPROACHES[$game_map.map_id]
      near = list && list.find { |a| steps_before(a) }
      return @braked = nil unless near
      return if @braked.equal?(near[0]) || (@route && @route.last != near[0][0, 2])
      return unless $game_player.moving? && $game_player.direction == near[1]
      return unless PokeAccess::Puzzles.assist? && PokeAccess::Control.free? && left_before(near) <= BRAKE_LEAD
      @braked = near[0]
      PokeAccess.speak(PokeAccess::I18n.t(:rv_hack_stop), true)
    end

    # How many steps the player is short of a braking spot along the way in (0 on it, up to 2), or nil off that line.
    def self.steps_before(a)
      spot, d = a
      (0..2).find { |k| $game_player.x == spot[0] - k * DELTA[d][0] && $game_player.y == spot[1] - k * DELTA[d][1] }
    end

    # Seconds until the player's step onto a braking spot starts, from the step under way (below 0 once it has).
    def self.left_before(a)
      k = steps_before(a)
      return -1.0 if k == 0
      timer = $game_player.instance_variable_get(:@move_timer)
      rest = timer ? $game_player.instance_variable_get(:@move_time).to_f - timer.to_f : PACE
      (k - 1) * PACE + rest
    end

    # Says once the way on from a station that crosses no round: to the next waiting spot, or onto the breach.
    def self.lead(here)
      return if @stay[:state]
      @stay[:state] = :led
      key = here.equal?(STATIONS[$game_map.map_id].last) ? :rv_hack_lead_breach : :rv_hack_lead
      PokeAccess.speak(PokeAccess::I18n.t(key, :way => PokeAccess::Routes::Text.steps(here[2])), false)
    end

    # Says wait, or go, and remembers it; the way on goes with go, or with the first wait for a way of LONG legs or
    # more, so that its go is short once that wait has been read with no line cutting it. A go keeps its way, which
    # no stop cuts but at its end.
    def self.tell(state, interrupt)
      here = @stay[:station]
      @stay[:state] = state
      @stay[:at] = clock
      way = PokeAccess::Routes::Text.steps(here[2])
      long = @stay[:told].nil? && PokeAccess::Routes::Text.legs(here[2]).length >= LONG
      line = if state == :go
               short = @stay[:heard]
               short ? PokeAccess::I18n.t(:rv_hack_go_short) : PokeAccess::I18n.t(:rv_hack_go, :way => way)
             elsif long
               PokeAccess::I18n.t(:rv_hack_wait_way, :way => way)
             else
               PokeAccess::I18n.t(:rv_hack_wait)
             end
      start_route(here) if state == :go
      PokeAccess.speak(line, interrupt)
      @stay[:told] = @read_until || clock if state == :wait && long
    end

    # Keeps the tiles of a go's way, from the station it leaves.
    def self.start_route(here)
      @route_from = here[0, 2]
      @route = []
      here[2].inject(@route_from) do |(x, y), d|
        @route.push([x + DELTA[d][0], y + DELTA[d][1]])
        @route.last
      end
    end

    # The widest window of starts, from REACTION seconds on, in which the way from a station keeps clear of every
    # marcianito: each tile entered no sooner than its steps at PACE, and left by then plus the window, a step, a
    # FRAME a step and TURN for each turn so far; nil when no start does.
    def self.slack(here)
      way = here[2]
      horizon = REACTION + (way.length + 1) * (PACE + TURN) + 1.0
      stays = []
      $game_map.events.each_value do |ev|
        stays.concat(stays_of(ev, horizon)) if ev.character_name.to_s =~ /marcianito/i
      end
      x = here[0]
      y = here[1]
      turns = 0
      best = nil
      way.each_with_index do |d, i|
        x += DELTA[d][0]
        y += DELTA[d][1]
        turns += 1 if way[i + 1] != d
        enter = REACTION + i * PACE
        leave = REACTION + (i + 1) * (PACE + FRAME) + turns * TURN
        stays.each do |sx, sy, from, to|
          next unless sx == x && sy == y && to + MARGIN > enter
          w = from - MARGIN - leave
          return nil if from - MARGIN < enter || w < 0
          best = w if best.nil? || w < best
        end
      end
      best || horizon
    end

    # Where a marcianito will stand, [x, y, from, to] in seconds from now up to horizon, as its custom route runs on
    # the way Game_Character runs it: its tile until its next step, then each step's tile until the one after; from
    # the soonest it can get there, to the latest it can leave, each step and wait before taking up to a FRAME more.
    def self.stays_of(ev, horizon)
      route = ev.instance_variable_get(:@move_route)
      list = route ? route.list : []
      i = ev.instance_variable_get(:@move_route_index).to_i
      tile = ev.instance_variable_get(:@move_time).to_f
      t = pending(ev, tile)
      late = t > 0 ? FRAME : 0.0
      x = ev.x
      y = ev.y
      since = -1.0
      out = []
      guard = 2000
      while t < horizon && (guard -= 1) > 0
        cmd = list[i]
        if cmd.nil? || cmd.code == 0
          break unless route.repeat && i > 0
          i = 0
          next
        end
        i += 1
        if MOVES[cmd.code]
          out.push([x, y, since, t + late])
          x += MOVES[cmd.code][0]
          y += MOVES[cmd.code][1]
          since = t
          t += tile
          late += FRAME
        elsif cmd.code == 15
          t += cmd.parameters[0] / 20.0
          late += FRAME
        elsif cmd.code == 29
          tile = tile_time(cmd.parameters[0])
        end
      end
      out.push([x, y, since, horizon + 1.0])
    end

    # Seconds until an event's route takes its next command: the rest of its step, or of its wait.
    def self.pending(ev, tile)
      timer = ev.instance_variable_get(:@move_timer)
      return [tile - timer.to_f, 0.0].max if timer
      wait = ev.instance_variable_get(:@wait_count).to_f
      return 0.0 if wait <= 0
      [wait - (clock - ev.instance_variable_get(:@wait_start).to_f), 0.0].max
    end

    # Seconds a tile takes at a move speed, as Game_Character#move_speed= sets them in Essentials v21.
    def self.tile_time(speed)
      return 0.05 if speed == 6
      return 0.1 if speed == 5
      2.0 / (2**speed)
    end

    # The engine's clock, in seconds: the one the game stamps a route's wait with.
    def self.clock
      System.uptime
    rescue StandardError => e
      PokeAccess.swallowed(e)
      Time.now.to_f
    end

    PokeAccess::Frame.each_pulse { PokeAccess::RevivalHack.tick } unless @pulsing
    @pulsing = true
    PokeAccess::Speech.observe(:rv_hack_reading) { |msg| PokeAccess::RevivalHack.heard(msg) }
  end
end

PokeAccess::Game.define("revival") do
  PokeAccess::RevivalHack::LEVELS.each do |map, (breach, start)|
    mechanic(:state, map) do
      spot :event => breach, :label => :rv_hack_breach, :onto => true
      obstacle(/marcianito/i, :moving => true)
      sent_back :rv_hack_caught, :to => start
      arrival_hint :rv_hack_rule, :once => true
      PokeAccess::RevivalHack::STATIONS[map].select { |s| s[3] }.each_with_index do |s, k|
        spot :at => [s[0], s[1]], :label => [:rv_hack_wait_spot, { :n => k + 1 }], :assist => true, :onto => true
      end
    end
  end

  mechanic(:state, 140) do
    auto
    count :rv_hack_terminals, :var => 114, :of => 5, :assist => true
    solved { $game_variables[114] >= 5 }
  end

  mechanic(:state, 247) do
    auto
    count :rv_hack_terminals, :var => 124, :of => 4
    solved { $game_variables[124] >= 4 }
  end
end
