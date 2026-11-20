# Moonlit Forest's nightmare ride (map 824, switch 806, the player's own steps locked by switch 815): the player rides a
# Magikarp (event 4) that hops the way the player faces as the use key goes down: one tile, or two once the long hop is
# charged (switch 807, which event 39 turns on, with animation 18, when the key is held about 24 frames, and the long
# hop turns off). Three nightmares (events 7, 8 and 10) give chase once it passes x 17, 24 and 40; the silhouette at
# the far end (event 42) ends the dream, and a landing at y 10 or above leaves the ride (event 37). The controls are
# said once a visit; each hop or turn says whether one and two tiles ahead are free, blocked or the way out, and the
# charge is said as it comes; with the puzzle assist both also give the next press of the shortest way to the
# silhouette, and so does a charge spent without moving, once the Magikarp has stayed put a few frames. A nightmare is
# said as it appears, where it is, and again as it closes in. What a frame has to say goes out as one line, which cuts
# what came before only when it answers a hop or a turn, and never while a nightmare that just appeared is being said.
module PokeAccess
  module IFMagikarpRide
    MAP = 824
    RIDING = 806
    CHARGE = 807
    KARP = 4
    NIGHTMARES = [7, 8, 10]
    GOAL = 42
    CLOSE = 3
    LEAVE_Y = 10
    SETTLE = 6
    CALM = 120
    DIRS = { 8 => [0, -1, :dir_up], 6 => [1, 0, :dir_right], 2 => [0, 1, :dir_down], 4 => [-1, 0, :dir_left] }

    @state = nil
    @told = false

    # Per-frame entry point: the ride's lines while it runs; leaving the map lets the controls be said again.
    def self.poll
      @told = false unless $game_map && $game_map.map_id == MAP
      return (@state = nil) unless $game_map && $game_map.map_id == MAP && $game_switches[RIDING]
      karp = $game_map.events[KARP]
      return unless karp
      parts = []
      opening = @state.nil?
      unless @state
        @state = { :key => nil, :seen => {}, :near => nil, :charged => charged?, :frame => 0, :calm => 0,
                   :spent => nil }
        parts.push(PokeAccess::I18n.t(:if_karp_rule)) unless @told
        @told = true
      end
      @state[:frame] += 1
      @free = {}
      hop = ahead(karp, parts)
      charge(karp, parts)
      spent(karp, parts, hop)
      cut = hop && !opening && @state[:frame] >= @state[:calm]
      @state[:calm] = @state[:frame] + CALM if nightmares(karp, parts)
      PokeAccess.speak(PokeAccess.sentences(parts), cut) unless parts.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True while the long hop is charged.
    def self.charged?
      $game_switches[CHARGE] ? true : false
    end

    # The charge as it comes, with the assist the next press; a spent charge is noted for spent.
    def self.charge(karp, parts)
      now = charged?
      return if now == @state[:charged]
      @state[:charged] = now
      @state[:spent] = now ? nil : [@state[:key], @state[:frame] + SETTLE]
      return unless now
      parts.push(PokeAccess::I18n.t(:if_karp_charged))
      hop = PokeAccess::Puzzles.assist? ? next_hop(karp, true) : nil
      parts.push(hop) if hop
    end

    # With the assist, the next press once a spent charge has left the Magikarp where it was for SETTLE frames, with no
    # hop or turn since.
    def self.spent(karp, parts, hop)
      mark = @state[:spent]
      return unless mark
      return @state[:spent] = nil if hop || @state[:key] != mark[0]
      return if @state[:frame] < mark[1]
      @state[:spent] = nil
      line = PokeAccess::Puzzles.assist? ? next_hop(karp, charged?) : nil
      parts.push(line) if line
    end

    # True if the Magikarp can land on a tile, as its jump checks it; kept for one frame, as event 39 moves.
    def self.free?(karp, x, y)
      key = [x, y]
      return @free[key] if @free.key?(key)
      @free[key] = karp.passable?(x, y, 0) ? true : false
    end

    # What a landing tile is: blocked, the way out of the ride, or free.
    def self.landing(karp, x, y)
      return :if_karp_blocked unless free?(karp, x, y)
      y <= LEAVE_Y ? :if_karp_exit : :if_karp_free
    end

    # On each hop or turn: whether one and two tiles ahead are free, and with the assist the next press; true when
    # there was one.
    def self.ahead(karp, parts)
      d = $game_player.direction
      step = DIRS[d]
      key = [karp.x, karp.y, d]
      return false if step.nil? || key == @state[:key]
      @state[:key] = key
      one = landing(karp, karp.x + step[0], karp.y + step[1])
      two = landing(karp, karp.x + 2 * step[0], karp.y + 2 * step[1])
      parts.push(PokeAccess::I18n.t(:if_karp_ahead, :one => PokeAccess::I18n.t(one), :two => PokeAccess::I18n.t(two)))
      hop = PokeAccess::Puzzles.assist? ? next_hop(karp, charged?) : nil
      parts.push(hop) if hop
      true
    end

    # The tiles beside the silhouette, where the ride ends.
    def self.goals
      ev = $game_map.events[GOAL]
      return [] unless ev
      DIRS.values.map { |dx, dy, _w| [ev.x + dx, ev.y + dy] }.reject { |_x, y| y <= LEAVE_Y }
    end

    # The first press of the shortest way from the Magikarp to the silhouette, as said, or nil when there is none. A
    # state is a tile and the charge; a press hops two when charged, one when not, stays put when the landing is
    # blocked, spends the charge, and charges it again when held.
    def self.next_hop(karp, charged)
      targets = goals
      from = [karp.x, karp.y]
      return nil if targets.empty? || targets.include?(from)
      start = [from, charged]
      prev = { start => nil }
      queue = [start]
      until queue.empty?
        cur = queue.shift
        return hop_words(karp, prev, cur) if targets.include?(cur[0])
        n = cur[1] ? 2 : 1
        DIRS.each do |d, (dx, dy, _w)|
          land = [cur[0][0] + n * dx, cur[0][1] + n * dy]
          open = free?(karp, land[0], land[1])
          next if open && land[1] <= LEAVE_Y
          tile = open ? land : cur[0]
          [false, true].each do |hold|
            key = [tile, hold]
            next if prev.key?(key)
            prev[key] = [cur, d, n, hold, !open]
            queue.push(key)
          end
        end
      end
      nil
    end

    # The first press that led to a state, as said: a hop or a long hop that way, held to charge; or a press that stays
    # put, held to charge or quick to spend the charge, facing the way of the press after it when that way is blocked
    # too.
    def self.hop_words(karp, prev, state)
      chain = [prev[state]]
      chain.unshift(prev[chain[0][0]]) while prev[chain[0][0]]
      from, d, n, hold, stays = chain[0]
      if stays && chain[1]
        dx, dy, _w = DIRS[chain[1][1]]
        d = chain[1][1] unless free?(karp, from[0][0] + n * dx, from[0][1] + n * dy)
      end
      word = PokeAccess::I18n.t(DIRS[d][2])
      if stays
        press = PokeAccess::I18n.t(hold ? :if_karp_charge_here : :if_karp_spend, :dir => word)
        return PokeAccess::I18n.t(:if_karp_next, :hop => press)
      end
      hop = PokeAccess::I18n.t(n == 2 ? :if_karp_long : :if_karp_short, :dir => word)
      hop = PokeAccess::I18n.t(:if_karp_hold, :hop => hop) if hold
      PokeAccess::I18n.t(:if_karp_next, :hop => hop)
    end

    # A nightmare once as it appears and where, and the nearest again at each distance up to CLOSE; true when one
    # appeared.
    def self.nightmares(karp, parts)
      near = nil
      appeared = false
      NIGHTMARES.each do |id|
        ev = $game_map.events[id]
        next unless ev && !ev.character_name.to_s.empty?
        dx = ev.x - karp.x
        dy = ev.y - karp.y
        unless @state[:seen][id]
          @state[:seen][id] = true
          appeared = true
          parts.push(PokeAccess::I18n.t(:if_karp_nightmare, :where => PokeAccess::Locator.dir_phrase(dx, dy)))
        end
        dist = dx.abs + dy.abs
        near = dist if near.nil? || dist < near
      end
      near = nil if near && near > CLOSE
      if near != @state[:near]
        @state[:near] = near
        parts.push(PokeAccess::I18n.t(:if_karp_close, :n => near)) if near
      end
      appeared
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  poll_each_frame { PokeAccess::IFMagikarpRide.poll }
end
