# Xenpurgis F1 (map 646), the room of nine islands: no-graphic floor tiles at the islands' edges jump the player four
# tiles over the wall, and two trampolines (events 142 and 144), moved a corner on by switches 143 and 145, jump from
# one corner. Room 5, west: grunts and statues in two squares; beating both (513 to 2) brings the ball (event 166).
module PokeAccess
  module RejuvXenpurgisTrampolines
    MAP = 646
    ROOM = [62, 78, 75, 92]
    # trampoline => [its corners in the order its switch moves it, the corners it jumps from, its square's north-west]
    PADS = { 142 => [[[77, 82], [76, 82], [76, 83], [77, 83]], [[77, 82]], [76, 82]],
             144 => [[[76, 78], [76, 77], [75, 77], [75, 78]], [[75, 77], [75, 78]], [75, 77]] }
    SWITCHES = { 143 => 142, 145 => 144 }
    CORNERS = { [0, 0] => :rjf_xp_corner_nw, [1, 0] => :rjf_xp_corner_ne, [0, 1] => :rjf_xp_corner_sw,
                [1, 1] => :rjf_xp_corner_se }
    JUMPS = { 20 => 6, 82 => 6, 129 => 6, 130 => 4, 131 => 4, 132 => 4, 133 => 6, 134 => 6, 136 => 8, 137 => 2,
              138 => 2, 139 => 8, 140 => 8, 191 => 2 }
    SPIKES = [204, 205, 206]

    # Whether the player is in the islands' room.
    def self.here?
      x = $game_player.x
      y = $game_player.y
      x >= ROOM[0] && x <= ROOM[1] && y >= ROOM[2] && y <= ROOM[3]
    end

    # A trampoline's place, [x, y], as the map has it now.
    def self.at(id)
      ev = $game_map.events[id]
      ev ? [ev.x, ev.y] : PADS[id][0][0]
    end

    # The word of a corner of a trampoline's square.
    def self.corner(id, place)
      base = PADS[id][2]
      PokeAccess::I18n.t(CORNERS[[place[0] - base[0], place[1] - base[1]]] || :rjf_xp_corner_nw)
    end

    # How many presses of its switch a trampoline needs to jump.
    def self.presses(id)
      cycle, good, _base = PADS[id]
      i = cycle.index(at(id)) || 0
      (0..3).find { |k| good.include?(cycle[(i + k) % 4]) } || 0
    end

    # A trampoline's name: its colour and the corner it is in; with the assist, whether it jumps from there.
    def self.pad(ev)
      key = ev.id == 142 ? :rjf_xp_green_pad : :rjf_xp_blue_pad
      line = PokeAccess::I18n.t(key, :corner => corner(ev.id, [ev.x, ev.y]))
      return line unless PokeAccess::Puzzles.assist?
      PokeAccess.sentences([line, PokeAccess::I18n.t(presses(ev.id).zero? ? :rjf_xp_pad_jumps : :rjf_xp_pad_still)])
    end

    # How many times, in words.
    def self.times(n)
      n == 1 ? PokeAccess::I18n.t(:rjf_xp_once) : PokeAccess::I18n.t(:rjf_xp_times, :n => n)
    end

    # What a switch does as it is stepped on: the corner its trampoline goes to.
    def self.moved(ev)
      id = SWITCHES[ev.id]
      cycle = PADS[id][0]
      dest = cycle[((cycle.index(at(id)) || 0) + 1) % 4]
      [ev.id == 143 ? :rjf_xp_green_moved : :rjf_xp_blue_moved, { :corner => corner(id, dest) }]
    end

    # With the assist, the presses still missing and when to cross the middle island's spikes on the way to the
    # switches, or the way across once both trampolines jump.
    def self.hint
      parts = []
      b = presses(144)
      g = presses(142)
      parts.push(PokeAccess::I18n.t(:rjf_xp_hint_blue, :times => times(b))) if b > 0
      parts.push(PokeAccess::I18n.t(:rjf_xp_hint_green, :times => times(g))) if g > 0
      parts.push(PokeAccess::I18n.t(parts.empty? ? :rjf_xp_hint_go : :rjrv2_xp_cross))
      PokeAccess.sentences(parts)
    end
  end

  module RejuvXenpurgisSpinner
    MAP = 646
    ROOM = [33, 50, 74, 93]
    DOOR = 1894
    BALL = 166
    # switch => [its grunt, his statues, the square's north-west tile, his facing => [the next one, each piece's step,
    # the grunt's first]]
    SQUARES = {
      88 => [80, [87], [38, 76], { 2 => [4, [[0, 1], [-1, 0]]], 4 => [6, [[1, 0], [0, 1]]],
                                   6 => [8, [[0, -1], [1, 0]]], 8 => [2, [[-1, 0], [0, -1]]] }],
      149 => [81, [89, 85], [49, 82], { 2 => [4, [[0, 1], [0, -1], [1, 0]]], 4 => [8, [[1, 0], [-1, 0], [0, -1]]],
                                        8 => [6, [[0, -1], [0, 1], [-1, 0]]], 6 => [2, [[-1, 0], [1, 0], [0, 1]]] }]
    }
    SWITCH_OF = { 80 => 88, 81 => 149 }
    # grunt => the tiles before him the player can stand on
    STANDS = { 80 => [[38, 77], [37, 77]], 81 => [[48, 83]] }
    AHEAD = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # The way across the north square, from (37, 77) to the pad at (40, 76): its south-west and north-east corners, and
    # one of the other two.
    NORTH_ENDS = [[38, 77], [39, 76]]
    NORTH_MIDS = [[39, 77], [38, 76]]
    # The tile of the south square above the pad to the ball.
    SOUTH_GAP = [49, 83]
    # Each step of the plan the assist can be at: [kind, the switch or grunt, presses]
    STEPS = [[:press, 88, 1], [:press, 88, 2], [:press, 88, 3], [:fight, 80, 0], [:press, 149, 1], [:press, 149, 2],
             [:press, 149, 3], [:fight, 81, 0], [:ball, nil, 0], [:door, nil, 0]]
    SPOTS = { :press => :rjrb_xs_spot_press, :fight => :rjrb_xs_spot_fight, :ball => :rjrb_xs_spot_ball,
              :door => :rjrb_xs_spot_door }

    # Whether the player is in room 5, its door not yet open.
    def self.live?
      x = $game_player.x
      y = $game_player.y
      !$game_switches[DOOR] && x >= ROOM[0] && x <= ROOM[1] && y >= ROOM[2] && y <= ROOM[3]
    end

    # Whether a grunt is beaten: his self switch A.
    def self.beaten?(id); $game_self_switches[[MAP, id, "A"]] ? true : false; end

    # A square's grunt and pieces, {id => [x, y]}, and his facing, after so many presses of its switch from now; nil
    # without them or with a facing the switch does not read.
    def self.after(sw, presses)
      grunt, statues, _base, moves = SQUARES[sw]
      ids = [grunt] + statues
      pos = {}
      ids.each do |id|
        ev = $game_map.events[id]
        return nil unless ev
        pos[id] = [ev.x, ev.y]
      end
      face = $game_map.events[grunt].direction
      presses.times do
        return nil unless moves[face]
        nxt, steps = moves[face]
        ids.each_with_index { |id, i| pos[id] = [pos[id][0] + steps[i][0], pos[id][1] + steps[i][1]] }
        face = nxt
      end
      [pos, face]
    end

    # The tiles a square's drawn pieces take, of a layout from after.
    def self.taken(pos)
      pos.select { |id, _xy| (ev = $game_map.events[id]) && !ev.character_name.to_s.empty? }.map { |_id, xy| xy }
    end

    # Whether the north square lets the player across with these tiles taken.
    def self.north_open?(t)
      NORTH_ENDS.none? { |xy| t.include?(xy) } && NORTH_MIDS.any? { |xy| !t.include?(xy) }
    end

    # The tile where an unbeaten grunt would see the player, of a layout from after, or nil.
    def self.stand_of(grunt, pos, face)
      return nil if beaten?(grunt) || AHEAD[face].nil?
      xy = [pos[grunt][0] + AHEAD[face][0], pos[grunt][1] + AHEAD[face][1]]
      STANDS[grunt].include?(xy) ? xy : nil
    end

    # The fewest presses of a switch, 0 to 3, after which the block holds for its layout, or nil.
    def self.presses(sw)
      (0..3).find do |k|
        lay = after(sw, k)
        lay && yield(lay[0], lay[1], taken(lay[0]))
      end
    end

    # The north grunt's step: the presses that let him see the player and leave the square open once he is beaten,
    # else those that let him see the player.
    def self.north_fight
      k = presses(88) { |pos, face, t| stand_of(80, pos, face) && north_open?(t - [pos[80]]) }
      k || presses(88) { |pos, face, _t| stand_of(80, pos, face) }
    end

    # The south square's presses still due: for its grunt to see the player, or, once beaten, to clear the tile above
    # the pad to the ball.
    def self.south_due
      return presses(149) { |_pos, _face, t| !t.include?(SOUTH_GAP) } if beaten?(81)
      presses(149) { |pos, face, _t| stand_of(81, pos, face) }
    end

    # The next step of the plan, worked out once a frame.
    def self.step
      key = [$game_map.map_id, PokeAccess::World::Epoch.frame]
      return @step[1] if @step && @step[0] == key
      @step = [key, plan_step]
      @step[1]
    end

    # The next step of the plan, as one of STEPS, or nil once the door is open or the layout is off the plan.
    def self.plan_step
      unless beaten?(80)
        k = north_fight
        return nil unless k
        return k > 0 ? [:press, 88, k] : [:fight, 80, 0]
      end
      due = south_due
      return nil unless due
      if due > 0
        k = presses(88) { |_pos, _face, t| north_open?(t) }
        return nil unless k
        return k > 0 ? [:press, 88, k] : [:press, 149, due]
      end
      return [:fight, 81, 0] unless beaten?(81)
      ball = $game_map.events[BALL]
      return [:ball, nil, 0] if ball && !ball.character_name.to_s.empty?
      [:door, nil, 0]
    end

    # The tile before the grunt the plan fights next.
    def self.stand
      s = step
      return nil unless s && s[0] == :fight
      lay = after(SWITCH_OF[s[1]], 0)
      lay && stand_of(s[1], lay[0], lay[1])
    end

    # The assist's line for a step of the plan.
    def self.hint(s)
      case s[0]
      when :press
        key = s[1] == 88 ? :rjrb_xs_hint_north : :rjrb_xs_hint_south
        PokeAccess::I18n.t(key, :times => PokeAccess::RejuvXenpurgisTrampolines.times(s[2]))
      when :fight then PokeAccess::I18n.t(s[1] == 80 ? :rjrb_xs_hint_fight_north : :rjrb_xs_hint_fight_south)
      when :ball then PokeAccess::I18n.t(:rjrb_xs_hint_ball)
      else PokeAccess::I18n.t(:rjrb_xs_hint_door)
      end
    end

    # The words of a square, by its switch.
    def self.square(sw); PokeAccess::I18n.t(sw == 88 ? :rjrb_xs_north : :rjrb_xs_south); end

    # The corner of its square a tile is.
    def self.corner(sw, xy)
      base = SQUARES[sw][2]
      key = PokeAccess::RejuvXenpurgisTrampolines::CORNERS[[xy[0] - base[0], xy[1] - base[1]]]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # A grunt's name: his square, his corner and the way he looks; nil, his own, while not drawn.
    def self.grunt(ev)
      return nil if ev.character_name.to_s.empty?
      sw = SWITCH_OF[ev.id]
      [:rjrb_xs_grunt, { :square => square(sw), :corner => corner(sw, [ev.x, ev.y]).to_s,
                         :dir => PokeAccess::Puzzles.face_name(ev.direction) }]
    end

    # A statue's name: its square and its corner.
    def self.statue(ev)
      sw = SQUARES.keys.find { |k| SQUARES[k][1].include?(ev.id) }
      [:rjrb_xs_statue, { :square => square(sw), :corner => corner(sw, [ev.x, ev.y]).to_s }]
    end

    # What a switch does as it is stepped on: where its grunt goes and the way he will look, or, with him gone, that the
    # statues turn.
    def self.turned(ev)
      lay = after(ev.id, 1)
      return nil unless lay
      grunt = $game_map.events[SQUARES[ev.id][0]]
      return [:rjrb_xs_turned_statues, { :square => square(ev.id) }] if grunt.character_name.to_s.empty?
      [:rjrb_xs_turned, { :square => square(ev.id), :corner => corner(ev.id, lay[0][grunt.id]).to_s,
                          :dir => PokeAccess::Puzzles.face_name(lay[1]) }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  xp = PokeAccess::RejuvXenpurgisTrampolines
  mechanic(:state, xp::MAP, :part => :trampolines) do
    auto
    name xp::PADS.keys, lambda { |ev| xp.pad(ev) }
    name 143, :rjf_xp_green_switch
    name 145, :rjf_xp_blue_switch
    on_use xp::SWITCHES.keys, lambda { |ev| xp.moved(ev) }
    name xp::JUMPS.keys, lambda { |ev| [:rjf_xp_jump, { :dir => PokeAccess::Puzzles.face_name(xp::JUMPS[ev.id]) }] }
    name xp::SPIKES, :rjrv2_xp_spikes, :grouped => true
    hint lambda { xp.hint }
    active { xp.here? }
  end
  sp = PokeAccess::RejuvXenpurgisSpinner
  mechanic(:state, sp::MAP, :part => :spinner) do
    auto
    name [80, 81], lambda { |ev| sp.grunt(ev) }
    name [85, 87, 89], lambda { |ev| sp.statue(ev) }
    name 88, :rjrb_xs_switch_north
    name 149, :rjrb_xs_switch_south
    on_use sp::SQUARES.keys, lambda { |ev| sp.turned(ev) }
    sp::STEPS.each do |s|
      target = case s[0]
               when :press then { :event => s[1], :onto => true }
               when :fight then { :at => lambda { sp.stand }, :onto => true }
               when :ball then { :event => sp::BALL }
               else { :event => 58 }
               end
      spots = [target.dup.merge!(:label => sp::SPOTS[s[0]], :assist => true)]
      phase lambda { PokeAccess::Puzzles.assist? && sp.live? && sp.step == s }, :quiet => true,
            :hint => lambda { sp.hint(s) }, :spots => spots
    end
    active { sp.live? }
    solved(nil, :quiet => true) { $game_switches[sp::DOOR] }
  end
end
