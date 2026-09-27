# Realidea's beam rooms (Ruinas, maps 20 and 191-193): a small crystal fires a beam that prisms turn, solved when
# it reaches the large crystal. The beam is traced as launchLaser moves it; turning a prism says its shape,
# firing says the path, and the assist checks each shape against the room's one solution.
module PokeAccess
  module RealideaLasers
    # Per room: :emitter and :receptor crystals, :mirrors in the order the game checks them, :steps (it moves one
    # more), Bronzor's event, and the :goal shape of the mirror on each tile.
    ROOMS = {
      20  => { :emitter => 3, :receptor => 1, :mirrors => [4, 5, 6], :steps => 20,
               :goal => { [11, 7] => :desc, [11, 11] => :desc, [17, 11] => :asc } },
      191 => { :emitter => 3, :receptor => 1, :mirrors => [18, 4, 15, 16, 5, 14, 19, 17, 20, 13], :steps => 38,
               :goal => { [8, 5] => :asc, [13, 5] => :desc, [14, 5] => :asc, [15, 5] => :desc, [10, 7] => :asc,
                          [15, 7] => :asc, [10, 10] => :desc, [13, 10] => :asc, [14, 11] => :desc, [17, 11] => :asc } },
      192 => { :emitter => 3, :receptor => 1, :mirrors => [14, 5, 6, 15, 18, 16, 17], :steps => 40, :bronzor => 14,
               :goal => { [11, 7] => :desc, [9, 5] => :asc, [14, 5] => :desc, [11, 11] => :desc, [14, 11] => :asc,
                          [9, 12] => :desc, [17, 12] => :asc } },
      193 => { :emitter => 3, :receptor => 1, :mirrors => [14, 5, 6, 15, 18, 16, 17], :steps => 46, :bronzor => 14,
               :goal => { [10, 10] => :desc, [14, 5] => :asc, [17, 5] => :desc, [18, 7] => :desc, [17, 10] => :asc,
                          [14, 12] => :desc, [18, 12] => :asc } }
    }
    # The event every room parks the drawn beam in.
    BEAM = 10
    # Where a mirror sends a beam, by the mirror's shape and the beam's direction.
    TURN = { :desc => { 2 => 6, 4 => 8, 6 => 2, 8 => 4 }, :asc => { 2 => 4, 4 => 2, 6 => 8, 8 => 6 } }
    # A direction spoken as where the beam heads, and as the edge a beam heading that way is lost by.
    HEADING = { 2 => :rea_laser_to_down, 4 => :rea_laser_to_left, 6 => :rea_laser_to_right, 8 => :rea_laser_to_up }
    EDGE = { 2 => :rea_laser_by_down, 4 => :rea_laser_by_left, 6 => :rea_laser_by_right, 8 => :rea_laser_by_up }
    SHAPE = { :asc => :rea_laser_asc, :desc => :rea_laser_desc }

    # The beam room the player is in, or nil.
    def self.room
      ROOMS[($game_map.map_id rescue 0)]
    end

    # An event of the map, or nil.
    def self.event(id)
      ($game_map.events[id.to_i] rescue nil)
    end

    # The shape a mirror facing dir draws.
    def self.shape(dir)
      (dir == 2 || dir == 8) ? :desc : :asc
    end

    # launchLaser step for step: the beam moves first, turns on every mirror of its tile in the order given, and
    # ends on the receiver, or on column or row 0 once the map has wrapped it round; steps + 1 moves at most.
    # param board {:w, :h, :from => [x, y], :dir, :to => [x, y], :steps, :mirrors => [[id, x, y, shape], ...]}
    # returns [outcome (:hit, :lost or :stop), the mirrors it met as [[id, new direction], ...], its last direction]
    def self.trace(board)
      x, y = board[:from]
      d = board[:dir]
      hops = []
      (board[:steps] + 1).times do
        x = (x + PokeAccess::DIR_DELTA[d][0]) % board[:w]
        y = (y + PokeAccess::DIR_DELTA[d][1]) % board[:h]
        board[:mirrors].each do |m|
          next unless m[1] == x && m[2] == y
          d = TURN[m[3]][d]
          hops.push([m[0], d])
        end
        return [:hit, hops, d] if x == board[:to][0] && y == board[:to][1]
        return [:lost, hops, d] if x == 0 || y == 0
      end
      [:stop, hops, d]
    end

    # The room as it stands, for trace: the crystals, the map's size and every mirror where it is and as it faces.
    # param args launchLaser's arguments (emitter, beam, receiver, mirrors, steps), or nil for the room's own
    def self.board(r, args = nil)
      em = event(args ? args[0] : r[:emitter])
      rc = event(args ? args[2] : r[:receptor])
      return nil unless em && rc
      ids = args ? Array(args[3]) : r[:mirrors]
      mirrors = ids.map { |id| e = event(id); e && [e.id, e.x, e.y, shape(e.direction)] }.compact
      { :w => $game_map.width, :h => $game_map.height, :from => [em.x, em.y], :dir => em.direction,
        :to => [rc.x, rc.y], :steps => (args ? args[4] : r[:steps]).to_i, :mirrors => mirrors }
    end

    # The room's prisms, Bronzor aside, in reading order: row by row, left to right. Their numbers when spoken.
    def self.prisms(r)
      r[:mirrors].reject { |id| id == r[:bronzor] }.map { |id| event(id) }.compact.sort_by { |e| [e.y, e.x] }.map { |e| e.id }
    end

    # True once Bronzor, beaten, has settled in its gap and turns like a prism.
    def self.bronzor_placed?(r)
      mid = $game_map.map_id
      r[:bronzor] && $game_self_switches[[mid, r[:bronzor], "A"]] && !$game_self_switches[[mid, r[:bronzor], "B"]] ? true : false
    end

    # Bronzor as the game names its species (the event is named "actualizar").
    def self.bronzor_name(r)
      e = event(r[:bronzor])
      (e && PokeAccess::Locator.sprite_species(e.character_name.to_s)) || PokeAccess::I18n.t(:rea_laser_mirror)
    end

    # A mirror as it is spoken: its prism number, or Bronzor.
    def self.mirror_name(r, id)
      return bronzor_name(r) if id == r[:bronzor]
      PokeAccess::I18n.t(:rea_laser_prism, :n => prisms(r).index(id).to_i + 1)
    end

    # "Prisma 2: diagonal descendente", and with the assist whether that is the shape it must end in.
    # param verdict false to leave the assist's verdict out
    def self.mirror_line(r, id, verdict = true)
      e = event(id)
      return "" unless e
      s = shape(e.direction)
      line = PokeAccess::I18n.t(:rea_laser_shape, :name => mirror_name(r, id), :shape => PokeAccess::I18n.t(SHAPE[s]))
      v = verdict ? verdict_of(r, e) : nil
      v ? "#{line}, #{v}" : line
    end

    # With the assist, whether a mirror stands as the solution wants it; nil without it.
    def self.verdict_of(r, e)
      return nil unless PokeAccess::Puzzles.assist?
      want = r[:goal][[e.x, e.y]]
      return nil unless want
      want == shape(e.direction) ? PokeAccess::I18n.t(:rea_laser_ok) : PokeAccess::I18n.t(:rea_laser_goal, :shape => PokeAccess::I18n.t(SHAPE[want]))
    end

    # The mirrors the solution wants turned: the prisms in reading order, then Bronzor once it is in its gap.
    def self.wrong_mirrors(r)
      ids = prisms(r)
      ids.push(r[:bronzor]) if bronzor_placed?(r)
      ids.select do |id|
        e = event(id)
        want = e && r[:goal][[e.x, e.y]]
        want && want != shape(e.direction)
      end
    end

    # A shot as the player hears it: the whole path when it misses, just the arrival when it reaches the crystal.
    def self.shot_line(r, b, t)
      outcome, hops, d = t
      return PokeAccess::I18n.t(:rea_laser_hit) if outcome == :hit
      parts = [PokeAccess::I18n.t(:rea_laser_start, :dir => PokeAccess::I18n.t(HEADING[b[:dir]]))]
      hops.each { |id, nd| parts.push(PokeAccess::I18n.t(:rea_laser_hop, :name => mirror_name(r, id), :dir => PokeAccess::I18n.t(HEADING[nd]))) }
      parts.push(outcome == :lost ? PokeAccess::I18n.t(:rea_laser_lost, :side => PokeAccess::I18n.t(EDGE[d])) : PokeAccess::I18n.t(:rea_laser_stop))
      parts.join("; ")
    end

    # With the assist, what to do next: beat Bronzor while its gap is empty, else turn the first wrong mirror the
    # beam crosses, else the first wrong one in reading order; nil when all stand right.
    # param t a trace to follow, or nil
    def self.next_step(r, t = nil)
      return PokeAccess::I18n.t(:rea_laser_missing, :name => bronzor_name(r)) if r[:bronzor] && !bronzor_placed?(r)
      wrong = wrong_mirrors(r)
      return nil if wrong.empty?
      along = t && t[1].map { |id, _d| id }.find { |id| wrong.include?(id) }
      PokeAccess::I18n.t(:rea_laser_todo, :list => mirror_name(r, along || wrong[0]))
    end

    # After a prism, or Bronzor in its gap, is turned: its new shape.
    def self.rotated(id)
      r = room
      return unless r && r[:mirrors].include?(id.to_i)
      return if id.to_i == r[:bronzor] && !bronzor_placed?(r)
      PokeAccess.speak(mirror_line(r, id.to_i), true)
    rescue StandardError
      nil
    end

    # Before the small crystal fires: the path the beam is about to take, traced from the very arguments the game
    # passes, and with the assist what to turn when it misses. Kept for the info key.
    def self.firing(args)
      r = room
      b = r && board(r, args)
      return unless b
      t = trace(b)
      @last = [b, t]
      line = shot_line(r, b, t)
      hint = (t[0] != :hit && PokeAccess::Puzzles.assist?) ? next_step(r, t) : nil
      PokeAccess.speak(hint ? "#{line}. #{hint}" : line, true)
    rescue StandardError
      nil
    end

    # After the shot: quiet when it went as traced, said only when the game's own answer differs (Bronzor,
    # still wandering, can cross the beam as it flies).
    def self.fired(result)
      return unless room && @last
      hit = (result == true)
      return if hit == (@last[1][0] == :hit)
      PokeAccess.speak(PokeAccess::I18n.t(hit ? :rea_laser_real_hit : :rea_laser_real_miss), false)
    rescue StandardError
      nil
    end

    # Frame, in the Bronzor rooms: says when Bronzor settles in its gap, and the shape it came in with. Arriving on
    # the map, or loading a game there, only takes note.
    def self.poll
      r = room
      return unless r && r[:bronzor]
      placed = bronzor_placed?(r)
      mid = $game_map.map_id
      if @poll_map != mid
        @poll_map = mid
        @placed = placed
        return
      end
      return if placed == @placed
      @placed = placed
      return unless placed
      parts = [PokeAccess::I18n.t(:rea_laser_placed, :name => bronzor_name(r)), mirror_line(r, r[:bronzor], false)]
      parts.push(PokeAccess::I18n.t(:rea_laser_placed_hint)) if PokeAccess::Puzzles.assist?
      PokeAccess.speak(parts.join(". "), false)
    rescue StandardError
      nil
    end

    # The room's piece on (x,y): :emitter, :receptor, or a mirror's id; nil for none.
    def self.piece_at(r, x, y)
      [:emitter, :receptor].each { |k| e = event(r[k]); return k if e && e.x == x && e.y == y }
      r[:mirrors].find { |id| e = event(id); e && e.x == x && e.y == y }
    end

    # What the info key says: the piece in front of the player, or the room with the last shot.
    def self.info_line
      r = room
      return "" unless r
      fx, fy = PokeAccess::Spatial.front_tile
      piece = piece_at(r, fx, fy)
      line = piece && piece_line(r, piece)
      line && !line.empty? ? line : board_line(r)
    end

    # A piece in front of the player: the small crystal with the way it fires, the large one, or a mirror's shape.
    def self.piece_line(r, piece)
      case piece
      when :emitter
        em = event(r[:emitter])
        PokeAccess::I18n.t(:rea_laser_emitter_dir, :dir => PokeAccess::I18n.t(HEADING[em.direction]))
      when :receptor then PokeAccess::I18n.t(:rea_laser_receiver)
      else
        piece == r[:bronzor] && !bronzor_placed?(r) ? nil : mirror_line(r, piece, false)
      end
    end

    # The room: how many prisms, the way the beam leaves, and the last shot fired here.
    def self.board_line(r)
      em = event(r[:emitter])
      line = PokeAccess::I18n.t(:rea_laser_board, :n => prisms(r).length, :dir => PokeAccess::I18n.t(HEADING[em ? em.direction : 6]))
      return line unless @last
      "#{line}. #{PokeAccess::I18n.t(:rea_laser_last, :shot => shot_line(r, @last[0], @last[1]))}"
    end

    # The assist's line for the info key: the verdict on the mirror in front, else what to do next, else that all
    # is set to fire.
    def self.assist_line
      r = room
      return "" unless r
      fx, fy = PokeAccess::Spatial.front_tile
      piece = piece_at(r, fx, fy)
      e = piece.is_a?(Integer) && event(piece)
      return (verdict_of(r, e) || "") if e && !(piece == r[:bronzor] && !bronzor_placed?(r))
      next_step(r, @last && @last[1]) || PokeAccess::I18n.t(:rea_laser_ready)
    end

    # A piece's name for the locator: the crystals by what they are, a mirror by its number and shape, the parked
    # beam as the beam; nil for anything else, left to the locator.
    def self.piece_name(ev)
      r = room
      return nil if r.nil? || ev.is_a?(PokeAccess::Locator::SurfaceTarget) || !ev.respond_to?(:id)
      return PokeAccess::I18n.t(:rea_laser_emitter) if ev.id == r[:emitter]
      return PokeAccess::I18n.t(:rea_laser_receiver) if ev.id == r[:receptor]
      return PokeAccess::I18n.t(:rea_laser_beam) if ev.id == BEAM
      return nil unless r[:mirrors].include?(ev.id)
      ev.id == r[:bronzor] && !bronzor_placed?(r) ? bronzor_name(r) : mirror_line(r, ev.id)
    end

    # The puzzle category's spots for a room: both crystals and every mirror, each named as it stands.
    def self.spots(mid)
      r = ROOMS[mid]
      out = [{ :event => r[:emitter], :label => :rea_laser_emitter }, { :event => r[:receptor], :label => :rea_laser_receiver }]
      r[:mirrors].each { |id| out.push(:event => id, :label => lambda { piece_name(event(id)) || "" }) }
      out
    end

    # True once the room is solved: the small crystal has turned to its spent page.
    def self.solved?
      r = room
      r ? ($game_self_switches[[$game_map.map_id, r[:emitter], "A"]] ? true : false) : false
    end

    # Forgets the last shot and Bronzor's watch (a new map, or the room reloaded after the cutscene).
    def self.reset
      @last = nil
      @poll_map = nil
      @placed = nil
    end
  end
end

PokeAccess::Caches.register(:realidea_lasers) { PokeAccess::RealideaLasers.reset }

PokeAccess::Game.define("realidea") do
  kernel("rotateEvent", :after) { |a, _r| PokeAccess::RealideaLasers.rotated(a[0]) }
  kernel("launchLaser", :before) { |a, _r| PokeAccess::RealideaLasers.firing(a) }
  kernel("launchLaser", :after) { |_a, r| PokeAccess::RealideaLasers.fired(r) }
  poll_each_frame { PokeAccess::RealideaLasers.poll }
  override("PokeAccess::Locator", :target_name) do |_mod, original, args|
    tag = (PokeAccess::Tags.get($game_map.map_id, args[0].id) rescue nil)
    (tag.nil? || tag.to_s.empty? ? PokeAccess::RealideaLasers.piece_name(args[0]) : nil) || original.call
  end
  PokeAccess::RealideaLasers::ROOMS.each_key do |mid|
    puzzle(mid, :kind => :stages, :solved => lambda { PokeAccess::RealideaLasers.solved? },
                :spots => PokeAccess::RealideaLasers.spots(mid),
                :stages => [{ :when => lambda { true },
                              :title => lambda { PokeAccess::RealideaLasers.info_line },
                              :hint => lambda { PokeAccess::RealideaLasers.assist_line } }])
  end
end
