# Aderyn's gym in Celeste City (map 24): crystal walls (events 3 to 77, each gone while its switch, 235 to 252, is on) split
# the floor into rooms, and the gym is crossed by touching totems. Six totems (78 to 82 and 86) each set some walls open and
# others shut, and the second touch does the opposite (their self switch A picks the page); three special ones (83 to 85)
# each open a wall of the central corridor once. Entering by the teleporter opens switch 248. The walls themselves are said
# by the core as they open and close (auto); this file names the totems, says the room's rule and, with the assist, the next
# totem of a shortest plan from where the player stands, searched over the rooms below (rooms and links read off the map).
module PokeAccess
  module DesolationCelesteGym
    MAP = 24
    AIDE_ROOM = 3
    ENTRY_ROOM = 12
    FIRST_SWITCH = 235
    # Each wall switch and the rooms its wall joins while open.
    LINKS = { 235 => [7, 10], 236 => [10, 14], 237 => [11, 13, 14], 238 => [8, 11], 239 => [5, 8], 240 => [4, 7],
              241 => [2, 4], 242 => [2, 5], 243 => [1, 2], 244 => [4, 6], 245 => [5, 6], 246 => [8, 9], 247 => [7, 9],
              248 => [10, 12], 249 => [11, 12, 13], 250 => [3, 6], 251 => [6, 9], 252 => [9, 12] }
    # The six totems: room it is touched from, switches its first page turns on and those it turns off; the second page
    # does the opposite.
    TOTEMS = { 78 => [10, [235, 249], [247, 246]], 79 => [7, [240, 238, 247], [241, 243]],
               80 => [4, [245, 239], [243, 235]], 81 => [8, [237], [240, 248]], 82 => [5, [236, 242], [237, 244]],
               86 => [11, [242, 246], [241, 249]] }
    # The special totems: room and the switch they turn on once.
    SPECIAL = { 83 => [9, 252], 84 => [14, 251], 85 => [1, 250] }
    NAMES = { 78 => :deso_celeste_totem_west_low, 79 => :deso_celeste_totem_west_mid, 80 => :deso_celeste_totem_west_high,
              86 => :deso_celeste_totem_east_low, 81 => :deso_celeste_totem_east_mid, 82 => :deso_celeste_totem_east_high,
              84 => :deso_celeste_special_south, 83 => :deso_celeste_special_middle, 85 => :deso_celeste_special_north }
    # Rooms as boxes [x0, x1, y0, y1], tried in this order (an earlier box wins where two overlap).
    ROOMS = [[3, [9, 13, 22, 26]], [13, [14, 15, 48, 48]], [13, [15, 16, 49, 51]], [12, [8, 14, 43, 51]], [14, [3, 19, 51, 56]],
             [1, [6, 16, 8, 14]], [2, [2, 20, 16, 26]], [4, [2, 7, 27, 33]], [5, [15, 20, 27, 33]], [6, [9, 13, 29, 33]],
             [7, [2, 7, 35, 40]], [8, [15, 20, 35, 40]], [9, [9, 13, 36, 40]], [10, [2, 7, 42, 49]],
             [11, [15, 20, 42, 49]]]
    SELF_BITS = [78, 79, 80, 81, 82, 86]
    # The order totems are tried in, so a plan comes out the same on every Ruby.
    TRIES = [78, 79, 80, 81, 82, 86, 83, 84, 85]

    @plans = {}
    @room = nil

    # The live state: a bit per wall switch from 235, then a bit per totem whose self switch A is on.
    def self.mask
      m = 0
      LINKS.each_key { |s| m |= 1 << (s - FIRST_SWITCH) if $game_switches[s] }
      SELF_BITS.each_with_index { |id, i| m |= 1 << (18 + i) if $game_self_switches[[MAP, id, "A"]] }
      m
    end

    # The room the player stands in, or the last one known while on a wall's tile.
    def self.room
      x = $game_player.x
      y = $game_player.y
      hit = ROOMS.find { |_r, b| x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3] }
      @room = hit[0] if hit
      @room || ENTRY_ROOM
    end

    # The rooms reached from room under mask.
    def self.reach(m, room)
      seen = { room => true }
      queue = [room]
      until queue.empty?
        r = queue.shift
        LINKS.each do |s, rooms|
          next if m[s - FIRST_SWITCH] == 0 || !rooms.include?(r)
          rooms.each do |o|
            next if seen[o]
            seen[o] = true
            queue.push(o)
          end
        end
      end
      seen
    end

    # The state after touching a totem, or nil when the touch changes nothing.
    def self.touch(m, id)
      sp = SPECIAL[id]
      if sp
        bit = 1 << (sp[1] - FIRST_SWITCH)
        return (m & bit) == 0 ? m | bit : nil
      end
      _room, ons, offs = TOTEMS[id]
      sb = 1 << (18 + SELF_BITS.index(id))
      second = (m & sb) != 0
      ons, offs = offs, ons if second
      n = m
      ons.each { |s| n |= 1 << (s - FIRST_SWITCH) }
      offs.each { |s| n &= ~(1 << (s - FIRST_SWITCH)) }
      second ? n & ~sb : n | sb
    end

    # [first totem, touches] of a shortest plan from mask and room to Aderyn's room; [nil, 0] when already open.
    def self.plan(m, room)
      start = reach(m, room)
      key = [m, start.keys.min]
      return @plans[key] if @plans.key?(key)
      seen = { key => true }
      queue = [[m, start, nil, 0]]
      found = nil
      until queue.empty?
        cur, rooms, first, steps = queue.shift
        if rooms[AIDE_ROOM]
          found = [first, steps]
          break
        end
        TRIES.each do |id|
          at = (TOTEMS[id] || SPECIAL[id])[0]
          next unless rooms[at]
          n = touch(cur, id)
          next unless n
          nr = reach(n, at)
          k = [n, nr.keys.min]
          next if seen[k]
          seen[k] = true
          queue.push([n, nr, first || id, steps + 1])
        end
      end
      @plans[key] = found
    end

    # The next totem and how many touches are left from where the player stands, or nil.
    def self.next_step
      return nil unless $game_map.map_id == MAP && !solved?
      now = [(Graphics.frame_count rescue 0), PokeAccess::World::Epoch.frame, $game_player.x, $game_player.y]
      return @step if @step_frame == now
      @step_frame = now
      @step = plan(mask, room)
    end

    # The info key's hint with the assist: the next totem and the touches left.
    def self.hint
      step = next_step
      return nil unless step && step[0]
      [:deso_celeste_next, { :name => PokeAccess::I18n.t(NAMES[step[0]]), :n => step[1] }]
    end

    # True once Aderyn has given the badge.
    def self.solved?
      $game_switches[253] ? true : false
    end

    # Drops what was planned and the room last known.
    def self.forget
      @plans = {}
      @room = nil
      @step_frame = nil
      @step = nil
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::DesolationCelesteGym.forget }

PokeAccess::Game.define("desolation") do
  gym = PokeAccess::DesolationCelesteGym
  mechanic(:state, gym::MAP) do
    auto
    gym::NAMES.each { |id, key| name id, key }
    arrival_hint :deso_celeste_rule, :once => true
    [true, false].each do |even|
      gym::NAMES.each_key do |id|
        phase(lambda { PokeAccess::Puzzles.assist? && (s = gym.next_step) && s[0] == id && s[1].even? == even },
              :title => lambda { gym.hint })
      end
    end
    solved { gym.solved? }
  end
end
