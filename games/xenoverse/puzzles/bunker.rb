# The Bunker Abbandonato of the Canyon Asteroide, after the League. Maps 593 and 599: unseen sensors raise a gate behind the
# player (switches 1089 and 1090; 1096, 1117 and 1118), which the core says as it closes; 'teleport bunker' pads send the
# player back to the start and open every gate, and in 599 bring the cut trees back. Map 596: platforms alike, one set
# dangerous with switch 1093 off and the other with it on, each sending the player back to the entrance (31,41); the wall
# switches that flip it show its state, which is said as it changes; the button at the far end (event 62, switch 1095)
# makes them all safe. Map 602, the Sound Room: eight grids of unseen traps back to (9,7), each with a blue button that
# shows for a moment which tiles are safe; the way across a sighted player reads in that moment is said as it is pressed,
# from the tile the player stands on.
# The third grid has none, and its alarm (events 173 and 174, switch 1128) shuts the player in until a trap is stepped on.
module PokeAccess
  module XenoBunker
    SENSORS = { 593 => [1, 2, 6, 7], 599 => [11, 12, 22, 23, 25, 30], 602 => [173, 174], 603 => [39, 75, 76] }
    BACK_PADS = { 593 => [[13, 14], [22, 4], :xv_bunker_back_gates], 599 => [[10, 21, 27], [31, 18], :xv_bunker_back_trees] }
    PLATFORMS = 596
    PLATFORM = /\Apedanebunker\z/
    ENTRANCE = [31, 41]
    SWITCHES = 1093
    ALL_SAFE = 1095
    SOUND = 602
    SUSPECT = 603
    SOUND_START = [9, 7]
    GRIDS = { 22 => [[6, 3], [2, 1], [6, 2], [8, 1], [6, 3]], 49 => [[6, 4], [8, 1], [6, 3], [2, 3], [4, 3], [2, 2]],
              58 => nil, 80 => [[2, 3], [6, 4]], 82 => [[2, 3], [4, 2], [2, 6], [6, 1], [2, 1], [6, 1], [2, 2]],
              107 => [[2, 5], [4, 1], [2, 4], [6, 1], [2, 2]], 134 => [[2, 12]],
              148 => [[6, 2], [2, 1], [6, 2], [8, 1], [6, 2], [8, 1], [6, 4], [2, 2], [6, 4]] }
    # A grid's button => the tile its way starts from.
    ENTRIES = { 22 => [27, 7], 49 => [49, 7], 80 => [31, 23], 82 => [43, 48], 107 => [25, 49], 134 => [56, 48],
                148 => [46, 79] }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    STEPS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # Tiles the walk to a grid's start looks through before it gives up: four times the most any side of a button needs.
    REACH = 64
    ALL_OFF = 1130

    # True while a platform's live page sends the player back.
    def self.dangerous?(ev)
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| (c.code rescue 0) == 201 }
    end

    # A platform's name; with the assist, whether it sends the player back now.
    def self.platform_label(ev)
      return :xv_bunker_platform unless PokeAccess::Puzzles.assist?
      dangerous?(ev) ? :xv_bunker_platform_trap : :xv_bunker_platform_safe
    end

    # The way across a grid as its flash shows it, from where the player stands, said as "3 right, 1 down"; from the
    # grid's start where no walk there is found.
    def self.flash_line(button)
      legs = GRIDS[button]
      return :xv_bunker_flash_none unless legs
      t = PokeAccess::I18n
      walk = approach(button)
      path = joined(walk || [], legs).map { |d, n| t.t(:loc_leg, :n => n, :dir => t.t(DIRS[d])) }.join(", ")
      [walk ? :xv_bunker_flash : :xv_bunker_flash_entry, { :path => path }]
    end

    # The legs of the shortest walk from the player to the tile a grid's way starts from, by the steps the routes keep
    # (walls, the button and drawn events) and never onto a tile whose event sends the player off (the traps); nil when
    # none is found within REACH tiles.
    def self.approach(button)
      entry = ENTRIES[button]
      start = [$game_player.x, $game_player.y]
      traps = trap_tiles
      probe = PokeAccess::World::Probe
      probe.session do
        parent = { start => nil }
        queue = [start]
        until queue.empty? || parent.size > REACH
          cur = queue.shift
          return legs_of(parent, cur) if cur == entry
          STEPS.each do |d, (dx, dy)|
            nxt = [cur[0] + dx, cur[1] + dy]
            next if parent.key?(nxt) || traps[nxt] || !probe.step?(cur[0], cur[1], d)
            parent[nxt] = [cur, d]
            queue.push(nxt)
          end
        end
        nil
      end
    end

    # The tiles of the map's events whose live page transfers the player: the grids' traps.
    def self.trap_tiles
      out = {}
      ($game_map.events || {}).each_value do |ev|
        list = PokeAccess.ivar(ev, :@list)
        out[[ev.x, ev.y]] = true if list.is_a?(Array) && list.any? { |c| (c.code rescue 0) == 201 }
      end
      out
    end

    # The walk to tile as legs, read back through the search's parents.
    def self.legs_of(parent, tile)
      dirs = []
      while parent[tile]
        tile, d = parent[tile]
        dirs.unshift(d)
      end
      joined(dirs.map { |d| [d, 1] }, [])
    end

    # Two lists of legs as one, a leg that goes on the way the last went merged into it.
    def self.joined(first, second)
      out = []
      (first.dup.concat(second)).each do |d, n|
        if out.last && out.last[0] == d
          out.last[1] += n
        else
          out.push([d, n])
        end
      end
      out
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  bunker = PokeAccess::XenoBunker
  bunker::BACK_PADS.each do |map, (pads, start, line)|
    mechanic(:state, map) do
      auto
      name bunker::SENSORS[map], :xv_bunker_sensor, :assist => true
      sent_back line, :to => start, :events => pads
    end
  end

  mechanic(:state, bunker::PLATFORMS) do
    auto
    name bunker::PLATFORM, lambda { |ev| bunker.platform_label(ev) }, :when => false
    watch :switch => bunker::SWITCHES, :label => :xv_bunker_switches, :on => :xv_bunker_switch_on,
          :off => :xv_bunker_switch_off
    sent_back :xv_bunker_platform_back, :to => bunker::ENTRANCE
    hint :xv_bunker_platforms_hint
    solved { $game_switches[bunker::ALL_SAFE] }
  end

  mechanic(:state, bunker::SOUND) do
    auto
    name bunker::GRIDS.keys, :xv_bunker_button
    bunker::GRIDS.each_key { |id| on_use id, lambda { bunker.flash_line(id) } }
    name bunker::SENSORS[bunker::SOUND], :xv_bunker_sensor, :assist => true
    sent_back :xv_bunker_trap_back, :to => bunker::SOUND_START
    sent_back :xv_bunker_trap_back, :maps => [bunker::SUSPECT], :to => bunker::SOUND_START
    solved(nil, :quiet => true) { $game_switches[bunker::ALL_OFF] }
  end

  mechanic(:state, bunker::SUSPECT) do
    auto
    name bunker::SENSORS[bunker::SUSPECT], :xv_bunker_sensor, :assist => true
  end
end
