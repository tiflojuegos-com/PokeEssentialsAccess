module PokeAccess
  # What touching a map event does to the player: the page's command list walked as the interpreter would, one facing
  # at a time, without running it. A condition live state cannot answer stops the walk as unknown.
  module EventPages
    # What a walk found. move: net [dx, dy] from Set Move Route; path: [dx, dy, facing] after each step; transfer:
    # [map, x, y] of a transfer that runs (x, y nil when a script names only the map); bridge: the height a ramp
    # sets (:toggle for a switch-back ramp); jump: a move was a jump; talks: it spoke or fought; changes: it set
    # something that stays (a switch, a variable, an item); waits: it waited for the move to end; unknown: the walk
    # stopped at something it could not answer; maybe_transfer: a transfer lies past that point; battle: it started
    # one; through: a step was taken with Through on; held: it went that way only because a direction key is held.
    Outcome = Struct.new(:move, :path, :transfer, :bridge, :jump, :talks, :changes, :waits, :unknown, :maybe_transfer,
                         :battle, :through, :held)

    DIAGONAL = { 5 => [-1, 1], 6 => [1, 1], 7 => [-1, -1], 8 => [1, -1] }
    TURN_RIGHT = { 2 => 4, 4 => 8, 6 => 2, 8 => 6 }
    TURN_LEFT = { 2 => 6, 4 => 2, 6 => 8, 8 => 4 }

    # Event codes the walk reads.
    BRANCH = 111
    ELSE = 411
    MOVE_ROUTE = 209
    WAIT_MOVES = 210
    TRANSFER = 201
    SCRIPT = 355
    SCRIPT_MORE = 655
    STOP = 115
    COMMON_EVENT = 117
    # Show Choices and its branches: "when <choice>" and "when cancel".
    CHOICES = 102
    WHEN = 402
    WHEN_CANCEL = 403
    # Number input, loops and label jumps: the walk cannot tell which way these go.
    UNREADABLE = [103, 112, 113, 118, 119, 413]
    # Text and battles: what a cutscene does and a plain carry or doorway never does.
    TALK = [101, 301]
    BATTLE = 301
    # Switches, variables, self switches, money, items and party: what a page sets that stays set.
    CHANGE = [121, 122, 123, 125, 126, 127, 128, 129]
    # Script calls that belong to a cutscene: battles, messages, portraits, speech bubbles, a trainer noticing.
    TALK_SCRIPT = /pb\w*Battle|TrainerBattle|WildBattle|pbMessage|pbConfirmMessage|pbShowCommands|pbNoticePlayer|pbTrainerEnd|showMug|pbCallBub/
    BATTLE_SCRIPT = /pb\w*Battle|TrainerBattle|WildBattle/
    # Script calls that set something that stays: switches, self switches, variables, rewards.
    CHANGE_SCRIPT = /pbSetSelfSwitch|setTempSwitch|\$game_(?:switches|variables)\[[^\]]*\]\s*=(?!=)|pbReceiveItem|pbItemBall|pbAddPokemon/
    # A variable set to the answer of a question with options: "$game_variables[5] = pbMessage(..., [Yes, No])".
    CHOICE_ASSIGN = /\A\s*\$game_variables\[\s*(\d+)\s*\]\s*=\s*(?:Kernel\.)?(?:pbMessage\w*|pbShowCommands\w*)\s*\(.*\[/m
    # A move-route script that moves the character is a move the walk cannot measure.
    MOVING_SCRIPT = /moveto|jump|move_|@x\b|@y\b/
    # A walk longer than this is a malformed list; better unknown than stuck.
    STEP_CAP = 2000
    # How deep common events calling common events are followed.
    COMMON_DEPTH = 3

    # The outcome of touching event ev (its active page) with the player facing d, or nil.
    # param at the player's [x, y] when the page starts; without it a condition on their position is unknown
    # param act the page is started with the action button and answered yes (first option, confirmation accepted)
    def self.outcome(ev, d, at = nil, act = false)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      walk(list, d, ev, at, act)
    rescue StandardError
      nil
    end

    # True if the list, or a common event it calls, has a script condition, which may ask where the player or the
    # event stands: such a page is walked tile by tile.
    def self.varies_by_tile?(list, depth = 0)
      list.any? do |c|
        code = (c.code rescue 0)
        if code == BRANCH
          (c.parameters[0] rescue nil) == 12
        elsif code == COMMON_EVENT && depth < COMMON_DEPTH
          sub = common_list((c.parameters[0] rescue 0))
          sub ? varies_by_tile?(sub, depth + 1) : false
        else
          false
        end
      end
    end

    # Walks the command list of event ev for facing d as the interpreter would run it.
    def self.walk(list, d, ev, at = nil, act = false)
      o = Outcome.new(nil, [], nil, nil, false, false, false, false, false, false, false, false, false)
      st = { :x => 0, :y => 0, :face => d, :fix => false, :moved => false, :steps => 0, :at => at,
             :act => act, :vars => {}, :chosen => {}, :through => false, :held => false }
      run(list, o, st, ev, 0)
      o.move = [st[:x], st[:y]] unless st[:x] == 0 && st[:y] == 0
      o.held = st[:held]
      o
    rescue StandardError
      nil
    end

    # Runs a list on paper against the walk's state. Returns :stop when the walk is over (a transfer, the end
    # of the event, something unreadable), nil when the caller carries on.
    def self.run(list, o, st, ev, depth)
      branch = {}
      i = 0
      while i < list.length
        st[:steps] += 1
        return stuck(o, list, i) if st[:steps] > STEP_CAP
        c = list[i]
        code = (c.code rescue 0)
        ind = (c.indent rescue 0)
        pars = (c.parameters rescue nil) || []
        if code == BRANCH
          r = condition(pars, st, ev)
          return stuck(o, list, i) if r.nil?
          branch[ind] = r
          unless r
            i = next_at(list, i, ind)
            next
          end
        elsif code == ELSE
          unless branch[ind] == false
            i = next_at(list, i, ind)
            next
          end
        elsif code == CHOICES
          return stuck(o, list, i) unless st[:act]
          st[:chosen][ind] = 0
          o.talks = true
        elsif code == WHEN || code == WHEN_CANCEL
          unless code == WHEN && st[:chosen][ind] == pars[0]
            i = next_at(list, i, ind)
            next
          end
        elsif UNREADABLE.include?(code)
          return stuck(o, list, i)
        elsif code == STOP
          return depth == 0 ? :stop : nil
        elsif TALK.include?(code)
          o.talks = true
          o.battle = true if code == BATTLE
        elsif CHANGE.include?(code)
          o.changes = true
        elsif code == COMMON_EVENT
          sub = common_list(pars[0])
          return stuck(o, list, i) if sub.nil? || depth >= COMMON_DEPTH
          return :stop if run(sub, o, st, ev, depth + 1) == :stop
        elsif code == TRANSFER
          o.transfer = transfer_dest(pars)
          return stuck(o, list, i) if o.transfer.nil?
          return :stop
        elsif code == MOVE_ROUTE && pars[0].to_i == -1
          return stuck(o, list, i) unless route(pars[1], o, st)
          st[:moved] = true
        elsif code == WAIT_MOVES
          o.waits = true if st[:moved]
        elsif code == SCRIPT
          s = script_at(list, i)
          dest = (PokeAccess::Locator.script_transfer_dest(s) rescue nil)
          if dest
            o.transfer = dest
            return :stop
          end
          o.bridge = ramp(s) || o.bridge
          o.talks = true if s =~ TALK_SCRIPT
          o.battle = true if s =~ BATTLE_SCRIPT
          if st[:act] && (m = s.match(CHOICE_ASSIGN))
            st[:vars][m[1].to_i] = 0
          elsif s =~ CHANGE_SCRIPT
            o.changes = true
          end
        end
        i += 1
      end
      nil
    end

    # The command list of common event id, or nil.
    def self.common_list(id)
      l = ($data_common_events[id.to_i].list rescue nil)
      l.is_a?(Array) ? l : nil
    end

    # Marks an outcome as stopped at list[i], noting whether a transfer lies past that point.
    def self.stuck(o, list, i)
      o.unknown = true
      o.maybe_transfer = transfer_after?(list, i)
      :stop
    end

    # True if a transfer (the command or a script one) appears at or after list[i].
    def self.transfer_after?(list, i)
      (i...list.length).any? do |k|
        code = (list[k].code rescue 0)
        code == TRANSFER ||
          (code == SCRIPT && !(PokeAccess::Locator.script_transfer_dest(script_at(list, k)) rescue nil).nil?)
      end
    end

    # The index of the next command at the same indent as list[i]: the else or the end of its branch.
    def self.next_at(list, i, ind)
      j = i + 1
      j += 1 while j < list.length && (list[j].indent rescue 0) != ind
      j
    end

    # The script a 355 line starts, with its 655 continuation lines.
    def self.script_at(list, i)
      s = ((list[i].parameters[0] rescue "") || "").to_s.dup
      j = i + 1
      while j < list.length && (list[j].code rescue 0) == SCRIPT_MORE
        s << "\n" << ((list[j].parameters[0] rescue "") || "").to_s
        j += 1
      end
      s
    end

    # The height a bridge ramp's script sets, :toggle for a switch-back ramp, or nil.
    def self.ramp(s)
      return 0 if s =~ /pbBridgeOff/
      return :toggle if s =~ /puentedemierda/
      m = s.match(/pbBridgeOn\s*(?:\(\s*(\d+)\s*\))?/)
      return nil unless m
      m[1] ? m[1].to_i : 2
    end

    # A Transfer Player command's [map, x, y]: literal, or read from the variables it names.
    def self.transfer_dest(pars)
      return [pars[1], pars[2].to_i, pars[3].to_i] if pars[0].to_i == 0 && pars[1]
      return nil unless pars[0].to_i == 1
      v = $game_variables
      m = v[pars[1]].to_i
      m > 0 ? [m, v[pars[2]].to_i, v[pars[3]].to_i] : nil
    rescue StandardError
      nil
    end

    # A conditional branch against live state: true, false, or nil when it cannot be answered here. RMXP stores
    # "is ON" as 0 for switches and self switches.
    def self.condition(pars, st, ev)
      face = st[:face]
      case pars[0]
      when 0 then (($game_switches[pars[1]] ? true : false) == (pars[2].to_i == 0))
      when 1 then variable_condition(pars, st[:vars])
      when 2
        key = [($game_map.map_id rescue 0), (ev.id rescue 0), pars[1].to_s]
        (($game_self_switches[key] ? true : false) == (pars[2].to_i == 0))
      when 6 then character_facing(pars, face, ev)
      when 11 then pars[1] == face
      when 12 then script_condition(pars[1].to_s, st, ev)
      end
    rescue StandardError
      nil
    end

    # A script condition, answered by ScriptCondition; one that holds on a held direction key marks the walk as held.
    def self.script_condition(src, st, ev)
      ctx = context(st, ev)
      r = ScriptCondition.evaluate(src, ctx)
      st[:held] = true if r && ctx[:held]
      r
    end

    # What a script condition may read of the walk: the facing, where the player stands by now, where the
    # event itself stands, whether the player is answering yes, and the answers given so far.
    def self.context(st, ev)
      { :face => st[:face], :pos => position(st), :self => ([ev.x, ev.y] rescue nil), :act => st[:act],
        :vars => st[:vars] }
    end

    # Where the player stands at this point of the walk: where the page started, plus what it has moved them.
    def self.position(st)
      at = st[:at]
      at ? [at[0] + st[:x], at[1] + st[:y]] : nil
    end

    # A game variable as the walk sees it: an answer given during the walk, else the live value.
    def self.variable(id, vars)
      (vars && vars.key?(id)) ? vars[id] : $game_variables[id]
    end

    # Variable comparison: pars[2] says whether pars[3] is a constant (0) or another variable.
    def self.variable_condition(pars, vars = nil)
      v = variable(pars[1], vars)
      n = pars[2].to_i == 0 ? pars[3] : variable(pars[3], vars)
      return nil unless v.is_a?(Integer) && n.is_a?(Integer)
      case pars[4].to_i
      when 0 then v == n
      when 1 then v >= n
      when 2 then v <= n
      when 3 then v > n
      when 4 then v < n
      when 5 then v != n
      end
    end

    # "Character is facing <dir>": the player's facing is the one being walked, any other character's is live.
    def self.character_facing(pars, face, ev)
      who = pars[1].to_i
      dir = if who == -1 then face
            elsif who == 0 then (ev.direction rescue nil)
            else ($game_map.events[who].direction rescue nil)
            end
      dir.nil? ? nil : dir == pars[2]
    end

    # Runs a move route on paper against the walk's state, recording where each step leaves the player. False
    # for a route whose end cannot be known (a random step, a step toward someone, a script that moves).
    def self.route(mr, o, st)
      ((mr.list rescue nil) || []).each do |mc|
        code = (mc.code rescue 0)
        pars = (mc.parameters rescue nil) || []
        case code
        when 1, 2, 3, 4
          dir = [2, 4, 6, 8][code - 1]
          st[:face] = dir unless st[:fix]
          step(o, st, PokeAccess::DIR_DELTA[dir][0], PokeAccess::DIR_DELTA[dir][1])
        when 5, 6, 7, 8
          st[:face] = diagonal_face(code, st[:face]) unless st[:fix]
          step(o, st, DIAGONAL[code][0], DIAGONAL[code][1])
        when 9, 10, 11
          return false
        when 23, 24
          st[:face] = nil unless st[:fix]
        when 12, 13
          return false if st[:face].nil?
          s = code == 12 ? 1 : -1
          dd = PokeAccess::DIR_DELTA[st[:face]]
          step(o, st, dd[0] * s, dd[1] * s)
        when 14
          jx = pars[0].to_i; jy = pars[1].to_i
          next if jx == 0 && jy == 0
          o.jump = true
          st[:face] = jump_face(jx, jy, st[:face]) unless st[:fix]
          step(o, st, jx, jy)
        when 16, 17, 18, 19
          st[:face] = [2, 4, 6, 8][code - 16] unless st[:fix]
        when 20, 21, 22
          next if st[:fix]
          return false if st[:face].nil?
          f = st[:face]
          st[:face] = code == 20 ? TURN_RIGHT[f] : (code == 21 ? TURN_LEFT[f] : 10 - f)
        when 35 then st[:fix] = true
        when 36 then st[:fix] = false
        when 37 then st[:through] = true
        when 38 then st[:through] = false
        when 45
          return false if pars[0].to_s =~ MOVING_SCRIPT
        end
      end
      true
    rescue StandardError
      false
    end

    # One step of a route: the position moves and the path records where it left the player.
    def self.step(o, st, dx, dy)
      st[:x] += dx
      st[:y] += dy
      o.through = true if st[:through]
      o.path.push([st[:x], st[:y], st[:face]])
    end

    # The facing after a diagonal step, as RMXP turns it: a vertical facing is kept on the vertical part,
    # a horizontal one on the horizontal part.
    def self.diagonal_face(code, face)
      case code
      when 5 then face == 6 ? 4 : (face == 8 ? 2 : face)
      when 6 then face == 4 ? 6 : (face == 8 ? 2 : face)
      when 7 then face == 6 ? 4 : (face == 2 ? 8 : face)
      else        face == 4 ? 6 : (face == 2 ? 8 : face)
      end
    end

    # The facing after a jump: toward the longer leg of it, as Game_Character#jump turns.
    def self.jump_face(jx, jy, face)
      return (jx < 0 ? 4 : 6) if jx.abs > jy.abs
      jy < 0 ? 8 : 2
    end

    # Script conditions answered without running them: comparisons, parentheses, !, && and || over live values
    # (ATOMS) and a game's own calls (register_atom). An unknown call reads as :unknown, which && or || may still
    # settle; an answer that rests on it is nil.
    module ScriptCondition
      # [pattern, value reader]; a reader gets the match and the walk's context (EventPages.context): :face, :act,
      # :vars, :pos (the player's [x, y], nil when the start is not given) and :self (the event's [x, y]).
      ATOMS = [
        [/\A\$PokemonGlobal\.(bicycle|surfing|diving)\b/, lambda { |m, _c| ($PokemonGlobal.send(m[1]) ? true : false) }],
        [/\A\$game_switches\[\s*(\d+)\s*\]/, lambda { |m, _c| ($game_switches[m[1].to_i] ? true : false) }],
        [/\A\$game_variables\[\s*(\d+)\s*\]/, lambda { |m, c| EventPages.variable(m[1].to_i, c[:vars]) }],
        [/\ApbGet\(\s*(\d+)\s*\)/, lambda { |m, c| EventPages.variable(m[1].to_i, c[:vars]) }],
        [/\A\$PokemonBag\.pbQuantity\(\s*(?:PBItems::|:)(\w+)\s*\)/, lambda { |m, _c| ScriptCondition.quantity(m[1]) }],
        [/\A\$bag\.quantity\(\s*:(\w+)\s*\)/, lambda { |m, _c| ScriptCondition.quantity(m[1]) }],
        [/\A(?:\$PokemonBag\.pbHasItem\?|\$bag\.has\?)\(\s*(?:PBItems::|:)(\w+)\s*\)/, lambda { |m, _c| ScriptCondition.holds?(m[1]) }],
        [/\AInput\.press\?\(\s*Input::(UP|DOWN|LEFT|RIGHT)\s*\)/, lambda { |m, c| ScriptCondition.key_held(m[1], c) }],
        [/\A\$game_player\.direction\b/, lambda { |_m, c| c[:face] }],
        [/\A\$game_player\.moving\?/, lambda { |_m, _c| false }],
        [/\A\$game_player\.(x|y)\b/, lambda { |m, c| c[:pos] ? c[:pos][m[1] == "x" ? 0 : 1] : :unknown }],
        [/\Aget_character\(\s*(-1|0)\s*\)\.(x|y)\b/, lambda { |m, c| ScriptCondition.character_at(m[1], m[2], c) }],
        [/\A\$PokemonGlobal\.visitedMaps\[\s*(\d+)\s*\]/, lambda { |m, _c| ($PokemonGlobal.visitedMaps[m[1].to_i] ? true : false) }],
        [/\A\$game_map\.map_id\b/, lambda { |_m, _c| $game_map.map_id }],
        [/\A(?:true|false|nil)\b/, lambda { |m, _c| { "true" => true, "false" => false }[m[0]] }],
        [/\A-?\d+/, lambda { |m, _c| m[0].to_i }]
      ]
      OPERATORS = /\A(?:==|!=|>=|<=|&&|\|\||>|<|!|\(|\)|and\b|or\b|not\b)/
      # A call the grammar does not know: a name, a chain of methods, an argument list with no parentheses inside it.
      UNKNOWN_CALL = /\A[\$@]?[A-Za-z_]\w*(?:(?:\.|::)[A-Za-z_]\w*[?!]?)*(?:\([^()]*\))?/
      # A question put to the player, whose arguments may hold anything (a message with parentheses in it):
      # a yes/no confirmation, or a message or menu with options, answered in a walk that says yes.
      PROMPTS = [[/\A(?:Kernel\.)?pbConfirmMessage\w*\s*\(/, true], [/\A(?:Kernel\.)?(?:pbShowCommands\w*|pbMessage\w*)\s*\(/, 0]]

      # A coordinate of the interpreter's get_character: -1 the player (:pos), 0 the event running (:self).
      def self.character_at(who, axis, ctx)
        at = who == "0" ? ctx[:self] : ctx[:pos]
        at ? at[axis == "x" ? 0 : 1] : :unknown
      end

      # Declares a script call a game defines for its own events, as [pattern, reader]: the reader gets the
      # match and the walk's context and answers the value the call would return, or :unknown.
      def self.register_atom(pattern, &reader)
        @extra ||= []
        @extra.push([pattern, reader])
      end

      # True, false, or nil when the script is outside the grammar or its answer rests on a value it cannot read.
      # param ctx the walk's context (see EventPages.context); a bare Hash with :face will do
      def self.evaluate(src, ctx)
        toks = tokenize(src.to_s.strip, ctx)
        return nil if toks.nil? || toks.empty?
        @toks = toks
        @at = 0
        v = either
        return nil if v == :bad || v == :unknown || @at != @toks.length
        v ? true : false
      rescue StandardError
        nil
      end

      # The script as [:op, text] and [:val, value] tokens, or nil at the first thing it does not know.
      def self.tokenize(s, ctx)
        out = []
        until s.empty?
          s = s.sub(/\A\s+/, "")
          break if s.empty?
          if (m = s.match(OPERATORS))
            out.push([:op, m[0]])
            s = s[m[0].length..-1]
            next
          end
          prompt = PROMPTS.find { |re, _v| s =~ re }
          if prompt
            close = closing_paren(s, s.match(prompt[0])[0].length - 1)
            return nil if close.nil?
            out.push([:val, ctx[:act] ? prompt[1] : :unknown])
            s = s[(close + 1)..-1]
            next
          end
          atom = (@extra || []).find { |re, _r| s =~ re } || ATOMS.find { |re, _r| s =~ re }
          if atom
            m = s.match(atom[0])
            out.push([:val, atom[1].call(m, ctx)])
          else
            m = s.match(UNKNOWN_CALL)
            return nil unless m
            out.push([:val, :unknown])
          end
          s = s[m[0].length..-1]
        end
        out
      end

      # The index of the parenthesis closing the one at s[open], skipping quoted text, or nil.
      def self.closing_paren(s, open)
        depth = 0
        quote = nil
        i = open
        while i < s.length
          ch = s[i, 1]
          if quote
            if ch == "\\" then i += 1
            elsif ch == quote then quote = nil
            end
          elsif ch == '"' || ch == "'"
            quote = ch
          elsif ch == "("
            depth += 1
          elsif ch == ")"
            depth -= 1
            return i if depth == 0
          end
          i += 1
        end
        nil
      end

      # a || b, a or b: settled by a known true on either side.
      def self.either
        v = both
        while (t = @toks[@at]) && t[0] == :op && (t[1] == "||" || t[1] == "or")
          @at += 1
          r = both
          return :bad if v == :bad || r == :bad
          v = if v == :unknown then ((r && r != :unknown) ? r : :unknown)
              else (v || r)
              end
        end
        v
      end

      # a && b, a and b: settled by a known false on either side.
      def self.both
        v = negated
        while (t = @toks[@at]) && t[0] == :op && (t[1] == "&&" || t[1] == "and")
          @at += 1
          r = negated
          return :bad if v == :bad || r == :bad
          v = if v == :unknown then (r ? :unknown : r)
              elsif !v then v
              else r
              end
        end
        v
      end

      # !a, not a
      def self.negated
        t = @toks[@at]
        if t && t[0] == :op && (t[1] == "!" || t[1] == "not")
          @at += 1
          v = negated
          return v if v == :bad || v == :unknown
          return !v
        end
        compared
      end

      # a == b and the other comparisons
      def self.compared
        a = primary
        t = @toks[@at]
        return a unless t && t[0] == :op && ["==", "!=", ">=", "<=", ">", "<"].include?(t[1])
        @at += 1
        b = primary
        return :bad if a == :bad || b == :bad
        return :unknown if a == :unknown || b == :unknown
        case t[1]
        when "==" then a == b
        when "!=" then a != b
        else
          return :bad unless a.is_a?(Integer) && b.is_a?(Integer)
          a.send(t[1], b)
        end
      end

      # a value, or a parenthesised expression
      def self.primary
        t = @toks[@at]
        return :bad if t.nil?
        @at += 1
        return t[1] if t[0] == :val
        return :bad unless t[1] == "("
        v = either
        c = @toks[@at]
        return :bad unless c && c[0] == :op && c[1] == ")"
        @at += 1
        v
      end

      # Whether a direction key is held: the one the walk faces. A held key is noted in the context (ctx[:held]).
      def self.key_held(name, ctx)
        held = { "DOWN" => 2, "LEFT" => 4, "RIGHT" => 6, "UP" => 8 }[name] == ctx[:face]
        ctx[:held] = true if held
        held
      end

      # How many of an item the bag holds, or :unknown when no bag answers.
      def self.quantity(sym)
        n = PokeAccess::Engine.bag_quantity(sym.to_sym)
        n.nil? ? :unknown : n
      end

      # Whether the bag holds an item, or :unknown when no bag answers.
      def self.holds?(sym)
        n = quantity(sym)
        n == :unknown ? n : n > 0
      end
    end
  end
end
