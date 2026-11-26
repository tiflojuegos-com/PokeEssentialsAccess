# Aventurine Woods (maps 283, 282 and 284 south, 288 and 289 north): Honey on a tree calls a Pinsir and a Heracross, and
# beating one has the other break the log or web in the way, once, or sends it away. ORDER is the order everything falls
# in, simulated over the woods with the mod's moves; NEEDS holds an entry back while what its way crosses stands. With
# Blindstep the Tauros goes through tall grass, and BLIND_WAYS gives the shorter way and needs where that changes them.
module PokeAccess
  module RebornAventurineBugs
    TANZAN = [:in, 17, 51, 272]
    CELESTINE = [:in, 12, 19, 434]
    WEST = [310, 367, 368, 369, 370, 371, 372, 373, 375, 379]
    # Per map, the entries [switch, how] in falling order; how is :walk, :in from another place, or a Tauros ride in by
    # a Route 1 exit (:ride to the tree, :off with the tile to get off on, :far to the west, :east on foot).
    ORDER = {
      282 => [[372, TANZAN], [373, TANZAN], [379, TANZAN], [374, TANZAN], [300, :walk], [375, TANZAN], [376, TANZAN]],
      283 => [[310, :walk], [369, [:off, 34, 39, 26, 6, 31, 13]], [368, [:off, 34, 39, 26, 6, 38, 26]],
              [367, [:off, 34, 39, 26, 6, 38, 26, :same]], [370, [:off, 34, 39, 26, 6, 47, 37]],
              [371, [:ride, 72, 39, 55, 6]]],
      284 => [[305, :walk], [377, :walk], [378, :walk], [391, [:far, 72, 39, 55, 6, 0, 48, 34, 49]]],
      288 => [[342, CELESTINE], [343, CELESTINE], [344, CELESTINE], [341, [:east, 66, 8, 0, 30, 69, 30]]],
      289 => [[302, :walk], [307, :walk], [327, :walk], [328, :walk], [339, :walk], [340, :walk]]
    }
    NEEDS = { 341 => [302], 371 => [310], 376 => [300], 377 => [305], 378 => [305],
              391 => [310, 367, 368, 369, 370, 371, 372, 373, 375, 379, 300, 305, 377, 378] }
    BLIND_WAYS = { 371 => [[:ride, 34, 39, 26, 6], []], 391 => [[:ride, 59, 43, 36, 8], [305, 377, 378]] }
    RIDES = [:ride, :off, :far]
    PAIR = { 391 => [48, 30] }
    GATES = {
      282 => [33, 46, :rbrj_aw_spot_suicune, 1374,
              [WEST, :rbrj4_aw_gate_far, { :rx => 72, :ry => 39, :ex => 55, :ey => 6, :bx => 0, :by => 42 }],
              [[375], :rbrj_aw_gate_suicune, { :ex => 12, :ey => 8 }]],
      289 => [57, 9, :rbrj_aw_spot_raikou, 1373, [[328, 339], :rbrj_aw_gate_raikou, { :ex => 23, :ey => 51 }],
              [[], :rbrj_aw_gate_raikou, { :ex => 80, :ey => 51 }]]
    }
    GATE_VAR = 572
    MAPS = [282, 283, 284, 288, 289]
    BUGS = /\A(Pinsir|Heracross)\z/
    OBSTACLES = {
      282 => { 300 => [49, 50, 51], 372 => (60..63).to_a, 373 => [27] + (64..74).to_a, 374 => (75..86).to_a,
               375 => [87, 88], 376 => (89..92).to_a, 379 => (97..100).to_a },
      283 => { 310 => (56..59).to_a, 312 => [50, 51, 52], 367 => (69..80).to_a, 368 => [81, 82, 83],
               369 => (84..95).to_a, 370 => (60..63).to_a, 371 => (96..106).to_a },
      284 => { 305 => (28..31).to_a, 377 => (37..40).to_a, 378 => (41..52).to_a },
      288 => { 309 => [27, 28], 341 => (36..47).to_a, 342 => (50..61).to_a, 343 => [64, 65, 66], 344 => (67..78).to_a },
      289 => { 302 => [27, 28, 29], 307 => [33, 34, 35], 327 => [43, 44], 328 => (45..56).to_a, 339 => (61..64).to_a,
               340 => [36, 37, 38] }
    }
    # The Route 1 logs rammed aside when their pair's Tauros is beaten (route1_bulls.rb).
    BULLS = { 300 => [59, 27, 299], 302 => [66, 16, 301], 305 => [61, 32, 304], 307 => [70, 23, 306],
              309 => [76, 26, 308], 310 => [72, 25, 311], 312 => [12, 26, 313] }

    # What beating a bug has its partner break, [switch, :log | :web] (a web when its page tells of one), or nil if
    # nothing.
    def self.breaks(ev)
      breaks_in(PokeAccess.ivar(ev, :@list) || [])
    end

    # What a bug's page list has its partner break, as breaks says.
    def self.breaks_in(list)
      guard = nil
      hit = nil
      list.each do |c|
        pr = c.parameters || []
        guard = pr[1] if c.code == 111 && pr[0] == 0 && pr[2] == 1
        hit = guard if !hit && guard && c.code == 121 && pr[0] == guard && pr[2] == 0
      end
      return nil unless hit
      web = list.any? { |c| c.code == 101 && (c.parameters || [])[0].to_s =~ /web/i }
      [hit, web ? :web : :log]
    end

    # With the assist, what beating a bug does: its partner breaks the log or web still standing, or nothing.
    def self.label(ev)
      b = breaks(ev)
      return [:rbh_aw_bug_plain, { :name => ev.name }] unless b && !$game_switches[b[0]]
      [b[1] == :web ? :rbh_aw_bug_web : :rbh_aw_bug_log, { :name => ev.name }]
    end

    # Forgets the bugs read on the last map.
    def self.forget
      @openers = nil
    end

    # The switch that clears an obstacle of this map, or nil.
    def self.switch_of(ev)
      (OBSTACLES[$game_map.map_id] || {}).each { |sw, ids| return sw if ids.include?(ev.id) }
      nil
    end

    # The bugs of this map by what beating them clears, {switch => [kind, bug]}, read once a map from all their pages.
    def self.openers
      return @openers[1] if @openers && @openers[0] == $game_map.map_id
      found = {}
      $game_map.events.each_value do |bug|
        next unless bug.name.to_s =~ BUGS
        rpg = PokeAccess.ivar(bug, :@event)
        lists = rpg ? rpg.pages.map { |pg| pg.list || [] } : [PokeAccess.ivar(bug, :@list) || []]
        lists.each do |list|
          b = breaks_in(list)
          found[b[0]] = [b[1], bug] if b
        end
      end
      @openers = [$game_map.map_id, found]
      found
    end

    # A log or web as drawn; with the assist, with what clears it: the bug to beat at its honey tree, or Route 1's Tauros.
    def self.obstacle_label(ev)
      sw = switch_of(ev)
      return nil unless sw
      if BULLS[sw]
        return :rbre_aw_log unless PokeAccess::Puzzles.assist?
        return [:rbre_aw_log_bull, { :x => BULLS[sw][0], :y => BULLS[sw][1] }]
      end
      kind, bug = openers[sw]
      return nil unless kind
      return(kind == :web ? :rbre_aw_web : :rbre_aw_log) unless PokeAccess::Puzzles.assist?
      [kind == :web ? :rbre_aw_web_bug : :rbre_aw_log_bug, { :name => bug.name, :x => bug.x, :y => bug.y }]
    end

    # True while Blindstep lets the Tauros into tall grass.
    def self.blindstep?
      ($game_switches[:Blindstep] rescue false) ? true : false
    end

    # This wood's order.
    def self.order
      ORDER[$game_map.map_id] || []
    end

    # True once a Route 1 log can no longer be rammed: its pair was ridden, the pair's switch on and the log's off.
    def self.lost?(sw)
      b = BULLS[sw]
      b && $game_switches[b[2]] && !$game_switches[sw] ? true : false
    end

    # An entry's way, how as ORDER gives it, and what that way crosses: with Blindstep, BLIND_WAYS's where it has one.
    def self.way(sw, how)
      blind = blindstep? && BLIND_WAYS[sw]
      blind ? blind : [how, NEEDS[sw] || []]
    end

    # What an entry's way crosses, as way gives it.
    def self.needs(sw)
      way(sw, nil)[1]
    end

    # True while an entry can still fall: neither it nor a log its way crosses is lost.
    def self.open?(sw)
      !lost?(sw) && needs(sw).none? { |n| lost?(n) }
    end

    # The next log, web or bug pair of this wood's order still to fall, [switch, how] with the way it takes now, or nil
    # once none is left.
    def self.next_entry
      entry = order.find { |sw, _how| !$game_switches[sw] && open?(sw) }
      entry && [entry[0], way(*entry)[0]]
    end

    # The Honey this wood's order still needs, one for each log or web a bug breaks.
    def self.honey_left
      order.count { |sw, _how| !BULLS[sw] && !PAIR[sw] && !$game_switches[sw] && open?(sw) }
    end

    # True for an entry still to fall that takes a Tauros ride of its own (one marked :same takes none).
    def self.ride_step?(sw, how)
      how.is_a?(Array) && RIDES.include?(how[0]) && !how.include?(:same) && !$game_switches[sw] && open?(sw)
    end

    # The Tauros rides every wood's order still asks for.
    def self.ride_steps_left
      ORDER.values.inject(0) { |sum, steps| sum + steps.count { |sw, how| ride_step?(sw, way(sw, how)[0]) } }
    end

    # The rides still asked for: the woods' orders and each standing New World gate whose beast is not done and not
    # lost.
    def self.rides_left
      gates = GATES.values.count do |g|
        $game_variables[GATE_VAR].to_i >= 2 && !$game_switches[g[3]] && (blindstep? || g[4][0].none? { |n| lost?(n) })
      end
      ride_steps_left + gates
    end

    # What clears an ORDER entry, said as its obstacle is named with the assist; the pair that bars the way by itself.
    def self.clearer(sw)
      return [:rbrj_aw_pair, { :x => PAIR[sw][0], :y => PAIR[sw][1] }] if PAIR[sw]
      ev = $game_map.events[OBSTACLES[$game_map.map_id][sw][0]]
      ev && obstacle_label(ev)
    end

    # True while the New World's gates stand, variable 572 from 2.
    def self.gate_open?
      $game_variables[GATE_VAR].to_i >= 2
    end

    # The gate to the New World this wood leads to, as the assist says it, once it stands and its way is open; that its
    # way is lost; or nil.
    def self.gate_line
      gate = GATES[$game_map.map_id]
      return nil unless gate && gate_open?
      need, key, args = blindstep? ? gate[5] : gate[4]
      lost = !blindstep? && need.any? { |n| lost?(n) }
      return PokeAccess::I18n.t(:rbrj4_aw_gate_lost, :x => gate[0], :y => gate[1]) if lost
      return nil unless need.all? { |sw| $game_switches[sw] }
      PokeAccess::I18n.t(key, args.dup.merge!(:x => gate[0], :y => gate[1]))
    end

    # The assist's line for the next entry of the order: its clearer, how to come in and the Honey left.
    def self.step_line(entry, what)
      args = { :what => PokeAccess::I18n.t(*Array(what)), :honey => honey_left }
      how = entry[1]
      return PokeAccess::I18n.t(:rbrj_aw_next, args) if how == :walk
      a = how[1..-1]
      case how[0]
      when :in
        args.merge!(:ex => a[0], :ey => a[1], :place => PokeAccess::Locator.map_name(a[2]))
        PokeAccess::I18n.t(:rbrj4_aw_next_in, args)
      when :ride
        PokeAccess::I18n.t(:rbrj_aw_next_ride, args.merge!(:rx => a[0], :ry => a[1], :ex => a[2], :ey => a[3]))
      when :off
        args.merge!(:rx => a[0], :ry => a[1], :ex => a[2], :ey => a[3], :x => a[4], :y => a[5])
        PokeAccess::I18n.t(:rbrj_aw_next_dismount, args)
      when :east
        args.merge!(:rx => a[0], :ry => a[1], :ox => a[2], :oy => a[3], :bx => a[4], :by => a[5])
        PokeAccess::I18n.t(:rbrj4_aw_next_east, args)
      else
        args.merge!(:rx => a[0], :ry => a[1], :ex => a[2], :ey => a[3], :bx => a[4], :by => a[5])
        args.merge!(:x => a[6], :y => a[7])
        PokeAccess::I18n.t(:rbrj4_aw_next_far, args)
      end
    end

    # The line for an entry whose way still crosses something standing: the Route 1 Tauros that rams it when that is
    # all, or else the woods it goes through.
    def self.wait_line(what, pending)
      args = { :what => PokeAccess::I18n.t(*Array(what)) }
      return PokeAccess::I18n.t(:rbrj4_aw_wait, args) unless pending.all? { |n| BULLS[n] }
      PokeAccess::I18n.t(:rbrj4_aw_wait_bull, args.merge!(:x => BULLS[pending[0]][0], :y => BULLS[pending[0]][1]))
    end

    # What can no longer fall in this wood, once each: a log whose pair was ridden, and what only such a log led to.
    def self.lost_lines
      order.map do |sw, _how|
        next nil if $game_switches[sw] || open?(sw)
        next PokeAccess::I18n.t(:rbrj4_aw_lost, :x => BULLS[sw][0], :y => BULLS[sw][1]) if lost?(sw)
        what = clearer(sw)
        what && PokeAccess::I18n.t(:rbrj4_aw_lost_behind, :what => PokeAccess::I18n.t(*Array(what)))
      end.compact
    end

    # With the assist, this wood's gate, what it has lost, then its next log, web or pair and the Honey left, or that it
    # is clear.
    def self.wood_hint
      entry = next_entry
      what = entry && clearer(entry[0])
      lost = lost_lines
      step = if what
               pending = needs(entry[0]).reject { |n| $game_switches[n] }
               pending.empty? ? step_line(entry, what) : wait_line(what, pending)
             elsif !entry && lost.empty?
               PokeAccess::I18n.t(:rbrj_aw_clear)
             end
      lines = [gate_line].concat(lost).push(step).compact
      lines.empty? ? nil : PokeAccess.sentences(lines)
    end
  end
end

PokeAccess::Game.define("reborn") do
  bugs = PokeAccess::RebornAventurineBugs
  mechanic(:state, bugs::MAPS) do
    auto
    name bugs::BUGS, lambda { |ev| bugs.label(ev) }, :assist => true
    hint lambda { bugs.wood_hint }
    info { nil }
    active { PokeAccess::Puzzles.assist? && !bugs.wood_hint.nil? }
  end
  bugs::OBSTACLES.each do |map, groups|
    mechanic(:state, map, :part => :obstacles) do
      auto
      name groups.values.flatten, lambda { |ev| bugs.obstacle_label(ev) }, :grouped => true,
           :when => lambda { |ev| !$game_switches[bugs.switch_of(ev).to_i] }
      gate = bugs::GATES[map]
      spot :at => gate[0, 2], :label => gate[2], :assist => true, :when => lambda { bugs.gate_open? } if gate
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornAventurineBugs.forget }
