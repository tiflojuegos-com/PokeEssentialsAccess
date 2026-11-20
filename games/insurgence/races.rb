module PokeAccess
  # Insurgence's Pokemon races on the Sonata Tracks (the desk's Kernel.pbStartRace, common events 21 and 31): the
  # player walks their own Pokemon north with the arrows against three rivals (events 1 to 3), from row 134 to the
  # Finish events of row 9. As each step brings a row into view it says what comes in the player's column (a wall and
  # the way past it, a booster, a ramp, slowing ground, ice, the finish line) and the boosters in the columns beside it;
  # also the rows left at each mark, the place once it holds and a booster picked up. While the race runs the mod's
  # guides, surface cues and soundscape hold (Control.condition below), and the info key says the race line.
  module InsurgenceRace
    # The tracks common event 21 sends the player to: Flower Fields, Golden Sands, Rocky Road and Ice Path. Outer
    # Reaches (272) has a branch there, but getPokemonRaceMaps never offers it.
    RACE_MAPS = [274, 345, 346, 568]
    # On while the player races (common event 31 until the desk's page on the Sonata Tracks), and on once the
    # announcer's "Go" lets the rivals run (pbGetMoveForEvent).
    RACING = 136
    GO = 137
    # Each racer's booster frames left, the player's first (the Speed_Boost events set 20, Scene_Map counts it down).
    BOOSTS = 63
    RIVALS = [1, 2, 3]
    # The events a track is drawn with, by the part of their names the game's own script matches.
    FEATURES = [["Speed_Boost", :boost], ["RAMP", :ramp], ["Finish", :finish]]
    FINISH_ROW = 9
    # The rows ahead read, a row more than the 512x384 screen shows above the player so a line ends before the player
    # gets there, and more while a booster runs (speed x1.25).
    LOOK = 7
    LOOK_BOOSTED = 9
    # The columns a gap is looked for on each side of a wall, and those a run of one kind is followed to its left end.
    GAP_REACH = 12
    RUN_REACH = 30
    # The rows left said once as the player gets there, and the frames a place must hold before it is said.
    HALFWAY = 50
    PLACE_SETTLE = 20
    # The ground that slows a racer (pbIsGrassTag?: grass, tall grass, sand, underwater grass) and ice, which slides.
    SLOW = { 2 => :ins_race_grass, 10 => :ins_race_grass, 11 => :ins_race_grass, 3 => :ins_race_sand }
    ICE = 12
    # The way past a wall by side (-1 west, 1 east, 0 both as near): walking there, or through a ramp on the player's own
    # row, which only jumps when stepped on from the south.
    WALL_LINES = { -1 => :ins_race_wall_left, 1 => :ins_race_wall_right, 0 => :ins_race_wall_both }
    RAMP_LINES = { -1 => :ins_race_ramp_below_left, 1 => :ins_race_ramp_below_right, 0 => :ins_race_ramp_below_both }

    # True while the player races on one of the tracks.
    def self.racing?
      return false unless $game_switches && $game_switches[RACING] && $game_map
      RACE_MAPS.include?($game_map.map_id)
    end

    # Per pulse: once a map frame while the race runs on the map with no message up, the race's news; forgets the race
    # once it is over.
    def self.poll
      return reset unless racing?
      serial = PokeAccess::Frame.serial
      return if serial == @serial
      @serial = serial
      return unless $game_switches[GO] && PokeAccess::Control.scene_map?
      return if PokeAccess::Control.flag($game_temp, :message_window_showing)
      update
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Forgets the race said.
    def self.reset
      @map = nil
      @serial = nil
    end

    # One frame of the race: the start line the first time, then on each new tile what comes ahead and the boosters
    # beside, and each frame the place and a booster picked up; the halfway mark after them in a line of its own.
    # Nothing while an ice slide carries the player (pbSlideOnIce runs the map frames tile by tile): where it stops is
    # read. A line about the player's own column interrupts, unless the last one told of a booster beside or the
    # halfway mark; the rest waits its turn. Nothing once the player is on the finish line.
    def self.update
      opening = @map.nil? ? begin_race : nil
      x = $game_player.x
      y = $game_player.y
      return if y <= @finish || (opening.nil? && PokeAccess::Control.sliding?)
      parts = [opening]
      own = false
      side = []
      halfway = nil
      if [x, y] != @pos
        @pos = [x, y]
        @look = boost_frames > 0 ? LOOK_BOOSTED : LOOK
        news = ahead(x, y)
        own = !news.empty?
        side = beside(x, y)
        parts.concat(news)
        parts.concat(side)
        halfway = mark(y)
      end
      parts.push(place_line)
      parts.push(boost_line)
      text = PokeAccess.sentences(parts.compact)
      unless text.empty?
        PokeAccess.speak(text, !opening.nil? || (own && !@kept))
        @kept = own ? false : (@kept || !side.empty?)
      end
      return unless halfway
      PokeAccess.speak(halfway, false)
      @kept = true
    end

    # Takes the track afresh and answers the start line: the finish line's distance north.
    def self.begin_race
      @map = $game_map.map_id
      @features = features
      @steps = {}
      rows = @features.select { |_k, v| v == :finish }.map { |k, _v| k % PokeAccess::Routes::PKEY_STRIDE }
      @finish = rows.empty? ? FINISH_ROW : rows.max
      @look = LOOK
      @said = {}
      @wall = nil
      @pos = nil
      @place = nil
      @run = nil
      @kept = false
      @boosted = boost_frames > 0
      left = $game_player.y - @finish
      @halfway = left <= HALFWAY
      PokeAccess::I18n.t(:ins_race_start, :n => left)
    end

    # The track's boosters, ramps and finish line by tile key.
    def self.features
      out = {}
      $game_map.events.each_value do |ev|
        name = (ev.name rescue nil).to_s
        hit = FEATURES.find { |pat, _k| name.include?(pat) }
        out[key(ev.x, ev.y)] = hit[1] if hit
      end
      out
    end

    # A tile's key.
    def self.key(x, y); PokeAccess::Routes.pkey(x, y); end

    # True while a rival stands on (x, y).
    def self.rival_at?(x, y)
      RIVALS.any? do |i|
        ev = $game_map.events[i]
        ev && ev.x == x && ev.y == y
      end
    end

    # True when the player gets north out of (x, y), stepped onto from the south (below) or from a side. A ramp jumps
    # them up only when stepped on from the south, facing north (its touch page), and if the jump lands.
    def self.up?(x, y, below = true)
      return jumps?(x, y) if below && ramp?(x, y)
      step?(x, y, 8)
    end

    # True for a ramp's tile.
    def self.ramp?(x, y); @features[key(x, y)] == :ramp; end

    # The engine's answer for a step out of (x, y) toward d, kept for the race: a track's tiles never change. A step into
    # a rival's tile is taken as open, ground the rival will leave, and neither asked nor kept.
    def self.step?(x, y, d)
      dx, dy = PokeAccess::DIR_DELTA[d]
      return true if rival_at?(x + dx, y + dy)
      k = key(x, y) * 10 + d
      v = @steps[k]
      v.nil? ? (@steps[k] = PokeAccess::World::Probe.step?(x, y, d)) : v
    end

    # True when a ramp's jump north from (x, y) lands, by the engine's own check for a jump, kept for the race; a
    # rival's tile is taken as open, as for a step.
    def self.jumps?(x, y)
      return true if rival_at?(x, y - 1)
      k = key(x, y) * 10
      v = @steps[k]
      v.nil? ? (@steps[k] = PokeAccess::World::Probe.lands?(x, y, 8, x, y - 1)) : v
    end

    # True when the player can step either way between (x, y + 1) and (x, y): what getting onto a ramp again from the
    # south takes.
    def self.below_and_back?(x, y)
      step?(x, y, 2) && step?(x, y + 1, 8)
    end

    # Where a press toward d (4 or 6) from (x, y) leaves the player: the next column, and on ice on until the way is
    # shut or the ice ends (pbSlideOnIce); nil when the step is shut.
    def self.press(x, y, d)
      dx = d == 4 ? -1 : 1
      return nil unless step?(x, y, d)
      x += dx
      GAP_REACH.times do
        break unless ground_at(x, y) == :ins_race_ice && step?(x, y, d)
        x += dx
      end
      x
    end

    # The ground key of (x, y): ice, a slowing ground, or nil for ground that does neither.
    def self.ground_at(x, y)
      tag = ($game_map.terrain_tag(x, y) rescue 0).to_i
      tag == ICE ? :ins_race_ice : SLOW[tag]
    end

    # What lies in column x north of row y, nearest first, as [kind, row, rows away]: the boosters, ramps, the finish
    # line and each ground that starts, up to @look rows or the first wall, which ends it as :wall. The player's own
    # tile was stepped onto from a side for all it tells.
    def self.column(x, y)
      out = []
      ground = ground_at(x, y)
      1.upto(@look) do |d|
        r = y - d
        break if r < @finish
        unless up?(x, r + 1, d > 1)
          out.push([:wall, r, d])
          break
        end
        f = @features[key(x, r)]
        out.push([f, r, d]) if f
        g = ground_at(x, r)
        out.push([g, r, d]) if g && g != ground
        ground = g
      end
      out
    end

    # The news of the player's column: that the way is open again under the wall last said, and up to two things
    # ahead not said yet, a wall kept as the one to clear.
    def self.ahead(x, y)
      items = column(x, y)
      out = []
      out.push(PokeAccess::I18n.t(:ins_race_clear)) if cleared?(items.find { |i| i[0] == :wall }, x)
      fresh = items.reject { |i| @said[item_key(i, x)] }
      fresh[0, 2].each do |i|
        k = item_key(i, x)
        @said[k] = true
        @wall = [i[1], k] if i[0] == :wall
        out.push(describe(i, x))
      end
      out
    end

    # True when column x no longer meets the wall last said, the player still south of it and nothing else in the
    # way: the wall is then forgotten and unsaid, so stepping back under it says it again. A wall further on is unsaid
    # instead, to be said again with its own way past. Past its row the wall is forgotten in silence.
    def self.cleared?(wall, x)
      return false unless @wall
      row, said = @wall
      if $game_player.y <= row
        @wall = nil
        return false
      end
      return false if wall && wall[1] >= row
      @said.delete(said)
      @wall = nil
      return true unless wall
      @said.delete(item_key(wall, x))
      false
    end

    # Whatever is said once: a wall, a booster, a ramp or a ground by its row and the west end of its run (a wall's as
    # seen from the south, from a fence's row too), so moving along it says nothing more; the finish line once. A wall
    # right ahead of a player standing on a ramp is said for that ramp, stepping onto it from the south being the way.
    def self.item_key(item, x)
      kind, r, d = item
      return [:finish] if kind == :finish
      return [:wall_here, x, r] if kind == :wall && d == 1 && ramp?(x, r + 1)
      left = if kind == :wall
               run_left(x, r) { |cx| !up?(cx, r + 1) }
             elsif kind == :boost || kind == :ramp
               run_left(x, r) { |cx| @features[key(cx, r)] == kind }
             else
               run_left(x, r) { |cx| ground_at(cx, r) == kind }
             end
      [kind, r, left]
    end

    # The westmost column of the run through (x, r) the block holds for.
    def self.run_left(x, r)
      cx = x
      RUN_REACH.times do
        break unless cx > 0 && yield(cx - 1)
        cx -= 1
      end
      cx
    end

    # One thing ahead as said, with its distance in rows.
    def self.describe(item, x)
      kind, r, d = item
      case kind
      when :wall then wall_line(x, r + d, r, d)
      when :boost then PokeAccess::I18n.t(:ins_race_boost, :n => d)
      when :ramp then PokeAccess::I18n.t(:ins_race_ramp, :n => d)
      when :finish then PokeAccess::I18n.t(:ins_race_finish, :n => d)
      else PokeAccess::I18n.t(kind, :n => d)
      end
    end

    # A wall d rows ahead of row y, on row r, the way past it first: on a ramp stepped onto from a side, to step off
    # south and back on.
    def self.wall_line(x, y, r, d)
      if d == 1 && ramp?(x, y) && below_and_back?(x, y)
        return PokeAccess::I18n.t(:ins_race_ramp_below)
      end
      side, n, via_ramp = gap(x, y, r)
      return PokeAccess::I18n.t(:ins_race_wall_closed, :n => d) if side.nil?
      PokeAccess::I18n.t((via_ramp ? RAMP_LINES : WALL_LINES)[side], :n => d, :gap => n)
    end

    # The way past a wall on row r for a player on row y, as [side, columns away, through a ramp]: the best column on
    # each side (side_gap) walked to, else a ramp on the row to be stepped onto from the south; nil when none.
    def self.gap(x, y, r)
      west, west_ramp = side_gap(x, y, r, -1)
      east, east_ramp = side_gap(x, y, r, 1)
      way = pick(west, east)
      return way.push(false) if way
      way = pick(west_ramp, east_ramp)
      way ? way.push(true) : nil
    end

    # Of a west and an east column as [columns away, rows open], the one open further north, else the nearer, as
    # [side, columns away]: side 0 for both alike, nil for neither.
    def self.pick(west, east)
      return nil if west.nil? && east.nil?
      return [1, east[0]] if west.nil?
      return [-1, west[0]] if east.nil?
      return west[1] > east[1] ? [-1, west[0]] : [1, east[0]] if west[1] != east[1]
      return west[0] < east[0] ? [-1, west[0]] : [1, east[0]] if west[0] != east[0]
      [0, west[0]]
    end

    # The columns along row y toward dx (-1 west, 1 east) where the player's presses leave them (press: on ice, where a
    # slide stops), as [best walked to, nearest ramp]: the best is the column whose way north passes row r furthest
    # (reach), the nearest of those, and the ramp one on the row whose jump, stepped onto from the south, passes it,
    # each [columns away, rows open] or nil; up to GAP_REACH columns, or a wall on the row.
    def self.side_gap(x, y, r, dx)
      cx = x
      dir = dx < 0 ? 4 : 6
      full = [@look, y - @finish].min
      best = nil
      ramp = nil
      GAP_REACH.times do
        cx = press(cx, y, dir)
        break if cx.nil? || (cx - x).abs > GAP_REACH
        n = (cx - x).abs
        open = reach(cx, y)
        best = [n, open] if open >= y - r && (best.nil? || open > best[1])
        if ramp.nil? && ramp?(cx, y) && below_and_back?(cx, y)
          via = reach(cx, y + 1)
          ramp = [n, via] if via > y - r
        end
        break if best && best[1] >= full
      end
      [best, ramp]
    end

    # The rows column cx is open north of row y, the player stepped onto (cx, y) from a side, up to @look and no
    # further than the finish line.
    def self.reach(cx, y)
      n = 0
      n += 1 while n < @look && y - n > @finish && up?(cx, y - n, n > 0)
      n
    end

    # The boosters coming in the columns either side of the player, each run said once.
    def self.beside(x, y)
      out = []
      [[-1, :ins_race_boost_left], [1, :ins_race_boost_right]].each do |dx, k|
        b = column(x + dx, y).find { |i| i[0] == :boost }
        next unless b
        id = item_key(b, x + dx)
        next if @said[id]
        @said[id] = true
        out.push(PokeAccess::I18n.t(k, :n => b[2]))
      end
      out
    end

    # The rows left as the player reaches HALFWAY, once, or nil.
    def self.mark(y)
      left = y - @finish
      return nil if @halfway || left > HALFWAY
      @halfway = true
      PokeAccess::I18n.t(:ins_race_left, :n => left)
    end

    # The player's place: one and the rivals further north (a rival on the finish line among them).
    def self.place
      y = $game_player.y
      ahead = RIVALS.select do |i|
        ev = $game_map.events[i]
        ev && ev.y < y
      end
      1 + ahead.length
    end

    # The place once it has held PLACE_SETTLE frames and changed; the first one stays unsaid.
    def self.place_line
      n = place
      @run = (@run && @run[0] == n) ? [n, @run[1] + 1] : [n, 1]
      return nil if @run[1] < PLACE_SETTLE || n == @place
      first = @place.nil?
      @place = n
      first ? nil : PokeAccess::I18n.t(:ins_race_place, :n => n)
    end

    # The booster frames the player has left.
    def self.boost_frames
      v = $game_variables[BOOSTS]
      v.is_a?(Array) ? v[0].to_i : 0
    end

    # A booster picked up with none running.
    def self.boost_line
      on = boost_frames > 0
      was = @boosted
      @boosted = on
      on && !was ? PokeAccess::I18n.t(:ins_race_boosted) : nil
    end

    # The info key's line during the race: the place, the rows left, the nearest thing ahead and, where a press slides
    # the player on (ice), where each press leaves them (Info.forced_ways, which the race's line covers); nil off it.
    def self.info
      return nil unless racing? && @map && $game_player
      x = $game_player.x
      y = $game_player.y
      items = column(x, y)
      ahead = items.empty? ? PokeAccess::I18n.t(:ins_race_clear) : describe(items[0], x)
      PokeAccess.sentences([PokeAccess::I18n.t(:ins_race_place, :n => place),
                            PokeAccess::I18n.t(:ins_race_left, :n => [y - @finish, 0].max), ahead,
                            PokeAccess::Info.forced_ways])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Control.condition(:insurgence_race, :hold) { PokeAccess::InsurgenceRace.racing? }
PokeAccess::Info.map_owner(:insurgence_race) { PokeAccess::InsurgenceRace.info }

PokeAccess::Game.define("insurgence") do
  poll_each_frame { PokeAccess::InsurgenceRace.poll }
end
