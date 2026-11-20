# Monte Zodiaco Alterato, after the League. The glass bridge of map 633: glass tiles (events 60 to 80) crack once stepped on,
# each by its own switch (1243 to 1261, the page that waits for it), and a second step breaks one and drops the player to
# map 636; switch 1262 clears them all. Cracked glass leaves the map, so the routes keep off it, and the lists name it.
# Across the mountain, switch 1500 turns the controls round with no word, so it is said as it changes. The evil mirrors of
# map 629 (XenoMirrors): figures on four fields of ice that copy the player's facing, each zone with its parity switch.
# The shadows of map 631: three stretches of unseen traps, each sending the player back to its start, with tiles that
# wake grabbing hands in the third, which the walks keep off, and blinking tiles in the second (XenoBlink). The seal's
# zone of map 633 (x 27 to 38, y 59 to 64): unseen traps back to (44,64), and four rocks that leave one once smashed,
# told with the assist.
module PokeAccess
  module XenoAlteredZodiac
    BRIDGE = 633
    GLASS = 60..80
    CRACKS = 1243..1261

    # True when a glass tile's live page is the one its crack switch shows.
    def self.cracked?(ev)
      pg = PokeAccess.ivar(ev, :@page)
      c = pg && pg.condition
      return false unless c && (c.switch1_valid rescue false)
      CRACKS.include?(c.switch1_id)
    end

    REVERSED = 1500
    REVERSE_MAPS = [627, 628, 629, 630, 631, 632, 633, 634, 637, 638]
    SHADOWS = 631
    SHADOW_IDS = [5, 30, 41]
    SLAMS = [57, 58, 61, 63, 64, 67, 69, 75, 76, 78, 81, 84]
    STRETCH_STARTS = [[[20, 27], [21, 41, 25, 29]], [[50, 32], [51, 77, 27, 35]], [[70, 19], [17, 70, 17, 21]]]
    SEAL_ROCKS_TRAP = [26, 28, 29, 32]
    SEAL_START = [44, 64]
    SEAL_ZONE = [27, 38, 59, 64]

    # A seal rock's name with the assist when a trap lies under it; nil otherwise.
    def self.seal_rock_label(_ev)
      PokeAccess::Puzzles.assist? ? :xv_seal_rock_trap : nil
    end
  end

  # The evil mirrors of map 629. Each figure of a zone shows the player's reflection or an altered one, and the zone
  # decides which lets the player by: crossed sliding, it flips the zone's switch, and every figure of the zone swaps its
  # look; the other sends the player back to the zone's start, and so does one they stop on. Its page waits 4 frames
  # before the switch and a slide crosses a tile in 5 (0033_Interpreter.rb:722, 0020_Walk_Run.rb:66), so the page that
  # sends back first looks once the player has slid on. Each figure is named as it shows and the swap is said; with the
  # assist each is named by what it does, the next press out of the zone is said from where the player stands, found by
  # playing its slides, and a route through a zone takes those presses (plan).
  module XenoMirrors
    MAP = 629
    MIRROR = /\Amirror/
    OWN_REFLECTION = /\Amirror(kay|alice)\z/
    DECOYS = [5, 6, 7, 15, 21, 22, 26, 27, 28, 29]
    # A zone: its parity switch, its figures, true where the one showing the player's reflection lets them by, its tiles
    # [x0, x1, y0, y1] (its start and those a send-back leaves from), the floor past it, and the start it sends back to.
    Zone = Struct.new(:switch, :figures, :own_lets_by, :box, :past, :start)
    ZONES = [Zone.new(1187, [1, 8, 9, 10], true, [38, 42, 54, 64], [38, 42, 46, 53], [40, 64]),
             Zone.new(1188, [11, 12, 13, 14, 16, 17, 23, 24, 25], false, [19, 34, 41, 44], [15, 18, 41, 46], [33, 42]),
             Zone.new(1189, (30..40).to_a, true, [9, 13, 18, 35], [9, 13, 15, 17], [11, 35]),
             Zone.new(1193, [19, 20, 44, 45, 46], false, [9, 26, 14, 18], [17, 19, 11, 14], [11, 16])]
    # Figures whose page with the switch on does nothing.
    INERT_ON = [34]
    # Presses of more a send-back counts, so a way out takes one only where nothing else leads out.
    BACK_COST = 50
    # Tiles a slide is followed before it is taken for one that never stops.
    SLIDE_CAP = 100
    # The kind a kept plan takes where the zones' ways found none.
    UNPLANNED = :xv_unplanned
    EFFECTS = { :pass => :xv_mirror_lets_by, :back => :xv_mirror_sends_back, nil => :xv_mirror_does_nothing }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # A figure as it shows; with the assist, the decoys, which never change, and the others with what they do now.
    def self.label(ev)
      assist = PokeAccess::Puzzles.assist?
      return :xv_mirror_decoy if assist && DECOYS.include?(ev.id)
      look = ev.character_name.to_s =~ OWN_REFLECTION ? :xv_mirror_own : :xv_mirror_altered
      z = assist && ZONES.find { |zone| zone.figures.include?(ev.id) }
      return look unless z
      t = PokeAccess::I18n
      [:xv_mirror_effect, { :figure => t.t(look), :effect => t.t(EFFECTS[effect(z, ev, on?(z))]) }]
    end

    # The zone's switch.
    def self.on?(z); $game_switches[z.switch] ? true : false; end

    # True while the player stands on a figure of zone z that does something there: it is about to send them back.
    def self.on_figure?(z)
      z.figures.any? do |id|
        ev = drawn(id)
        ev && ev.x == $game_player.x && ev.y == $game_player.y && !effect(z, ev, on?(z)).nil?
      end
    end

    # True when (x, y) lies in the box [x0, x1, y0, y1].
    def self.inside?(b, x, y); x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3]; end

    # The zone the player stands in (zone_at); nil off map 629.
    def self.zone_here
      return nil unless ($game_map.map_id rescue 0) == MAP
      zone_at($game_player.x, $game_player.y)
    end

    # The zone (x, y) lies in, short of the floor past it, while a figure of it is drawn; nil elsewhere.
    def self.zone_at(x, y)
      ZONES.find { |z| inside?(z.box, x, y) && !inside?(z.past, x, y) && z.figures.any? { |id| drawn(id) } }
    end

    # Figure id while drawn; nil once its pad has broken the zone's mirrors.
    def self.drawn(id)
      ev = $game_map.events[id]
      ev && !ev.character_name.to_s.empty? ? ev : nil
    end

    # What a figure does with the player on its tile, the zone's switch at on: :pass, :back or nil. Past the switch it
    # shows the other reflection.
    def self.effect(z, ev, on)
      return nil if on && INERT_ON.include?(ev.id)
      own = !(ev.character_name.to_s =~ OWN_REFLECTION).nil?
      own = !own if on != on?(z)
      own == z.own_lets_by ? :pass : :back
    end

    # Where a press toward d from (x, y), the switch at on, leaves the player: [x, y, on], :back when a figure sends them
    # to the start, nil when the step is shut. A figure crossed flips the switch; one stopped on looks again with it
    # flipped, the player still there.
    def self.press(z, x, y, on, d)
      probe = PokeAccess::World::Probe
      return nil unless probe.step?(x, y, d)
      dx, dy = PokeAccess::DIR_DELTA[d]
      SLIDE_CAP.times do
        x += dx
        y += dy
        ev = z.figures.map { |id| drawn(id) }.compact.find { |f| f.x == x && f.y == y }
        hit = ev && effect(z, ev, on)
        return :back if hit == :back
        goes = PokeAccess::World::Terrain.ice?(x, y) && probe.step?(x, y, d)
        if hit == :pass
          on = !on
          return :back if !goes && effect(z, ev, on) == :back
        end
        return [x, y, on] unless goes
      end
      nil
    end

    # The cheapest presses from the player out past the zone (way_to).
    def self.way_out(z)
      way_to(z, [$game_player.x, $game_player.y, on?(z)], lambda { |n| inside?(z.past, n[0], n[1]) })
    end

    # The cheapest presses from state from [x, y, on] to one ends holds of, landing in the zone or the floor past it,
    # each [direction, [x, y, on] or :back], a send-back counting BACK_COST more; nil when none gets there.
    def self.way_to(z, from, ends)
      restart = [z.start[0], z.start[1], false]
      cost = { from => 0 }
      came = {}
      queue = [from]
      done = {}
      PokeAccess::World::Probe.session do
        until queue.empty?
          node = queue.min_by { |n| cost[n] }
          queue.delete(node)
          next if done[node]
          done[node] = true
          return presses_to(node, came) if ends.call(node)
          [2, 4, 6, 8].each do |d|
            got = press(z, node[0], node[1], node[2], d)
            next if got.nil?
            to = got == :back ? restart : got
            next unless inside?(z.box, to[0], to[1]) || inside?(z.past, to[0], to[1])
            c = cost[node] + (got == :back ? 1 + BACK_COST : 1)
            next if cost[to] && cost[to] <= c
            cost[to] = c
            came[to] = [node, d, got]
            queue.push(to)
          end
        end
      end
      nil
    end

    # The presses that led to node, from the first.
    def self.presses_to(node, came)
      out = []
      while came[node]
        node, d, got = came[node]
        out.unshift([d, got])
      end
      out
    end

    # With the assist, the way to target t (stood on with onto) where it crosses a zone whose figures stand: in a zone,
    # the presses way_to plays to the goal or out past it, from where the player stands or the walk enters it; on foot
    # between zones (Planner.plan_from); cut after a send-back, marked as the transfer it is. Nil where no such zone lies
    # on the way or the zones' ways find none, for the routes. Kept with the zones' switches, a way not found as UNPLANNED.
    def self.plan(t, onto)
      planner = PokeAccess::Routes::Planner
      st = PokeAccess::Guide.player_state
      return nil unless zone_at(st[0], st[1]) || entry(planner.plan_from(st[0], st[1], st[2], t.x, t.y, onto), st)
      made = planner.kept([:xv_mirrors, t.x, t.y, onto, switches]) do
        planned(t, onto, st) || PokeAccess::Routes::Plan.new(UNPLANNED)
      end
      made.kind == UNPLANNED ? nil : made
    end

    # The zones' switches, in order.
    def self.switches; ZONES.map { |z| on?(z) }; end

    # The plan of plan made afresh from state st [x, y, level], as a walk; nil where a zone's way, or the walk on from
    # it, finds none, or a zone would be crossed twice.
    def self.planned(t, onto, st)
      planner = PokeAccess::Routes::Planner
      goal = planner.goal_for(t.x, t.y, onto)
      route = PokeAccess::Pathfinder::Route.new
      crossed = []
      PokeAccess::Pathfinder.searching do
        (ZONES.length + 1).times do
          z = zone_at(st[0], st[1])
          unless z
            leg = planner.plan_from(st[0], st[1], st[2], t.x, t.y, onto)
            return nil unless leg.kind == :walk
            cut = entry(leg, st)
            join(route, leg.route, cut ? cut[0] : leg.route.length)
            return PokeAccess::Routes::Plan.new(:walk, route) unless cut
            z = cut[1]
            st = cut[2]
          end
          return nil if crossed.include?(z)
          crossed.push(z)
          presses = way_to(z, [st[0], st[1], on?(z)], ends_for(z, goal))
          return nil unless presses
          presses.each do |d, got|
            route.push(d)
            next unless got == :back
            route.warps = route.warps + [route.length - 1]
            return PokeAccess::Routes::Plan.new(:walk, route)
          end
          st = [presses[-1][1][0], presses[-1][1][1], st[2]] unless presses.empty?
          return PokeAccess::Routes::Plan.new(:walk, route) if goal.hit?(st[0], st[1])
        end
      end
      nil
    end

    # Where walk leg (a Plan) from state st first crosses into a zone whose figures stand: [the press, the zone, the
    # state it is pressed from]; nil when it crosses into none, or is no walk.
    def self.entry(leg, st)
      return nil unless leg.kind == :walk && leg.route
      from = st
      steps = PokeAccess::Routes::Moves.trace(st[0], st[1], st[2], leg.route, PokeAccess::Pathfinder.replay_mode)
      steps.each_with_index do |s, i|
        z = PokeAccess::Routes::Planner.passed(from[0], from[1], s.x, s.y).map { |x, y| zone_at(x, y) }.compact.first
        return [i, z, from] if z
        from = [s.x, s.y, s.level]
      end
      nil
    end

    # What ends a zone's way toward goal: one of the goal's tiles where the zone or the floor past it holds some, else
    # that floor.
    def self.ends_for(z, goal)
      own = goal.tiles.any? { |x, y| inside?(z.box, x, y) || inside?(z.past, x, y) }
      own ? lambda { |n| goal.hit?(n[0], n[1]) } : lambda { |n| inside?(z.past, n[0], n[1]) }
    end

    # Adds the first n presses of route part to route, with the transfers among them.
    def self.join(route, part, n)
      base = route.length
      route.concat(part[0, n])
      route.warps = route.warps + part.warps.select { |w| w < n }.map { |w| w + base }
    end

    # The first leg of presses from the player: [direction, tiles, slide, sends back], plain steps the same way on floor
    # taken together.
    def self.first_leg(presses)
      d, got = presses[0]
      dx, dy = PokeAccess::DIR_DELTA[d]
      ice = PokeAccess::World::Terrain.ice?($game_player.x + dx, $game_player.y + dy)
      return [d, 1, ice, got == :back] if ice || got == :back
      n = 1
      n += 1 while presses[n] && presses[n][0] == d && plain_step?(presses[n - 1][1], presses[n][1])
      [d, n, false, false]
    end

    # True when a press from from landed one plain tile on, off the ice.
    def self.plain_step?(from, to)
      return false unless to.is_a?(Array)
      (to[0] - from[0]).abs + (to[1] - from[1]).abs == 1 && !PokeAccess::World::Terrain.ice?(to[0], to[1])
    end

    # The next press out of the zone the player stands in, or toward the selected target (way_here), as the guide says a
    # step or a slide, with the keys reversed while they are, and said as a send-back where only one leads on; nil out
    # of a zone or with no way.
    def self.step_line
      z = zone_here
      presses = z && way_here(z)
      presses && !presses.empty? ? leg_line(first_leg(presses)) : nil
    end

    # The presses from the player that the routes take in zone z: to the selected target where the zone or the floor
    # past it holds its goal (ends_for), else, or with no way there, out of the zone (way_out).
    def self.way_here(z)
      loc = PokeAccess::Locator
      t = loc.target
      return way_out(z) unless t && loc.target_valid?
      goal = PokeAccess::Routes::Planner.goal_for(t.x, t.y, loc.onto?(t))
      way_to(z, [$game_player.x, $game_player.y, on?(z)], ends_for(z, goal)) || way_out(z)
    end

    # What a leg is said as.
    def self.leg_line(leg)
      d, n, slide, back = leg
      t = PokeAccess::I18n
      way = slide ? t.t(:loc_slide_leg, :dir => t.t(DIRS[d])) : t.t(:loc_leg, :n => n, :dir => t.t(DIRS[d]))
      way = t.t(:xv_blink_way_reversed, :way => way) if $game_switches[XenoAlteredZodiac::REVERSED]
      t.t(back ? :xv_mirror_step_back : :xv_mirror_step, :way => way)
    end

    # With the assist, the zone's rule: which figure lets the player by.
    def self.rule_line
      z = zone_here
      z ? PokeAccess::I18n.t(z.own_lets_by ? :xv_mirror_rule_own : :xv_mirror_rule_altered) : nil
    end

    # Forgets what was said, for a new visit.
    def self.reset
      @switches = {}
      @seen = nil
      @said = nil
      @along = []
      @guided = nil
    end

    # One pulse on map 629: says a zone's figures swapping as its switch turns, but as a send-back puts it back with the
    # player at the start; with the assist, once the player has stood still two pulses on a new spot of a zone, the next
    # press out of it, quiet along the steps of a walk already said and while a guide takes the mirrors' way (guided?).
    def self.tick
      return @switches = nil unless ($game_map.map_id rescue 0) == MAP
      reset if @switches.nil?
      swaps
      return unless PokeAccess::Puzzles.assist? && PokeAccess::Control.free?
      return @seen = nil if ($game_player.moving? rescue false)
      z = zone_here
      return @seen = nil unless z && !on_figure?(z)
      here = [$game_player.x, $game_player.y, on?(z)]
      return @seen = here unless @seen == here
      return if @said == here || @along.include?(here) || guided?
      @said = here
      presses = way_here(z)
      return @along = [] unless presses && !presses.empty?
      leg = first_leg(presses)
      @along = presses[0, leg[1] - 1].map { |_d, got| got }
      PokeAccess.speak(leg_line(leg), false)
    end

    # True while the step guide follows the selected target by a route the mirrors planned (Puzzles.way_plan), which
    # says each press itself; the cane alone only sounds the way, so the press is still said. Kept with the player's
    # tile, the zones' switches and the target.
    def self.guided?
      loc = PokeAccess::Locator
      t = loc.target
      return false unless t && PokeAccess::Guide.on?(:steps) && loc.target_valid?
      key = [$game_player.x, $game_player.y, switches, loc.identity(t), t.x, t.y]
      return @guided[1] if @guided && @guided[0] == key
      stats = loc.route_plan(t).stats
      @guided = [key, stats ? stats[:puzzle_way] == true : false]
      @guided[1]
    end

    # Says the swap of each zone whose switch turned since the last pulse.
    def self.swaps
      ZONES.each do |z|
        on = on?(z)
        was = @switches[z.switch]
        @switches[z.switch] = on
        next if was.nil? || was == on || [$game_player.x, $game_player.y] == z.start
        PokeAccess.speak(PokeAccess::I18n.t(:xv_mirror_swap), false)
      end
    end

    PokeAccess::Frame.each_pulse { PokeAccess::XenoMirrors.tick } unless @pulsing
    @pulsing = true
  end

  # The blinking tiles of map 631's second stretch: parallel events wait 20 and 10 (RPG Maker XP's waits count two frames
  # each, 0033_Interpreter.rb:722) and flip switch 1198 or 1202, so a tile of the way stays safe 41 or 21 frames, at 40 a
  # second, and is a trap while its switch is off. The player walks a tile in 10 frames (speed 3.8, no running there), and
  # a new direction key first turns them and steps TURN frames later (0019_Game_Player.rb:416).
  # Standing still on the tile before a crossing, with no event running and no message open, the player hears the
  # crossing once, to a safe tile; where the presses that keep every blinking tile safe under them leave MARGIN on each
  # side (a turn on a blinking tile counts its TURN and another MARGIN for the key, the first press TURN more), a go timed
  # on the blinking it has measured, aimed at their middle, only once the reader is quiet and no more often than GAP;
  # where they do not, that the crossing is very tight and why, and with the assist what other way there is.
  module XenoBlink
    MAP = 631
    SWITCHES = [1198, 1202]
    # Frames a switch stays on, from its events.
    SPAN = { 1198 => 41, 1202 => 21 }
    # Tile to wait on => [switch, legs of the crossing to a safe tile as [direction code, tiles], blinking tiles on it,
    # turns made on a blinking tile, why the crossing is very tight where it is (xv_blink_tight, the fast blinking, when
    # nil), what the assist says of another way there].
    STATIONS = { [60, 33] => [1198, [[6, 2]], 1, 0, nil, nil], [62, 33] => [1198, [[6, 1], [8, 1]], 1, 1, nil, nil],
                 [64, 32] => [1198, [[6, 1], [2, 2]], 2, 1, :xv_blink_tight_turn, :xv_blink_no_other],
                 [69, 32] => [1202, [[6, 2]], 1, 0, :xv_blink_tight, :xv_blink_other_faster] }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    # Frames a new direction key turns the player before the step.
    TURN = 3
    # Seconds between the go and the player's press: the reader's delay and the player's reaction.
    LEAD = 0.25
    # Seconds of reaction kept on each side of a press's aim.
    MARGIN = 0.15
    # Seconds at least between two goes.
    GAP = 2.0
    # Seconds the reader takes a character, and each line's pause, when it cannot tell whether it still talks.
    READ_CPS = 12.0
    READ_GAP = 0.3

    # Forgets what was measured, for a new visit.
    def self.reset
      @last = {}
      @on_at = {}
      @period = {}
      @station = nil
      @go_at = nil
      @cued = nil
      @read_until = nil
    end

    # One map frame of map 631 at frame now: measures the blinking and, while nothing holds the player (an event, a
    # message), says the station and the go.
    def self.tick(now)
      return @last = nil unless ($game_map.map_id rescue 0) == MAP
      reset if @last.nil?
      SWITCHES.each { |sw| measure(sw, $game_switches[sw] ? true : false, now) }
      return unless PokeAccess::Control.free?
      here = [($game_player.x rescue nil), ($game_player.y rescue nil)]
      stop = STATIONS[here]
      moving = ($game_player.moving? rescue false)
      return @station = nil unless stop && !moving
      arrive(here, stop) unless @station == here
      go(stop, now)
    end

    # Notes when the switch last turned safe and how often it comes back.
    def self.measure(sw, on, now)
      was = @last[sw]
      @last[sw] = on
      return unless on && was == false
      @period[sw] = now - @on_at[sw] if @on_at[sw]
      @on_at[sw] = now
    end

    # Says the crossing ahead of a station once as the player comes to stand on it: with a go to wait for, or as very
    # tight and why, and then, with the assist, what other way there is.
    def self.arrive(here, stop)
      @station = here
      t = PokeAccess::I18n
      way = stop[1].map { |d, n| t.t(:loc_leg, :n => n, :dir => t.t(DIRS[d])) }.join(", ")
      way = t.t(:xv_blink_way_reversed, :way => way) if $game_switches[PokeAccess::XenoAlteredZodiac::REVERSED]
      open = window(stop)
      PokeAccess.speak(t.t(open ? :xv_blink_station : (stop[4] || :xv_blink_tight), :way => way), false)
      PokeAccess.speak(t.t(stop[5]), false) if open.nil? && stop[5] && PokeAccess::Puzzles.assist?
    end

    # The frames after a switch turns on to aim the first press at, the middle of the presses that keep every blinking
    # tile under the player inside the safe span, a turn first or not; nil when they leave less than MARGIN each side.
    def self.window(stop)
      sw, _legs, blinking, turns = stop
      slack = (MARGIN * frame_rate).round
      exposure = blinking * step_frames + turns * (slack + TURN)
      presses = SPAN[sw] - exposure - TURN
      return nil if presses / 2.0 < slack
      presses / 2
    end

    # Says the go once a cycle, LEAD before the aimed press, when the crossing has a window, the reader is quiet and the
    # last go is GAP behind; the aim follows the switch's last turn on, or the next by the period measured.
    def self.go(stop, now)
      aim = window(stop)
      sw = stop[0]
      return unless aim && @on_at[sw]
      fps = frame_rate
      at = @on_at[sw] + aim - (LEAD * fps).round
      if at < now - 1
        period = @period[sw]
        return unless period && period > 0
        at += period while at < now - 1
      end
      return unless now >= at && now <= at + 1 && @cued != at
      @cued = at
      return if @go_at && now - @go_at < GAP * fps
      return unless quiet?
      @go_at = now
      PokeAccess.speak(PokeAccess::I18n.t(:xv_blink_go), false)
    end

    # The frames the player takes over a tile at their pace: the engine moves 2 ** speed of 128 a frame at 40 a second.
    def self.step_frames
      speed = ($game_player.move_speed rescue 3.8).to_f
      (128.0 / (2**speed)).ceil * frame_rate / 40
    end

    # The game's frames a second.
    def self.frame_rate
      (Graphics.frame_rate rescue 40).to_i
    end

    # True when the reader is not voicing anything, or, when it cannot tell, once what the mod sent should be read.
    def self.quiet?
      talking = PokeAccess.speaking?
      return !talking unless talking.nil?
      @read_until.nil? || clock >= @read_until
    end

    # Notes a line the mod sends the reader: by when all it has been sent will have been read.
    def self.heard(msg)
      now = clock
      start = msg.interrupt || @read_until.nil? || @read_until < now ? now : @read_until
      reading = msg.text.to_s.length / READ_CPS
      @read_until = start + reading + READ_GAP
    end

    # The mod's clock, in seconds.
    def self.clock
      PokeAccess.clock
    end

    PokeAccess::Frame.each_pulse { PokeAccess::XenoBlink.tick(PokeAccess::Frame.serial) } unless @pulsing
    @pulsing = true
    PokeAccess::Speech.observe(:xv_blink_reading) { |msg| PokeAccess::XenoBlink.heard(msg) }
  end
end

PokeAccess::Game.define("xenoverse") do
  zodiac = PokeAccess::XenoAlteredZodiac
  mechanic(:state, zodiac::BRIDGE, :part => :glass) do
    auto
    not_control zodiac::GLASS
    name zodiac::GLASS, lambda { |ev| zodiac.cracked?(ev) ? :xv_glass_cracked : :xv_glass },
         :when => lambda { |ev| zodiac.cracked?(ev) }
  end

  zodiac::REVERSE_MAPS.each do |map|
    mechanic(:state, map, :part => :reverse) do
      auto
      watch :switch => zodiac::REVERSED, :label => :xv_reverse_controls, :on => :xv_reverse_on, :off => :xv_reverse_off
    end
  end

  mirrors = PokeAccess::XenoMirrors
  mechanic(:state, mirrors::MAP, :part => :mirrors) do
    auto
    name mirrors::MIRROR, lambda { |ev| mirrors.label(ev) }
    avoid mirrors::MIRROR, :assist => true
    mirrors::ZONES.each { |z| sent_back :xv_mirror_back, :to => z.start, :from => z.box }
    active { PokeAccess::Puzzles.assist? && !mirrors.zone_here.nil? }
    info { mirrors.rule_line }
    hint lambda { mirrors.step_line }
    way { |t, onto| mirrors.plan(t, onto) }
  end

  mechanic(:state, zodiac::SHADOWS, :part => :shadows) do
    auto
    name zodiac::SHADOW_IDS, :xv_shadow
    avoid zodiac::SLAMS
    zodiac::STRETCH_STARTS.each { |to, from| sent_back :xv_shadow_back, :to => to, :from => from }
  end

  mechanic(:state, zodiac::BRIDGE, :part => :seal) do
    auto
    name zodiac::SEAL_ROCKS_TRAP, lambda { |ev| zodiac.seal_rock_label(ev) }, :assist => true
    sent_back :xv_seal_back, :to => zodiac::SEAL_START, :from => zodiac::SEAL_ZONE
  end
end
