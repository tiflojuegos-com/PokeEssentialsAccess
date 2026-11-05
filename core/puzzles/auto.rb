module PokeAccess
  module Puzzles
    # What a map whose puzzles nobody declared still tells: what a control the player uses opens or closes, by a line at
    # the :map_changes reading's level, and the silent controls among its events, for the locator's puzzles category. A
    # silent control writes a flag another event of the map reads, with no text, goods or transfer of its own. A map that
    # declares a mechanic speaks for itself: none of this runs there, unless all its mechanics ask for it (auto).
    module Auto
      # Frames with no event running before what a control did is said: what it set off may take a moment.
      SETTLE = 6
      # Text commands from which what fired is a scene rather than a control.
      SCENE_TEXTS = 4
      # Sheets of people and Pokemon: their change is a scene's, unless a silent control makes it.
      PERSON_RE = /\A(?:(?:BW|OW|DP|NB|boy|girl|chic[oa]|leader)(?:[ _\d(]|\z)|trchar|trainer|pkmn|pokemon|NPC|HGSS|character|\d+(?:_\d+)?s?\z)/i
      # Commands that talk, ask, hand over goods or start a fight.
      LOUD_CODES = [101, 102, 103, 105, 125, 126, 127, 128, 129, 301, 302, 303, 351, 352]
      # Scripts that ask for a text or use a field action, besides those that talk or give (EventPages::TALK_SCRIPT,
      # Locator::ITEM_GIFT_RE).
      OTHER_LOUD_RE = /pbEnterText|pbFreeText|pbHeadbutt|pbAddPokemon/
      # How many touch events alike a map may hold as controls: more are the tiles of a board, for a profile to declare.
      BOARD = 8
      SWITCH_WRITE_RE = /\$game_switches\[\s*(\d+)\s*\]\s*=[^=]/
      VAR_WRITE_RE = /\$game_variables\[\s*(\d+)\s*\]\s*(?:=[^=]|\+=|-=)|\bpbSet\(\s*(\d+)\s*,/
      SWITCH_READ_RE = /\$game_switches\[\s*(\d+)\s*\]/
      VAR_READ_RE = /\$game_variables\[\s*(\d+)\s*\]|\bpbGet\(\s*(\d+)\s*\)/

      @walls = {}
      @moved = {}
      @people = {}

      # The player's use of an event: its page starts on the map's interpreter, by the action button or a touch. Keeps it
      # for what it sets off and what a mechanic says of it; a scene told by a person, or a long one, is left to itself.
      def self.fired(int, list, id)
        return unless int.equal?(($game_system.map_interpreter rescue nil))
        Answers.forget
        Reach.forget
        return unless id.to_i > 0
        ev = ($game_map.events[id] rescue nil)
        trig = ev && PokeAccess.ivar(ev, :@trigger)
        return unless trig && trig <= 2
        @last_used = id
        PokeAccess::World::Mechanics.used(ev)
        return unless on_here?
        PokeAccess::World::Events.sync(true)
        arm(ev, id, trig, list)
      end

      # True on a map with no mechanic, or whose mechanics all keep this on.
      def self.on_here?
        PokeAccess::World::Mechanics.instances.all? { |inst| inst.spec[:auto] }
      end

      # Starts watching what an event just fired changes, unless it is a person talking or a long scene; what the last one
      # did is said first.
      def self.arm(ev, id, trig, list)
        settled if @source
        list = list.is_a?(Array) ? list : []
        loud = loud?(list)
        return if loud && person_sheet?(ev.character_name.to_s)
        return if list.count { |c| (c.code rescue 0) == 101 } >= SCENE_TEXTS
        @idle = 0
        r = PokeAccess::World::Events.record_of(ev)
        @source = { :id => id, :silent => !loud, :worked => trig == 0 && !r.nil? && !PokeAccess::World::Events.facet(r, :auto_control).nil? }
      end

      # True when a page talks, hands over goods, fights or runs or branches on a script that does, by itself or through a
      # common event it calls.
      def self.loud?(list, deep = true)
        list.any? do |c|
          code = (c.code rescue 0)
          next true if LOUD_CODES.include?(code)
          next true if deep && code == 117 && loud?(PokeAccess::EventPages.common_list(c.parameters[0]) || [], false)
          src = PokeAccess::Routes::Effects.script_of(c)
          src =~ PokeAccess::EventPages::TALK_SCRIPT || src =~ PokeAccess::Locator::ITEM_GIFT_RE || src =~ OTHER_LOUD_RE ? true : false
        end
      end

      # True for a sheet of a person or a Pokemon, also one named after its species.
      def self.person_sheet?(sheet)
        return false if sheet.empty?
        !(sheet =~ PERSON_RE).nil? || !PokeAccess::Locator.sprite_species_named(sheet).nil?
      end

      # True when no events are asked for, or the event last used is among them (a sent_back's :events).
      def self.last_used_among?(what)
        return true unless what
        ev = @last_used && ($game_map.events[@last_used] rescue nil)
        ev ? PokeAccess::World::Mechanics.picks?(what, ev) : false
      end

      # An event of the map changed (Events.on_change): keeps whether it blocks, and what it blocked before the control
      # that is being watched, but for its own event and for one that walks about. Someone drawn as a person stays one when
      # they leave and their sheet goes.
      def self.noticed(r, how)
        blocks = how != :go && blocks?(r)
        was = @walls[r.id] ? true : false
        @walls[r.id] = blocks
        @people[r.id] ||= person_sheet?(r.char.to_s) unless how == :move
        return if how == :move || was == blocks
        s = @source
        return if s.nil? || r.id == s[:id] || PokeAccess::World::Events.mover?(r)
        return if !s[:silent] && @people[r.id]
        @moved[r.id] ||= [was, r.x, r.y]
      end

      # True when a record stands in the way: drawn, and not walked through.
      def self.blocks?(r)
        return false if r.through
        !r.char.to_s.empty? || r.tile.to_i > 0
      end

      # One map frame: once what a used control set off has run its course, says what it did.
      def self.tick
        return unless @source
        PokeAccess::World::Events.sync
        return unless @source
        if ($game_system.map_interpreter.running? rescue false)
          @idle = 0
          return
        end
        @idle += 1
        settled if @idle >= SETTLE
      end

      # Drops what is being watched.
      def self.forget_source
        @source = nil
        @moved = {}
      end

      # Says what the control did, at the reading's level: what opened and closed, or that it worked.
      def self.settled
        s = @source
        opened = []
        closed = []
        @moved.each do |id, c|
          next if c[0] == (@walls[id] ? true : false)
          (c[0] ? opened : closed).push([c[1], c[2]])
        end
        forget_source
        return unless PokeAccess::Verbosity.keep?(:map_changes, :medium)
        lines = [change_line(opened, :chg_open_one, :chg_open_many), change_line(closed, :chg_shut_one, :chg_shut_many)].compact
        lines.push(PokeAccess::I18n.t(:chg_used)) if lines.empty? && s[:worked]
        PokeAccess.speak(PokeAccess.sentences(lines), false) unless lines.empty?
      end

      # What opened or closed: how many groups of touching tiles and, in full, where the only or the nearest one is; nil
      # with none.
      def self.change_line(tiles, one, many)
        return nil if tiles.empty?
        n = groups(tiles)
        what = n == 1 ? PokeAccess::I18n.t(one) : PokeAccess::I18n.t(many, :n => n)
        return what unless PokeAccess::Verbosity.keep?(:map_changes, :full)
        px = $game_player.x
        py = $game_player.y
        x, y = tiles.min_by { |t| (t[0] - px).abs + (t[1] - py).abs }
        dist = PokeAccess::Puzzles.offset_phrase(x - px, y - py)
        return what if dist.empty?
        PokeAccess::I18n.t(n == 1 ? :chg_where : :chg_nearest, :what => what, :dist => dist)
      end

      # How many groups of touching tiles there are among some.
      def self.groups(tiles)
        left = tiles.dup
        n = 0
        until left.empty?
          n += 1
          queue = [left.shift]
          until queue.empty?
            x, y = queue.shift
            near = left.select { |t| (t[0] - x).abs + (t[1] - y).abs == 1 }
            left -= near
            queue.concat(near)
          end
        end
        n
      end

      # The map's silent controls as targets of the puzzles category: what is drawn, or what stands on a tile nobody can
      # walk on, which the map draws; one hidden on open floor with the assist alone.
      def self.targets
        return [] unless on_here?
        list = PokeAccess::World::Events.summary(:auto_controls) { controls }
        list = list.reject { |r, hidden| (hidden && !PokeAccess::Puzzles.assist?) || PokeAccess::Locator.hidden?(r.ev) }
        list.map { |r, _hidden| PokeAccess::Locator::SurfaceTarget.new(r.x, r.y, name_of(r), :puzzle_control, r.id) }
      rescue StandardError => e
        PokeAccess.swallowed(e)
        []
      end

      # Every silent control of the map as [record, hidden on open floor], but touch events alike past BOARD.
      def self.controls
        out = []
        PokeAccess::World::Events.records.each do |r|
          hidden = PokeAccess::World::Events.facet(r, :auto_control)
          out.push([r, hidden]) unless hidden.nil?
        end
        alike = Hash.new(0)
        out.each { |r, _hidden| alike[family_of(r)] += 1 if r.trigger != 0 }
        out.reject { |r, _hidden| r.trigger != 0 && alike[family_of(r)] > BOARD }
      end

      # What makes touch events alike: their sheet or tile and their name, but for the one the editor gives by default.
      def self.family_of(r); [r.char.to_s, r.tile.to_i, r.name.to_s =~ /\AEV\d+\z/i ? "" : r.name.to_s]; end

      # One event's :auto_control facet: whether the silent control it is stands hidden on open floor; nil for any other.
      def self.control_facet(r)
        return nil unless control?(r)
        r.char.to_s.empty? && r.tile.to_i <= 0 && PokeAccess::Routes::Effects.fires_on_arrival?(r.ev)
      end

      # True for what the player works by the action button, or steps on when drawn, no person, field obstacle or exit, whose
      # page says nothing and writes a flag another event of the map reads.
      def self.control?(r)
        return false if PokeAccess::World::Mechanics.not_control?(r.ev)
        drawn = !r.char.to_s.empty? || r.tile.to_i > 0
        return false if person_sheet?(r.char.to_s) || !(r.trigger == 0 || (r.trigger == 1 && drawn))
        list = PokeAccess.ivar(r.ev, :@list)
        return false unless list.is_a?(Array) && !loud?(list) && list.none? { |c| (c.code rescue 0) == 201 }
        return false if PokeAccess::Locator.fieldmove_label(r.ev) || PokeAccess::Locator.transfer_event?(r.ev)
        linked?(r.id, writes_of(list))
      end

      # The name the lists give a control, or the word for a mechanism where they would call it just an object.
      def self.name_of(r)
        name = PokeAccess::Locator.target_name(r.ev)
        name == PokeAccess::I18n.t(:loc_object) ? PokeAccess::I18n.t(:puzzle_mechanism) : name
      end

      # True when another event of the map reads any of the flags, as [:switch | :var, id].
      def self.linked?(id, flags)
        readers = readers_here
        flags.any? { |k| (readers[k] || {}).keys.any? { |o| o != id } }
      end

      # The flags a page writes, directly or through a common event it calls, as [:switch | :var, id]. A variable that only
      # notes what the game reads (an item count, where someone stands) holds no state of the map.
      def self.writes_of(list, deep = true)
        out = []
        list.each do |c|
          code = (c.code rescue 0)
          pr = (c.parameters rescue nil) || []
          case code
          when 121 then (pr[0]..pr[1]).each { |i| out.push([:switch, i]) }
          when 122 then (pr[0]..pr[1]).each { |i| out.push([:var, i]) } if pr[3].to_i <= 2
          when 117 then out.concat(writes_of(PokeAccess::EventPages.common_list(pr[0]) || [], false)) if deep
          when 355, 655
            pr[0].to_s.scan(SWITCH_WRITE_RE) { |m| out.push([:switch, m[0].to_i]) }
            pr[0].to_s.scan(VAR_WRITE_RE) { |a, b| out.push([:var, (a || b).to_i]) }
          end
        end
        out.uniq
      end

      # Which events read which flag on this map, in their page conditions or their branches: flag => {event id => true}.
      # Kept for the map: an event's pages never change.
      def self.readers_here
        mid = $game_map.map_id
        return @readers[1] if @readers && @readers[0] == mid
        table = {}
        ($game_map.events || {}).each do |id, ev|
          PokeAccess::World::Mechanics::Links.pages(ev).each { |pg| page_reads(pg, id, table) }
        end
        @readers = [mid, table]
        table
      end

      # Notes what one page reads.
      def self.page_reads(pg, id, table)
        c = pg.condition
        note(table, [:switch, c.switch1_id], id) if (c.switch1_valid rescue false)
        note(table, [:switch, c.switch2_id], id) if (c.switch2_valid rescue false)
        note(table, [:var, c.variable_id], id) if (c.variable_valid rescue false)
        ((pg.list rescue nil) || []).each do |cmd|
          next unless (cmd.code rescue 0) == 111
          pr = cmd.parameters
          case pr[0]
          when 0 then note(table, [:switch, pr[1]], id)
          when 1 then note(table, [:var, pr[1]], id)
          when 12
            pr[1].to_s.scan(SWITCH_READ_RE) { |m| note(table, [:switch, m[0].to_i], id) }
            pr[1].to_s.scan(VAR_READ_RE) { |a, b| note(table, [:var, (a || b).to_i], id) }
          end
        end
      end

      # Notes that an event reads a flag.
      def self.note(table, key, id); (table[key] ||= {})[id] = true; end

      # Drops all that is kept: a new map, a load, a reset.
      def self.forget
        @walls = {}
        @people = {}
        @readers = nil
        @last_used = nil
        forget_source
      end
    end

    # With the assist, what an entry or a menu asks for: the answer of a number or text entry, where the page that opens it
    # compares what is entered with a fixed value right after, and the right option of a menu, by the rule a declaration
    # gives (right_choice).
    module Answers
      # How many commands after an entry its comparison is looked for.
      LOOK = 12
      TEXT_RE = /==\s*["']([^"']+)["']/
      NUMBER_RE = /==\s*(\d+)\b/
      # What a running script opens an entry with.
      ENTRY_RE = /ChooseNumber|pbEnterText|pbTextEntry|FreeText/
      # Where a script keeps what is entered: the variable it assigns or pbTextEntry's last argument.
      ENTRY_VAR_RE = /\$game_variables\[\s*(\d+)\s*\]\s*=[^=]|\bpbSet\(\s*(\d+)\s*,|pbTextEntry\(.*,\s*(\d+)\s*\)/
      # What the game skips over looking for what comes after a Show Text: its further lines, comments and labels.
      SKIPPED = [401, 108, 408, 118]

      # Forgets what was said: the player has used an event again.
      def self.forget; @said = nil; end

      # A Show Text about to run: the game opens a menu or a number entry right after it in the same message, so what they
      # ask goes after the text.
      def self.before_text(int)
        return unless PokeAccess::Puzzles.assist?
        list = PokeAccess.ivar(int, :@list)
        i = PokeAccess.ivar(int, :@index)
        return unless list.is_a?(Array) && i.is_a?(Integer)
        return say(int, i, true) if text_menu(list, i)
        j = i + 1
        j += 1 while SKIPPED.include?((list[j].code rescue 0))
        say(int, j, true) if [102, 103].include?((list[j].code rescue 0))
      end

      # The words of the Show Text at list[i], its further lines joined.
      def self.message_text(list, i)
        j = i + 1
        j += 1 while (list[j].code rescue 0) == 401
        list[i...j].map { |c| c.parameters[0].to_s }.join(" ")
      end

      # The menu a Show Text holds in its words (\ch[variable,cancel,options...]) as [variable, options], or nil.
      def self.text_menu(list, i)
        return nil unless message_text(list, i) =~ /\\ch\[([^\]]*)\]/
        parts = $1.split(",")
        [parts[0].to_i, parts.drop(2).map { |o| o.gsub(/\s+/, " ").strip }]
      end

      # Says what the menu or entry at an interpreter's command i asks for, queued and once for it, as one function of the
      # game may call another; after the message that opens it with after_text.
      def self.say(int = running, i = nil, after_text = false)
        return unless int && PokeAccess::Puzzles.assist?
        i ||= PokeAccess.ivar(int, :@index)
        list = PokeAccess.ivar(int, :@list)
        at = [list.object_id, i]
        return if at == @said
        a = [101, 102].include?((list[i].code rescue 0)) ? right_option(int, list, i) : expected(int, i)
        @said = at
        return unless a
        line = PokeAccess::I18n.t(:puzzle_answer, :a => a)
        after_text ? PokeAccess.also_after_next_line(line) : PokeAccess.speak(line, false)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Says the answer as an entry a script opens does, when the running command is that script: a game's own screen may
      # ask for a number from within another script (a mart's quantity), and what follows has nothing to do with it. After
      # the message it asks with, with after_text.
      def self.say_scripted(after_text = false)
        int = running
        say(int, nil, after_text) if int && scripted_entry?(int)
      end

      # The one option of the menu at list[i], a Show Command or a Show Text holding one, the declaration of the event running
      # it tells is right, as the game shows it; nil with no rule, or with none or several left.
      def self.right_option(int, list, i)
        rule = choice_rule(int)
        return nil unless rule
        names, options = menu_at(list, i)
        right = options.select { |_option, cmds| right?(rule, cmds) }
        return nil unless right.length == 1
        text = names[right[0][0]].to_s
        text = (respond_to?(:_MAPINTL, true) ? _MAPINTL($game_map.map_id, text) : text) rescue text
        PokeAccess.clean(text)
      end

      # The menu at list[i] as [its options' words, [option's index, its commands] each].
      def self.menu_at(list, i)
        return [list[i].parameters[0], branches(list, i)] if list[i].code == 102
        var, names = text_menu(list, i)
        [names, text_branches(list, i, var)]
      end

      # What a declaration of the map says of the menus of the event an interpreter runs, or nil.
      def self.choice_rule(int)
        ev = ($game_map.events[PokeAccess.ivar(int, :@event_id)] rescue nil)
        return nil unless ev
        PokeAccess::World::Mechanics.instances.each do |inst|
          hit = (inst.spec[:choices] || []).find { |c| PokeAccess::World::Mechanics.picks?(c[:events], ev) }
          return hit if hit
        end
        nil
      end

      # The branches of the menu at list[i], as [option's index, its commands], without what cancelling does.
      def self.branches(list, i)
        depth = list[i].indent
        out = []
        current = nil
        ((i + 1)...list.length).each do |j|
          c = list[j]
          if c.indent == depth
            break if c.code == 404
            current = c.code == 402 ? [] : nil
            out.push([c.parameters[0], current]) if current
          elsif current
            current.push(c)
          end
        end
        out
      end

      # The branches of a Show Text's own menu: what follows it, up to the next such menu, comparing its variable with an option's
      # place, as [that place, the commands the comparison holds]; what cancelling leaves there is no option.
      def self.text_branches(list, i, var)
        depth = list[i].indent
        out = []
        ((i + 1)...list.length).each do |j|
          c = list[j]
          break if c.indent < depth || (c.code == 101 && text_menu(list, j))
          next unless c.indent == depth && comparison_of?(c, var) && c.parameters[3] >= 0
          out.push([c.parameters[3], body(list, j)])
        end
        out
      end

      # True for a Conditional Branch on a variable being equal to a constant.
      def self.comparison_of?(c, var)
        c.code == 111 && c.parameters[0] == 1 && c.parameters[1] == var && c.parameters[2] == 0 && c.parameters[4] == 0
      end

      # The commands a branch holds: those after list[i] that sit deeper than it.
      def self.body(list, i)
        depth = list[i].indent
        (list[(i + 1)..-1] || []).take_while { |c| c.indent > depth }
      end

      # True for a branch as a rule wants it: it does what :takes says and not what :avoids says.
      def self.right?(rule, cmds)
        return false if rule[:avoids] && does?(cmds, rule[:avoids])
        rule[:takes] ? does?(cmds, rule[:takes]) : true
      end

      # True when a branch's commands write a flag ({:var => id}, {:switch => id} or {:self => letter}), set a variable to a
      # value (stores?), take the player away or into a fight (:transfer, :battle), or give an item (:item).
      def self.does?(cmds, what)
        return cmds.any? { |c| c.code == 201 } if what == :transfer
        return cmds.any? { |c| c.code == 126 || PokeAccess::Routes::Effects.script_of(c) =~ PokeAccess::Locator::ITEM_GIFT_RE } if what == :item
        if what == :battle
          return cmds.any? { |c| c.code == 301 || PokeAccess::Routes::Effects.script_of(c) =~ PokeAccess::EventPages::BATTLE_SCRIPT }
        end
        return cmds.any? { |c| c.code == 123 && c.parameters[0] == what[:self] } if what[:self]
        return stores?(cmds, what) if what[:compared_by] || what[:value]
        Auto.writes_of(cmds).include?(what[:var] ? [:var, what[:var]] : [:switch, what[:switch]])
      end

      # True when a branch sets a variable to the value a rule asks for: its :value, or the one the event it names takes as
      # right.
      def self.stores?(cmds, what)
        value = what[:compared_by] ? compared(what[:compared_by], what[:var], what[:moving]) : what[:value]
        value = value.call if value.respond_to?(:call)
        return false if value.nil?
        var = what[:var]
        cmds.any? do |c|
          pr = c.parameters
          c.code == 122 && pr[0] <= var && pr[1] >= var && pr[2] == 0 && pr[3] == 0 && pr[4] == value
        end
      end

      # The value an event's page as it stands compares a variable with: the first one, or the first whose branch writes the
      # variable moving; nil with none.
      def self.compared(id, var, moving = nil)
        ev = ($game_map.events[id] rescue nil)
        list = ev && PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array)
        list.each_with_index do |c, i|
          next unless comparison_of?(c, var)
          return c.parameters[3] if moving.nil? || Auto.writes_of(body(list, i)).include?([:var, moving])
        end
        nil
      end

      # True when the script an interpreter is running opens an entry.
      def self.scripted_entry?(int)
        list = PokeAccess.ivar(int, :@list)
        i = PokeAccess.ivar(int, :@index)
        return false unless list.is_a?(Array) && i.is_a?(Integer)
        !(script_running(list, i) =~ ENTRY_RE).nil?
      end

      # The lines of the script at an interpreter's command i, the last of them as it runs; "" for any other command. From
      # Essentials 19 script commands in a row run as one.
      def self.script_running(list, i)
        return "" unless [355, 655].include?((list[i].code rescue 0))
        joined = PokeAccess::Engine.gamedata?
        j = i
        j -= 1 while j > 0 && ((list[j].code rescue 0) == 655 || (joined && [355, 655].include?((list[j - 1].code rescue 0))))
        (j..i).map { |k| list[k].parameters[0].to_s }.join("\n")
      end

      # The variable an entry at command i writes: a number input's, or where its script keeps it; nil when it does not tell.
      def self.entry_var(list, i)
        return list[i].parameters[0] if (list[i].code rescue 0) == 103
        return nil unless script_running(list, i) =~ ENTRY_VAR_RE
        ($1 || $2 || $3).to_i
      end

      # The one fixed value the commands after an entry, up to the next one, compare its own variable with, or nil with none
      # or several (a menu of numbers rather than an answer), or an entry that does not tell where it keeps what is entered.
      def self.expected(int = running, i = nil)
        list = int && PokeAccess.ivar(int, :@list)
        i ||= int && PokeAccess.ivar(int, :@index)
        return nil unless list.is_a?(Array) && i.is_a?(Integer)
        var = entry_var(list, i)
        return nil unless var
        found = []
        ((i + 1)..[i + LOOK, list.length - 1].min).each do |j|
          break if [102, 103].include?((list[j].code rescue 0))
          v = constant_of(list[j], var)
          found.push(v) if v
        end
        found = found.uniq
        found.length == 1 ? found[0] : nil
      end

      # The interpreter running now, the innermost of the map's.
      def self.running
        int = ($game_system.map_interpreter rescue nil)
        return nil unless int && (int.running? rescue false)
        loop do
          child = PokeAccess.ivar(int, :@child_interpreter)
          return int unless child && (child.running? rescue false)
          int = child
        end
      end

      # The fixed value a branch compares a variable with: as a command against a number but 0, or in a script that names it
      # against a text or a number.
      def self.constant_of(c, var)
        return nil unless (c.code rescue 0) == 111
        pr = c.parameters
        return (pr[1] == var && pr[2] == 0 && pr[4] == 0 && pr[3].to_i != 0 ? pr[3].to_i : nil) if pr[0] == 1
        return nil unless pr[0] == 12
        src = pr[1].to_s
        return nil unless src =~ /(?:game_variables\[\s*|pbGet\(\s*)#{var}\s*[\]\)]/
        return $1 if src =~ TEXT_RE
        src =~ NUMBER_RE && $1.to_i != 0 ? $1.to_i : nil
      end
    end
  end
end

# What a mechanic hides stays out of the lists and the sonar, what it says of a teleport goes before the core's line, and
# what can be pushed says so after its name.
PokeAccess::Locator.register_rule(:hidden) { |ev| PokeAccess::Puzzles.hidden_event?(ev) }
PokeAccess::Locator.teleport_cause(:puzzles) { |from, to| PokeAccess::Puzzles.sent_back_line(from, to) }
PokeAccess::Locator.move_cause(:puzzles) { |from, to, kind| PokeAccess::Puzzles.sent_back_line(from, to, kind) }
PokeAccess::Locator.register_rule(:mark) { |t| PokeAccess::Routes::Effects.push_mark(t) }

PokeAccess::World::Events.facet_provider(:auto_control) { |r| PokeAccess::Puzzles::Auto.control_facet(r) }
PokeAccess::World::Events.on_change { |_tiles, r, how| PokeAccess::Puzzles::Auto.noticed(r, how) }
PokeAccess::World::Epoch.on(:map) { PokeAccess::Puzzles::Auto.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Puzzles::Auto.forget }

PokeAccess::Hooks.after_hook("Interpreter", :setup, :optional => true) do |int, _r, args|
  PokeAccess::Puzzles::Auto.fired(int, args[0], args[1])
end

PokeAccess::Hooks.before_hook("Interpreter", :command_101, :optional => true) { |i, _a| PokeAccess::Puzzles::Answers.before_text(i) }
PokeAccess::Hooks.before_hook("Interpreter", :command_102, :optional => true) { |i, _a| PokeAccess::Puzzles::Answers.say(i) }
PokeAccess::Hooks.before_hook("Interpreter", :command_103, :optional => true) { |i, _a| PokeAccess::Puzzles::Answers.say(i) }
%w[pbEnterText pbTextEntry pbFreeText pbChooseNumber].each do |f|
  PokeAccess::Hooks.wrap_kernel(f, "puzzle_answer_#{f}", :before) { |_args, _r| PokeAccess::Puzzles::Answers.say_scripted }
end
%w[pbMessageFreeText pbMessageChooseNumber].each do |f|
  PokeAccess::Hooks.wrap_kernel(f, "puzzle_answer_#{f}", :before) { |_args, _r| PokeAccess::Puzzles::Answers.say_scripted(true) }
end
