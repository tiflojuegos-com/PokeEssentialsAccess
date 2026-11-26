# Glass Workstation's psychic glass blocks (map 732): fourteen blocks (variables 408 to 421), a core and pieces drawn
# with a glass tile. With Espeon following (switch 947) a piece waits for a key and the block's page moves it one to
# four tiles that way, never towards the player. They gate the glass floor EV53 (48,27) and the reader EV174 (40,8).
module PokeAccess
  module RebornGlassBlocks
    MAP = 732
    GLACEON = 946
    ESPEON = 947
    LOWER = 410
    CLEARED = 953
    ELEVATORS = 957
    ATRIUM = 958
    STORY = 391
    VARS = (408..421).to_a
    CHANNELS = [397, 402, 403]
    OPPOSITE = { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }
    DIR_WORD = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    NAME = /\AGB(\d+)(Core|B)/
    LISTED = /\AGB\d+Core(A)?\z/
    MOVED = { 1 => { 1 => 2 }, 2 => { 1 => 8 }, 3 => { 1 => 2 }, 4 => { 1 => 4 }, 5 => { 1 => 2 }, 6 => { 1 => 8 },
              7 => { 1 => 8 }, 8 => { 1 => 8 }, 9 => { 1 => 2 }, 10 => { 1 => 4, 2 => 6 }, 11 => { 1 => 2 },
              12 => { 1 => 6, 2 => 6 }, 13 => { 1 => 4, 2 => 6 }, 14 => { 1 => 6 } }
    GOALS = { :glass => [[48, 28], :rbri_goal_glass, :rbri_spot_glass],
              :reader => [[40, 9], :rbri_goal_reader, :rbri_spot_reader],
              :doors => [[39, 9], :rbri_goal_doors, :rbri_spot_doors] }
    WEST = [6, 20, 20, 38]
    WEST_SPOT = [16, 30]
    DEAD_ENDS = [[6, 10, 24, 33], [15, 17, 32, 33]]
    NORTH_POCKET = [23, 39, 20, 29]
    POCKET = [[41, 41, 22, 23], [42, 45, 13, 26]]
    SIDES = { :nook => [[41, 41, 22, 23], [42, 45, 23, 26]],
              :north => [[40, 45, 9, 12], [42, 45, 13, 17], [45, 45, 18, 21], [44, 45, 22, 22]] }
    NOOK = [41, 22]
    NEEDED = { :reader => 403, :doors => 402 }
    CLEAR = { :reader => [43, 15], :doors => [36, 15] }

    # Either partner can be told to wait (common events 55 and 56), so each move names the partner it needs. Phase =>
    # "blocks|frozen channels" ("|p" with the player in POCKET) => [moves left, :e, block, tile to stand on, facing,
    # key] or [moves left, :g, channel, tile, facing], or [0] where the goal is reached.
    PLAN = {
      :glass => {
        "00000000010000|397" => [0], "00000000110000|397" => [0],
        "00000100010000|397" => [0], "00000000000000|397" => [1, :e, 10, [47, 30], 8, 4],
        "00000000100000|397" => [1, :e, 10, [47, 30], 8, 4], "00000001010000|397" => [1, :e, 8, [58, 37], 2, 2],
        "00000100000000|397" => [1, :e, 10, [47, 30], 8, 4], "10000000010000|397" => [1, :e, 1, [20, 31], 6, 8],
        "00000000000000|" => [2, :g, 397, [48, 36], 8], "00000001000000|397" => [2, :e, 8, [58, 37], 2, 2],
        "10000000000000|397" => [2, :e, 1, [20, 31], 6, 8], "00000001000000|" => [3, :e, 8, [58, 37], 2, 2],
        "00000100000000|" => [3, :e, 6, [30, 38], 4, 2], "10000000000000|" => [3, :e, 1, [20, 31], 6, 8]
      },
      :reader => {
        "10000000121011|397,402,403" => [0], "10000000121011|397,402,403|p" => [0],
        "10000000121011|397,403" => [0], "10000000121011|397,403|p" => [0],
        "10000000121211|397,403" => [0], "10000000121211|397,403|p" => [0],
        "10000000120011|397,403|p" => [1, :e, 11, [43, 23], 6, 2], "10000000121001|397,402,403" => [1, :e, 13, [42, 9], 4, 4],
        "10000000121001|397,402,403|p" => [1, :e, 13, [42, 9], 4, 4], "10000000121001|397,403" => [1, :e, 13, [42, 9], 4, 4],
        "10000000121001|397,403|p" => [1, :e, 13, [42, 9], 4, 4], "10000000121201|397,403" => [1, :e, 13, [42, 9], 4, 4],
        "10000000121201|397,403|p" => [1, :e, 13, [42, 9], 4, 4], "10000000120001|397,403|p" => [2, :e, 11, [43, 23], 6, 2],
        "10000000121000|397,402,403" => [2, :e, 14, [43, 11], 8, 6], "10000000121000|397,402,403|p" => [2, :e, 14, [43, 11], 8, 6],
        "10000000121000|397,403" => [2, :e, 14, [43, 11], 8, 6], "10000000121000|397,403|p" => [2, :e, 14, [43, 11], 8, 6],
        "10000000121200|397,403" => [2, :e, 14, [43, 11], 8, 6], "10000000121200|397,403|p" => [2, :e, 14, [43, 11], 8, 6],
        "10000000120000|397,403|p" => [3, :e, 11, [43, 23], 6, 2], "10000000121000|397,402|p" => [3, :g, 403, [42, 15], 8],
        "10000000121000|397|p" => [3, :g, 403, [42, 15], 8], "10000000121200|397|p" => [3, :g, 403, [42, 15], 8],
        "10000000120000|397,402|p" => [4, :e, 11, [43, 23], 6, 2], "10000000120000|397|p" => [4, :e, 11, [43, 23], 6, 2],
        "10000000120100|397" => [5, :e, 12, [42, 23], 2, 4], "10000000120100|397,402" => [5, :e, 12, [42, 23], 2, 4],
        "10000000120100|397,402|p" => [5, :e, 12, [42, 23], 2, 4], "10000000120100|397|p" => [5, :e, 12, [42, 23], 2, 4],
        "00000000120100|397" => [6, :e, 1, [20, 30], 6, 2], "10000000120000|397" => [6, :e, 12, [41, 26], 8, 6],
        "00000000120000|397" => [7, :e, 1, [20, 30], 6, 2], "10000000100000|397" => [7, :e, 10, [39, 28], 6, 6],
        "10000000110000|397" => [7, :e, 10, [37, 28], 6, 6], "00000000100000|397" => [8, :e, 1, [20, 30], 6, 2],
        "00000000110000|397" => [8, :e, 1, [20, 30], 6, 2], "00000000000000|397" => [9, :e, 9, [48, 31], 6, 2],
        "00000000010000|397" => [9, :e, 9, [48, 31], 6, 2], "00000001110000|397" => [9, :e, 8, [58, 37], 2, 2],
        "00000100110000|397" => [9, :e, 6, [30, 38], 4, 2], "00000001010000|397" => [10, :e, 8, [58, 37], 2, 2],
        "00000100010000|397" => [10, :e, 6, [30, 38], 4, 2], "10000000000000|397" => [10, :e, 1, [20, 31], 6, 8],
        "10000000010000|397" => [10, :e, 1, [20, 31], 6, 8]
      },
      :doors => {
        "10000000120121|397,402,403" => [0], "10000000120121|397,402,403|p" => [0],
        "00000000120121|397,402,403" => [1, :e, 1, [20, 30], 6, 2], "10000000120021|397,402,403|p" => [1, :e, 12, [41, 23], 2, 6],
        "10000000120111|397,402,403" => [1, :e, 13, [35, 10], 6, 6], "10000000120111|397,402,403|p" => [1, :e, 13, [35, 10], 6, 6],
        "00000000120111|397,402,403" => [2, :e, 1, [20, 30], 6, 2], "10000000120011|397,402,403|p" => [2, :e, 12, [41, 23], 2, 6],
        "10000000120111|397,403" => [2, :g, 402, [35, 15], 8], "10000000120111|397,403|p" => [2, :g, 402, [35, 15], 8],
        "00000000120111|397,403" => [3, :e, 1, [20, 30], 6, 2], "10000000120011|397,403|p" => [3, :e, 12, [41, 23], 2, 6],
        "10000000121011|397,402,403" => [3, :e, 11, [43, 25], 6, 8], "10000000121011|397,402,403|p" => [3, :e, 11, [43, 25], 6, 8],
        "10000000121011|397,403" => [4, :e, 11, [43, 25], 6, 8], "10000000121011|397,403|p" => [4, :e, 11, [43, 25], 6, 8],
        "10000000121211|397,402,403" => [4, :e, 12, [41, 23], 2, 4], "10000000121211|397,402,403|p" => [4, :e, 12, [41, 23], 2, 4],
        "10000000121211|397,403" => [5, :e, 12, [41, 23], 2, 4], "10000000121211|397,403|p" => [5, :e, 12, [41, 23], 2, 4]
      }
    }

    # The block flags as the plan writes them, "10000000120101|397,403".
    def self.state
      blocks = VARS.map { |v| $game_variables[v].to_i }.join
      frozen = CHANNELS.select { |c| $game_variables[c].to_i >= 1 }.join(",")
      "#{blocks}|#{frozen}"
    end

    # The story phase the blocks gate as things stand: the glass floor, the reader, the doors, or nil.
    def self.phase
      return nil unless $game_map && $game_map.map_id == MAP && !$game_switches[CLEARED]
      story = $game_variables[STORY].to_i
      return nil if story < 23 || story >= 47
      return :glass unless $game_switches[ELEVATORS]
      return :doors if $game_switches[ATRIUM]
      PokeAccess::Engine.bag_quantity(:METEORCARD).to_i > 0 ? :reader : nil
    end

    # The plan's entry for the live state and the player's side of block 12, or nil off the plan or out of a phase.
    def self.entry
      ph = phase
      return nil unless ph && PLAN[ph]
      pocket = POCKET.any? { |box| inside?(box, player_at) }
      PLAN[ph][pocket ? "#{state}|p" : state]
    end

    # True while the player walks the lower floor, where the plan is.
    def self.below?
      $game_switches[LOWER] ? true : false
    end

    def self.inside?(box, xy)
      xy[0] >= box[0] && xy[0] <= box[1] && xy[1] >= box[2] && xy[1] <= box[3]
    end

    # Where a partner waits on this map, [x, y], or nil while it follows or is elsewhere.
    def self.waiting(who)
      follow, vx, vy = who == :e ? [ESPEON, 406, 407] : [GLACEON, 404, 405]
      return nil if $game_switches[follow]
      x = $game_variables[vx].to_i
      x == 0 ? nil : [x, $game_variables[vy].to_i]
    end

    def self.follows?(who)
      $game_switches[who == :e ? ESPEON : GLACEON] ? true : false
    end

    def self.upstairs?(who)
      $game_switches[who == :e ? 965 : 964] ? true : false
    end

    def self.who(who)
      who == :e ? :rbri_espeon : :rbb_glass_glaceon
    end

    def self.player_at
      [$game_player.x, $game_player.y]
    end

    # Before Espeon moves block 1, Glaceon must not wait on the side it cuts off: the pocket north of it going up, the
    # south going down. A Glaceon following is left in the west first. An errand line, or nil.
    def self.west_errand(e)
      return nil unless phase == :glass && e[1] == :e && e[2] == 1
      i18n = PokeAccess::I18n
      if follows?(:g)
        return i18n.t(inside?(WEST, player_at) ? :rbri_leave_west_here : :rbri_leave_west)
      end
      at = waiting(:g)
      return nil unless at && !upstairs?(:g)
      north = inside?(NORTH_POCKET, at)
      cut = $game_variables[408].to_i == 1 ? north : !(north || inside?(WEST, at))
      cut ? i18n.t(:rbri_leave_fetch, :where => where(at)) : nil
    end

    def self.where(xy)
      PokeAccess::Locator.dir_phrase(xy[0] - $game_player.x, xy[1] - $game_player.y)
    end

    # The partner the next move needs, when it does not follow: where it waits, upstairs, or nowhere here.
    def self.fetch_line(e)
      need = e[1]
      return nil if follows?(need)
      i18n = PokeAccess::I18n
      name = i18n.t(who(need))
      return i18n.t(:rbri_fetch_upper, :who => name) if upstairs?(need)
      at = waiting(need)
      return i18n.t(:rbri_fetch_lost, :who => name) unless at
      i18n.t(:rbri_fetch, :who => name, :where => where(at))
    end

    # Glaceon left in the pocket north of block 1 once it went up, with channel 397 still molten: it is cut off.
    def self.cut_line
      return nil unless phase == :glass && $game_variables[408].to_i == 0 && $game_variables[397].to_i < 1
      at = waiting(:g)
      at && inside?(NORTH_POCKET, at) ? PokeAccess::I18n.t(:rbri_glaceon_cut) : nil
    end

    # The side of blocks 12 and 11 a tile is on: the nook's pocket, the north beyond block 11, or the west.
    def self.side(xy)
      SIDES.each { |name, boxes| return name if boxes.any? { |box| inside?(box, xy) } }
      :west
    end

    # Whether two sides are joined: the west and the pocket by block 12 moved right, the pocket and the north by block
    # 11 moved down.
    def self.joined?(a, b)
      return true if a == b
      pair = [a, b]
      return $game_variables[419].to_i == 1 if pair.include?(:west) && pair.include?(:nook)
      return $game_variables[418].to_i == 1 if pair.include?(:north) && pair.include?(:nook)
      false
    end

    # True while the phase still has a channel for Glaceon to freeze.
    def self.glaceon_needed?
      ch = NEEDED[phase]
      !ch.nil? && $game_variables[ch].to_i < 1
    end

    # The Espeon move that opens the way between the player's side and Glaceon's: [block, tile, facing, key], or nil.
    def self.reopen(glaceon, mine)
      gb11 = $game_variables[418].to_i
      gb12 = $game_variables[419].to_i
      return gb11 == 1 ? [11, [43, 25], 6, 8] : [12, [42, 23], 2, 6] if glaceon == :west
      if glaceon == :north
        return [12, [42, 23], 2, 4] if gb12 == 1
        return mine == :west ? [12, [41, 26], 8, 6] : [11, [43, 23], 6, 2]
      end
      mine == :west && gb12 == 0 ? [12, [41, 26], 8, 6] : nil
    end

    # Glaceon, still needed, waiting on a side the blocks shut from the player's: the move that opens it again, as
    # [line, tile, spot], or Espeon to fetch first; nil while Glaceon can come.
    def self.pocket_cut
      return nil unless glaceon_needed?
      at = waiting(:g)
      return nil unless at && !upstairs?(:g)
      mine = side(player_at)
      glaceon = side(at)
      return nil if joined?(glaceon, mine)
      mv = reopen(glaceon, mine)
      return nil unless mv
      i18n = PokeAccess::I18n
      e = [nil, :e, mv[0], mv[1], mv[2], mv[3]]
      fetch = fetch_line(e)
      return [fetch, waiting(:e), i18n.t(:rbri_spot_partner, :who => i18n.t(who(:e)))] if fetch
      opts = { :n => mv[0], :dir => i18n.t(DIR_WORD[mv[3]]), :face => i18n.t(DIR_WORD[mv[2]]) }
      here = mv[1] == player_at
      opts[:where] = where(mv[1]) unless here
      [i18n.t(here ? :rbri_cut_pocket_here : :rbri_cut_pocket, opts), mv[1], move_spot(e)]
    end

    # Whether the move shuts the pocket by block 11 behind the player: block 12 back to the left for the reader, and for
    # the doors any move while block 11 is down, since the next one, block 11 up, shuts the north off.
    def self.closer?(e)
      return false unless e[1] == :e
      return $game_variables[418].to_i == 1 if phase == :doors
      phase == :reader && e[2] == 12 && e[5] == 4
    end

    # Before a move that shuts the pocket by block 11, Glaceon is left in its nook (for the reader only while channel
    # 403 is left to freeze; for the doors always), or fetched there first. As [line, tile, spot], or nil.
    def self.nook_errand(e)
      return nil unless closer?(e) && (glaceon_needed? || phase == :doors)
      return nil if waiting(:g) == NOOK || upstairs?(:g)
      i18n = PokeAccess::I18n
      if follows?(:g)
        return [i18n.t(:rbri_nook_leave, :n => e[2], :where => where(NOOK)), NOOK,
                i18n.t(:rbri_spot_leave, :who => i18n.t(who(:g)))]
      end
      at = waiting(:g)
      return nil unless at
      [i18n.t(:rbri_nook_fetch, :n => e[2], :where => where(at)), at,
       i18n.t(:rbri_spot_partner, :who => i18n.t(who(:g)))]
    end

    # Where the one following is left before fetching the other from a dead end (the nook, the far west room by the west
    # elevator, the pocket south of the west spot), where a swap would drop it in the only way out; nil elsewhere.
    def self.clear_tile(at)
      return CLEAR[phase] if at == NOOK
      DEAD_ENDS.any? { |box| inside?(box, at) } ? WEST_SPOT : nil
    end

    # Before fetching the partner the move needs from a dead end, the one following is left out of the way. As [line,
    # tile, spot], or nil.
    def self.clear_errand(e)
      other = e[1] == :e ? :g : :e
      at = waiting(e[1])
      tile = at && follows?(other) && clear_tile(at)
      return nil unless tile
      i18n = PokeAccess::I18n
      name = i18n.t(who(other))
      line = i18n.t(:rbri_clear_leave, :who => name, :need => i18n.t(who(e[1])), :where => where(tile))
      [line, tile, i18n.t(:rbri_spot_leave, :who => name)]
    end

    # The partner the move does not need, waiting on the tile it is made from: fetched to free it, as [line, tile, spot].
    def self.in_way(e)
      other = e[1] == :e ? :g : :e
      return nil unless waiting(other) == e[3]
      i18n = PokeAccess::I18n
      name = i18n.t(who(other))
      [i18n.t(:rbri_in_way, :who => name, :where => where(e[3])), e[3], i18n.t(:rbri_spot_partner, :who => name)]
    end

    # The partner errands of block 1's west and of a partner to fetch, as [line, tile, spot], or nil.
    def self.partner_advice(e)
      i18n = PokeAccess::I18n
      west = west_errand(e)
      if west
        return [west, WEST_SPOT, i18n.t(:rbri_spot_leave, :who => i18n.t(who(:g)))] if follows?(:g)
        return [west, waiting(:g), i18n.t(:rbri_spot_partner, :who => i18n.t(who(:g)))]
      end
      line = fetch_line(e)
      line && [line, waiting(e[1]), i18n.t(:rbri_spot_partner, :who => i18n.t(who(e[1])))]
    end

    # With the assist, what the plan asks now: [line, tile to point at, its spot], or nil out of a phase.
    def self.advice
      return nil unless PokeAccess::Puzzles.assist? && phase && below?
      i18n = PokeAccess::I18n
      cut = cut_line
      return [cut, nil, nil] if cut
      reopened = pocket_cut
      return reopened if reopened
      e = entry
      return [i18n.t(:rbri_off_plan), nil, nil] unless e
      if e[0] == 0
        tile, _key, spot = GOALS[phase]
        return [goal_line, tile, i18n.t(spot)]
      end
      nook_errand(e) || clear_errand(e) || in_way(e) || partner_advice(e) || [move_line(e), e[3], move_spot(e)]
    end

    # With the assist, the info key's plan: the errand, the move, the goal, or that the blocks are off the plan.
    def self.step_line
      a = advice
      a && a[0]
    end

    # The move in words: from where, facing what, and the key for a block.
    def self.move_line(e)
      i18n = PokeAccess::I18n
      opts = { :left => e[0], :face => i18n.t(DIR_WORD[e[4]]) }
      opts[:n] = e[2] if e[1] == :e
      opts[:dir] = i18n.t(DIR_WORD[e[5]]) if e[1] == :e
      here = e[3] == player_at
      opts[:where] = where(e[3]) unless here
      key = e[1] == :e ? :rbrc_glass_step : :rbri_step_freeze
      i18n.t(here ? "#{key}_here".to_sym : key, opts)
    end

    # The move's spot in words.
    def self.move_spot(e)
      i18n = PokeAccess::I18n
      return i18n.t(:rbrc_glass_spot, :n => e[2], :dir => i18n.t(DIR_WORD[e[5]])) if e[1] == :e
      i18n.t(:rbri_spot_freeze, :dir => i18n.t(DIR_WORD[e[4]]))
    end

    # The goal of the phase, reached: where to stand.
    def self.goal_line
      tile, key, _spot = GOALS[phase]
      i18n = PokeAccess::I18n
      tile == player_at ? i18n.t("#{key}_here".to_sym) : i18n.t(key, :where => where(tile))
    end

    # The tile the assist points at: the next move's, the partner's or the errand's, or the goal.
    def self.stand_at
      a = advice
      a && a[1]
    end

    # The assist's spot in words.
    def self.spot_label
      a = advice
      a && a[2]
    end

    # The channel Glaceon freezes next with the assist, for glass_channels' names, or nil.
    def self.next_channel
      e = PokeAccess::Puzzles.assist? && below? && entry
      e && e[1] == :g ? e[2] : nil
    end

    # A block's number by its piece's event name, or nil.
    def self.block_of(ev)
      m = ev.name.to_s.match(NAME)
      m && m[1].to_i
    end

    def self.label(ev)
      n = block_of(ev)
      n && PokeAccess::I18n.t(:rbrc_glass_block, :n => n)
    end

    # What using a piece says: with Espeon, that it waits for a direction, and with the assist the planned key when the
    # piece is of the planned block and the player does not face the way it goes.
    def self.use_line(ev)
      return nil unless $game_switches[ESPEON]
      i18n = PokeAccess::I18n
      e = PokeAccess::Puzzles.assist? && phase && entry
      if e && e[1] == :e && e[2] == block_of(ev) && $game_player.direction != OPPOSITE[e[5]]
        return i18n.t(:rbrc_glass_wait_key, :dir => i18n.t(DIR_WORD[e[5]]))
      end
      i18n.t(:rbrc_glass_wait)
    end

    # A block's variable said by its value: in its place, or moved and which way.
    def self.words(n)
      w = { 0 => :rbrc_glass_home }
      MOVED[n].each do |value, dir|
        w[value] = lambda { PokeAccess::I18n.t(:rbri_glass_moved, :dir => PokeAccess::I18n.t(DIR_WORD[dir])) }
      end
      w
    end

    # The info key's line: the blocks out of their place and which way, or that all stand in it.
    def self.info_text
      i18n = PokeAccess::I18n
      items = []
      VARS.each_with_index do |v, i|
        dir = MOVED[i + 1][$game_variables[v].to_i]
        items << i18n.t(:rbri_glass_moved_item, :n => i + 1, :dir => i18n.t(DIR_WORD[dir])) if dir
      end
      return i18n.t(:rbri_glass_none_moved) if items.empty?
      i18n.t(:rbri_glass_moved_list, :list => items.join(", "))
    end

    # The rule, said on arriving while the blocks still gate the story.
    def self.rule
      phase ? :rbri_glass_rule : nil
    end

    def self.done?
      return true if $game_switches[CLEARED]
      $game_variables[STORY].to_i >= 47
    end
  end
end

PokeAccess::Game.define("reborn") do
  gb = PokeAccess::RebornGlassBlocks
  mechanic(:state, gb::MAP, :part => :glass_blocks) do
    auto
    name gb::NAME, lambda { |ev| gb.label(ev) }, :when => lambda { |ev| ev.name.to_s =~ gb::LISTED }
    on_use gb::NAME, lambda { |ev| gb.use_line(ev) }
    gb::VARS.each_with_index do |v, i|
      watch :var => v, :label => [:rbrc_glass_block, { :n => i + 1 }], :words => gb.words(i + 1)
    end
    info { gb.info_text }
    spot :at => lambda { gb.stand_at }, :label => lambda { gb.spot_label }, :assist => true, :onto => true
    arrival_hint lambda { gb.rule }
    hint lambda { gb.step_line }
    active { !gb.phase.nil? && gb.below? }
    solved(nil, :quiet => true) { gb.done? }
  end
end
