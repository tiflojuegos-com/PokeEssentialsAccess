module PokeAccess
  # The Erebus Gym mirror rooms (maps 542 and 543; pbDrawLasers and pbChangeMirror): each mirror's turn (variable 144)
  # and the tiles the beam lit (variable 145), by event id, are read as the sprites show them; with the puzzle assist
  # the beam is traced as the game draws it and the turns that light every receiver are searched for.
  module InsurgenceLasers
    # Per room: where each beam starts (the tile before its first), each receiver's event with the switch it sets, and
    # the mirrors in reading order (from Data/Map542-543; map 543's event 11, a mirror left away from the room at 1,9,
    # is none).
    ROOMS = {
      542 => { :emitters => [[12, 10], [14, 26]], :receivers => { 100 => 517, 99 => 516 },
               :mirrors => [43, 16, 19, 24, 40, 15, 21, 22, 41, 42, 38, 39] },
      543 => { :emitters => [[12, 14]], :receivers => { 211 => 515 },
               :mirrors => [1, 2, 3, 20, 21, 6, 5, 19, 8, 9, 7, 15, 12, 13, 14, 16] }
    }
    # The sides a mirror joins by its turn, as the game's own note on the table has them: 0 top and left, then
    # clockwise.
    SIDES = [:ins_mirror_tl, :ins_mirror_tr, :ins_mirror_br, :ins_mirror_bl]
    # The game's own ways (0 up, 1 right, 2 down, 3 left): the step each takes, and how a beam heading so is said.
    STEPS = [[0, -1], [1, 0], [0, 1], [-1, 0]]
    HEADING = [:ins_laser_to_up, :ins_laser_to_right, :ins_laser_to_down, :ins_laser_to_left]
    # getDirectionReflect: by a mirror's turn, the side the beam comes in by => the way it leaves; a side the turn
    # does not join cuts the beam there.
    REFLECT = [{ 0 => 3, 3 => 0 }, { 0 => 1, 1 => 0 }, { 2 => 1, 1 => 2 }, { 2 => 3, 3 => 2 }]
    # The most tiles a beam is followed before it is taken for a loop (the game would never end drawing it).
    TRACE_CAP = 2000
    # The most steps the search for the turns takes before it gives up (a few hundred solve both rooms).
    SEARCH_CAP = 20000

    # The room the player is in, or nil.
    def self.room
      ROOMS[($game_map.map_id rescue 0)]
    end

    # An event of the map, or nil.
    def self.event(id)
      ($game_map.events[id.to_i] rescue nil)
    end

    # True for a mirror of the room the player is in.
    def self.room_mirror?(ev)
      r = room
      r && ev && r[:mirrors].include?(ev.id) ? true : false
    end

    # True for a tile of the beam's track (a lit one wears a beam sprite), receivers aside.
    def self.track?(ev, r = room)
      r && (ev.name.to_s rescue "") == "laser" && !r[:receivers].key?((ev.id rescue nil)) ? true : false
    end

    # A mirror's turn, 0 to 3, from variable 144.
    def self.turn(id)
      (($game_variables[144][id] rescue 0) || 0).to_i % 4
    end

    # True while the beam passes an event, by variable 145.
    def self.lit?(id)
      ($game_variables[145][id] rescue false) == true
    end

    # The room's mirrors in reading order.
    def self.mirrors
      r = room
      r ? r[:mirrors].map { |id| event(id) }.compact : []
    end

    # A mirror's number in reading order.
    def self.number(id)
      (room ? room[:mirrors].index(id).to_i : 0) + 1
    end

    # A mirror as it is said: its number in reading order, the sides it joins and whether the beam passes it; with
    # the assist's verdict on request.
    def self.mirror_line(ev, verdict = false)
      line = PokeAccess::I18n.t(:ins_mirror, :n => number(ev.id), :sides => PokeAccess::I18n.t(SIDES[turn(ev.id)]))
      line = "#{line}, #{PokeAccess::I18n.t(:ins_mirror_lit)}" if lit?(ev.id)
      v = verdict ? verdict_of(ev.id) : nil
      v ? "#{line}, #{v}" : line
    end

    # The room as the beam leaves it: how many mirrors it passes and how many receivers it reaches.
    def self.status_line(r)
      list = mirrors
      lit = list.select { |ev| lit?(ev.id) }.length
      got = r[:receivers].keys.select { |id| lit?(id) }.length
      PokeAccess.sentences([PokeAccess::I18n.t(:ins_laser_mirrors, :n => list.length, :lit => lit),
                            PokeAccess::I18n.t(:ins_laser_receivers, :n => r[:receivers].length, :lit => got)])
    end

    # After a mirror is turned (its beam already redrawn): the mirror, with the assist whether it now stands as it
    # should, and the room.
    def self.rotated(id)
      r = room
      ev = r && event(id)
      return unless ev && r[:mirrors].include?(ev.id)
      PokeAccess.speak(PokeAccess.sentences([mirror_line(ev, true), status_line(r)]), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What the info key says: the mirror in front of the player, else the room.
    def self.info_line
      r = room
      return "" unless r
      ev = front_mirror
      ev ? mirror_line(ev) : status_line(r)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end

    # The room's mirror right in front of the player, or nil.
    def self.front_mirror
      fx, fy = PokeAccess::Control.front_tile
      mirrors.find { |m| m.x == fx && m.y == fy }
    end

    # The assist's line for the info key: the verdict on the mirror in front, else where each beam goes and the next
    # mirror to set; empty without the assist.
    def self.assist_line
      r = room
      return "" unless r && PokeAccess::Puzzles.assist?
      ev = front_mirror
      return verdict_of(ev.id).to_s if ev
      tiles = tile_events
      beams = r[:emitters].map { |s| trace(tiles, s, current_turns(r)) }
      PokeAccess.sentences(beams.map { |b| beam_line(r, b) } + [next_step(r, beams)])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end

    # A beam as it goes: the way it leaves, each mirror it meets and the way it takes after it, and how it ends
    # (reaching a receiver, cut at a mirror, or lost where nothing stands).
    def self.beam_line(r, beam)
      outcome, hops, lit = beam
      parts = [PokeAccess::I18n.t(:ins_laser_start, :dir => PokeAccess::I18n.t(HEADING[2]))]
      hops.each do |id, out|
        next if out.nil?
        parts.push(PokeAccess::I18n.t(:ins_laser_hop, :n => number(id), :dir => PokeAccess::I18n.t(HEADING[out])))
      end
      parts.push(beam_end(r, outcome, hops, lit))
      parts.join("; ")
    end

    # How a beam ends: at a receiver, cut at its last mirror, or lost.
    def self.beam_end(r, outcome, hops, lit)
      return PokeAccess::I18n.t(:ins_laser_reach) unless (lit & r[:receivers].keys).empty?
      return PokeAccess::I18n.t(:ins_laser_cut, :n => number(hops.last[0])) if outcome == :cut
      PokeAccess::I18n.t(:ins_laser_end)
    end

    # The next mirror to set, with the quarter turns it still needs: the first one a beam meets that stands wrong,
    # else the first wrong one in reading order; that all stand right; or that no turns light every receiver.
    def self.next_step(r, beams)
      goal = solution(r)
      return PokeAccess::I18n.t(:ins_laser_none) unless goal
      wrong = r[:mirrors].select { |id| goal[id] && goal[id] != turn(id) }
      return PokeAccess::I18n.t(:ins_laser_ready) if wrong.empty?
      met = beams.map { |b| b[1].map { |h| h[0] } }.flatten
      id = met.find { |m| wrong.include?(m) } || wrong[0]
      todo = PokeAccess::I18n.t(:ins_laser_todo, :n => number(id), :sides => PokeAccess::I18n.t(SIDES[goal[id]]))
      "#{todo}, #{turns_left(id, goal[id])}"
    end

    # With the assist, whether a mirror stands as the turns that light every receiver want it, else the sides it should
    # join and the quarter turns it still needs; nil without the assist, or for a mirror they leave alone.
    def self.verdict_of(id)
      return nil unless PokeAccess::Puzzles.assist?
      r = room
      goal = r && solution(r)
      want = goal && goal[id]
      return nil unless want
      return PokeAccess::I18n.t(:ins_laser_ok) if want == turn(id)
      "#{PokeAccess::I18n.t(:ins_laser_goal, :sides => PokeAccess::I18n.t(SIDES[want]))}, #{turns_left(id, want)}"
    end

    # How many times a mirror is still to be turned to stand at a turn: the game only turns it a quarter clockwise.
    def self.turns_left(id, want)
      PokeAccess::I18n.t(:ins_laser_turns, :n => (want - turn(id)) % 4)
    end

    # The first event on each tile of the map, as the game looks a tile up (getMirrorAt: ids 1 to the count of events
    # less one, ascending, so a higher id is never seen).
    def self.tile_events
      out = {}
      evs = $game_map.events || {}
      (1...evs.length).each do |id|
        ev = evs[id]
        out[[ev.x, ev.y]] ||= ev if ev
      end
      out
    end

    # Every mirror's turn now, by id.
    def self.current_turns(r)
      out = {}
      r[:mirrors].each { |id| out[id] = turn(id) }
      out
    end

    # A beam from start as pbDrawLasers draws it, mirrors turned as given (id => turn): [ending, hops as [id, way out or
    # nil where cut], lit event ids]. Ending :end on a tile with no event, :cut where a turn misses the side it comes
    # in by, :loop past TRACE_CAP, :open at a mirror not in turns (then also its id and the side it comes in by).
    def self.trace(tiles, start, turns)
      x, y = start
      way = 2
      lit = []
      hops = []
      TRACE_CAP.times do
        x += STEPS[way][0]
        y += STEPS[way][1]
        ev = tiles[[x, y]]
        return [:end, hops, lit] unless ev
        lit.push(ev.id)
        next unless (ev.name.to_s rescue "") == "c"
        side = (way + 2) % 4
        t = turns[ev.id]
        return [:open, hops, lit, ev.id, side] if t.nil?
        out = REFLECT[t][side]
        unless out
          lit.pop
          hops.push([ev.id, nil])
          return [:cut, hops, lit]
        end
        hops.push([ev.id, out])
        way = out
      end
      [:loop, hops, lit]
    end

    # The turns that light every receiver with the fewest quarter turns from where the mirrors stand, as {id => turn}
    # for the mirrors the beams meet; nil when none do within SEARCH_CAP.
    def self.solution(r)
      @best = nil
      @steps = 0
      search(r, tile_events, current_turns(r), 0, {}, 0, [])
      @best && @best[1]
    end

    # One step of the search: beam k traced with the turns fixed so far; at a mirror it leaves open, each turn is
    # tried (a turn that cuts it only while another beam is still to come), cheapest first.
    def self.search(r, tiles, now, k, fixed, cost, got)
      @steps += 1
      return if @steps > SEARCH_CAP || (@best && cost >= @best[0])
      starts = r[:emitters]
      if k == starts.length
        @best = [cost, fixed.dup] if r[:receivers].keys.all? { |id| got.include?(id) }
        return
      end
      res = trace(tiles, starts[k], fixed)
      unless res[0] == :open
        search(r, tiles, now, k + 1, fixed, cost, got | (res[2] & r[:receivers].keys))
        return
      end
      id = res[3]
      last = k == starts.length - 1
      (0..3).sort_by { |t| (t - now[id]) % 4 }.each do |t|
        next if last && REFLECT[t][res[4]].nil?
        fixed[id] = t
        search(r, tiles, now, k, fixed, cost + (t - now[id]) % 4, got)
        fixed.delete(id)
      end
    end

    # The puzzle category's spots: where each beam starts, each receiver and each mirror, named as it stands.
    def self.spots(mid)
      r = ROOMS[mid]
      out = r[:emitters].map { |xy| { :at => xy, :label => :ins_laser_emitter } }
      r[:receivers].each_key { |id| out.push(:event => id, :label => :ins_laser_receiver) }
      r[:mirrors].each do |id|
        out.push(:event => id, :label => lambda { ev = event(id); ev ? mirror_line(ev) : "" })
      end
      out
    end

    # True once every receiver of the room has opened its door.
    def self.solved?
      r = room
      r ? r[:receivers].values.all? { |sw| $game_switches[sw] ? true : false } : false
    end
  end
end

PokeAccess::Game.define("insurgence") do
  kernel("pbChangeMirror", :after) { |a, _r| PokeAccess::InsurgenceLasers.rotated(a[0]) }

  # In the mirror rooms a mirror is named as it stands and filed as an object, and the beam's tiles, lit ones wearing a
  # sprite, stay out of the lists and the sonar: the room's line and each turned mirror say where the beam goes.
  event_name { |ev| PokeAccess::InsurgenceLasers.room_mirror?(ev) ? PokeAccess::InsurgenceLasers.mirror_line(ev) : nil }
  event_category(:objects) { |ev| PokeAccess::InsurgenceLasers.room_mirror?(ev) }
  event_hidden { |ev| PokeAccess::InsurgenceLasers.track?(ev) }

  PokeAccess::InsurgenceLasers::ROOMS.each_key do |mid|
    mechanic(:state, mid) do
      PokeAccess::InsurgenceLasers.spots(mid).each { |s| spot s }
      info { PokeAccess::InsurgenceLasers.info_line }
      hint lambda { PokeAccess::InsurgenceLasers.assist_line }
      solved { PokeAccess::InsurgenceLasers.solved? }
    end
  end
end
