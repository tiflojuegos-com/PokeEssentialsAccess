# Hacking Minigame by wrigty12 (HackingGame_Scene): a circuit of nodes joined by paths, drawn with no window. Each node
# reached is said with its state and wires, what lies along each way out and the Antivirus on the hunt; a puzzle's arrow
# keys are said as it opens and the next one as each is played; a Key Node's revealed keys, the Antivirus alert, what an
# Antivirus takes when it catches the player, the moves left and the timer's half and quarter marks are said as they
# come. The info key has all of it for the moment, and the row key the whole board too.
module PokeAccess
  module HackingMinigame
    # The four ways in the scene's numbering, as [its number, the word for it, across, down].
    WAYS = [[8, :dir_up, 0, -1], [2, :dir_down, 0, 1], [4, :dir_left, -1, 0], [6, :dir_right, 1, 0]]
    # What a puzzle key's number asks for.
    KEY_WORDS = { 8 => :dir_up, 2 => :dir_down, 4 => :dir_left, 6 => :dir_right }
    # The nodes that stay locked (state 1) until their puzzle is solved.
    PUZZLE_NODES = [:Locked, :Checkpoint, :Light]
    # The states HackingKey#state= is given for the key to press and for a wrong one.
    KEY_CURRENT = 1
    KEY_WRONG = 4
    # The states of a puzzle key still to play: untouched, and the one to press.
    KEY_LEFT = [0, KEY_CURRENT]
    # The grid square, where the plugin's settings leave it out.
    SQUARE = 32

    @scene = nil
    @keys = nil
    @pending = false
    @outcome = nil
    @before = nil
    @marks = {}
    @published = nil
    @opened = nil
    @lives = nil
    @caught = false
    @shown = nil
    @reveal = nil
    @moves_left = nil

    # Holds the game while its loop runs (the block).
    def self.playing(scene)
      @scene = scene
      @marks = {}
      @published = nil
      @opened = nil
      @lives = nil
      @caught = false
      @shown = nil
      @moves_left = nil
      yield
    ensure
      @scene = nil
      @reveal = nil
    end

    # The node the player stands on, or nil.
    def self.node(s)
      at = PokeAccess.ivar(s, :@coords)
      nodes = PokeAccess.ivar(s, :@nodes)
      (at && nodes) ? nodes[[at[0], at[1]]] : nil
    end

    # The circuit's nodes by grid square.
    def self.nodes(s); PokeAccess.ivar(s, :@nodes) || {}; end

    # The path a way runs along from (x,y), kept under its two ends, top or left first; nil where none.
    def self.path(s, x, y, way)
      nx = x + way[2]
      ny = y + way[3]
      (way[2] + way[3]) < 0 ? PokeAccess.ivar(s, :@paths)[[nx, ny, x, y]] : PokeAccess.ivar(s, :@paths)[[x, y, nx, ny]]
    end

    # Whether a way can be walked from (x,y), as pbCanMove asks it of the player's node: the path open, its far node drawn.
    def self.passable?(s, x, y, way)
      p = path(s, x, y, way)
      return false unless p && p.can_pass
      n = nodes(s)[[x + way[2], y + way[3]]]
      n && n.visible ? true : false
    end

    # True while the fog of war covers the board but for a hole around the player.
    def self.fog?(s)
      f = PokeAccess.sprite(s, "fog")
      f && f.visible ? true : false
    end

    # True when a place on the grid shows through the hole in the fog of war, by its distance from the player: 80 pixels
    # on the plugin's fog.png, 48 on its fog_small.png.
    # param across squares to the right
    # param down squares down
    def self.in_hole?(s, across, down)
      square = (PokeAccess.const_at("HackingGameSettings::GRID_SQUARE_SIZE") || SQUARE).to_f
      radius = (PokeAccess.ivar(s, :@game_info) || {})[:fog] == :small ? 48 : 80
      (across * across + down * down) * square * square <= radius * radius
    end

    # What the player's node is: nothing to name on a plain Base Node, else its name and state.
    def self.node_words(n)
      return [] if n.type == :Base
      [PokeAccess.clean(n.get_name.to_s), node_state(n)].compact
    end

    # A node's state as its picture shows it, or nil where it has no state to tell.
    def self.node_state(n)
      return PokeAccess::I18n.t(:hack_disabled) unless n.can_interact?
      return PokeAccess::I18n.t(n.state == 1 ? :hack_locked : :hack_unlocked) if PUZZLE_NODES.include?(n.type)
      return PokeAccess::I18n.t(n.state == 1 ? :hack_charged : :hack_drained) if n.type == :Charge
      nil
    end

    # Why a node stands as it does, which the board shows in its wires and its overlay: the wire out of a Charge Node, the
    # drained ones a node waits on, and what a node held shut still needs.
    def self.node_notes(s, n)
      x, y = PokeAccess.ivar(s, :@coords)
      out = n.charge_target
      words = out ? [PokeAccess::I18n.t(:hack_wire_to, :where => where(out[0] - x, out[1] - y))] : []
      nodes(s).each do |at, o|
        next unless o && o.type == :Charge && o.charge_target == [x, y] && o.state == 0
        words.push(PokeAccess::I18n.t(:hack_wire_from, :where => where(at[0] - x, at[1] - y)))
      end
      need = needs_word(s, n)
      words.push(need) if need
      words
    end

    # What a node switched off by its group still needs, as many of that kind as are left; nil for any other.
    def self.needs_word(s, n)
      info = n.disabled_info
      return nil if info.nil? || n.disabled_unlocked
      left = nodes(s).values.compact.select { |o| o.type == info[:type] && o.state != 0 && (info[:id].nil? || o.id == info[:id]) }
      return nil if left.empty?
      PokeAccess::I18n.t(:hack_needs, :name => PokeAccess.clean(left[0].get_name.to_s), :n => left.length)
    end

    # What lies along a way out of (x,y), as [words, steps to it]: the plain nodes are walked to the first thing a look at
    # the board tells, a node worth naming, an Antivirus, a crossing or a dead end. Under fog only as far as its hole
    # shows, with no words when the next node is out of it; none for a loop of plain nodes either.
    def self.far_end(s, x, y, way)
      stops = virus_cells(s)
      fogged = fog?(s)
      from_x = x
      from_y = y
      steps = 0
      nodes(s).length.times do
        x += way[2]
        y += way[3]
        steps += 1
        return [nil, steps] if x == from_x && y == from_y
        return [PokeAccess::I18n.t(:hack_virus_here), steps] if stops.include?([x, y])
        n = nodes(s)[[x, y]]
        return [node_words(n).join(", "), steps] if n.type != :Base
        on = WAYS.select { |w| !(w[2] == -way[2] && w[3] == -way[3]) && passable?(s, x, y, w) }
        return [PokeAccess::I18n.t(:hack_no_way), steps] if on.empty?
        return [PokeAccess::I18n.t(:hack_cross), steps] if on.length > 1
        way = on[0]
        return [nil, steps] if fogged && !in_hole?(s, x + way[2] - from_x, y + way[3] - from_y)
      end
      [nil, steps]
    end

    # A way out of (x,y) as said: its direction and what lies along it, with the steps to that when more than one.
    def self.way_line(s, x, y, way)
      what, steps = far_end(s, x, y, way)
      dir = PokeAccess::I18n.t(way[1])
      return dir unless what
      PokeAccess::I18n.t(steps > 1 ? :hack_way_far : :hack_way, :dir => dir, :what => what, :n => steps)
    end

    # The ways the player can take, and each path that is drawn but leads to a node that is not, by the name the plugin
    # gives it. A locked path is not drawn at all, so it goes unsaid.
    def self.way_words(s)
      x, y = PokeAccess.ivar(s, :@coords)
      open = WAYS.select { |w| passable?(s, x, y, w) }
      shut = WAYS.select do |w|
        p = path(s, x, y, w)
        p && p.visible && !open.include?(w)
      end
      words = open.empty? ? [PokeAccess::I18n.t(:hack_no_way)] : open.map { |w| way_line(s, x, y, w) }
      words + shut.map do |w|
        name = PokeAccess.clean(path(s, x, y, w).get_name.to_s)
        PokeAccess::I18n.t(:hack_closed, :dir => PokeAccess::I18n.t(w[1]), :name => name)
      end
    end

    # The player's node with its wires, its ways out and each Antivirus on the hunt, as one line.
    def self.node_line(s)
      n = node(s)
      return nil unless n
      hunting = viruses(s).select { |a| a.active }
      PokeAccess.sentences(node_words(n) + node_notes(s, n) + way_words(s) + hunting.map { |a| virus_word(s, a, :hack_virus) })
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The Antivirus still on the board: one that took a charge stays hidden until a restart.
    def self.viruses(s)
      (PokeAccess.ivar(s, :@antivirus) || {}).values.compact.select { |a| a.visible }
    end

    # How far a sprite stands from the player's on the grid, as [across, down].
    def self.offset(s, sprite)
      square = (PokeAccess.const_at("HackingGameSettings::GRID_SQUARE_SIZE") || SQUARE).to_f
      p = PokeAccess.sprite(s, "player")
      [((sprite.x - p.x) / square).round, ((sprite.y - p.y) / square).round]
    end

    # The grid squares the Antivirus on the board stand on.
    def self.virus_cells(s)
      x, y = PokeAccess.ivar(s, :@coords)
      viruses(s).map do |a|
        across, down = offset(s, a)
        [x + across, y + down]
      end
    end

    # An Antivirus with where it stands from the player, in the words of the key given.
    def self.virus_word(s, sprite, key)
      across, down = offset(s, sprite)
      PokeAccess::I18n.t(key, :where => where(across, down))
    end

    # How far a place on the grid lies from the player, in the mod's words for directions.
    # param across squares to the right
    # param down squares down
    def self.where(across, down)
      parts = []
      parts.push([across > 0 ? :dir_right : :dir_left, across.abs]) if across != 0
      parts.push([down > 0 ? :dir_down : :dir_up, down.abs]) if down != 0
      parts.map { |dir, n| PokeAccess::I18n.t(:tilt_leg, :dir => PokeAccess::I18n.t(dir), :n => n) }.join(", ")
    end

    # Where the Finish Node lies and what it still needs, or nil where the circuit has none, hides it or the player stands
    # on it. Told under fog too, unlike the rest of the board: the clock runs while the player walks a hidden board by ear.
    def self.goal_line(s)
      at = PokeAccess.ivar(s, :@coords)
      pair = (PokeAccess.ivar(s, :@nodes) || {}).find { |_k, n| n && n.type == :Finish && n.visible }
      return nil unless at && pair
      text = where(pair[0][0] - at[0], pair[0][1] - at[1])
      return nil if text.empty?
      goal = PokeAccess::I18n.t(:tilt_goal, :where => text)
      need = needs_word(s, pair[1])
      need ? "#{goal}, #{need}" : goal
    end

    # The seconds left on the timer, or nil without one; Essentials 20 counts frames, 21 the play time.
    def self.seconds(s)
      t = PokeAccess.ivar(s, :@timer)
      return nil unless t.is_a?(Numeric)
      return (t / Graphics.frame_rate).to_i if PokeAccess.ivar(s, :@timer_inc_per_frame)
      left = t - $stats.play_time + PokeAccess.ivar(s, :@timer_start).to_f
      left < 0 ? 0 : left.to_i
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The timer, the moves and the lives left, those the circuit has; the moves as the bottom of the screen writes them.
    def self.limits(s)
      parts = []
      secs = seconds(s)
      parts.push(PokeAccess::I18n.t(:hack_time, :n => secs, :secs => PokeAccess::I18n.t(:secs, :n => secs))) if secs
      limit = PokeAccess.ivar(s, :@move_limit)
      parts.push(_INTL("Moves Remaining: {1}", limit - PokeAccess.ivar(s, :@move_count).to_i)) if limit
      lives = PokeAccess.ivar(s, :@lives)
      parts.push(PokeAccess::I18n.t(:hack_lives, :n => lives)) if lives.is_a?(Integer) && lives > 0
      parts
    end

    # The circuit as it opens: its limits, the goal, the keys while hints are said, then the first node; on a restart,
    # the catch if no frame has told it yet, and that it started over in the keys' place.
    def self.opening(s)
      restart = @opened.equal?(s)
      @opened = s
      watch_lives(s)
      @caught = false
      parts = limits(s) + [goal_line(s)]
      if restart
        parts.unshift(PokeAccess::I18n.t(:hack_restart))
      elsif PokeAccess::Verbosity.hints?
        key = PokeAccess::KeyHints.key(:b, PokeAccess::I18n.t(:key_escape))
        parts.push(PokeAccess::I18n.t(:hack_hint, :key => key))
      end
      parts.push(node_line(s))
      PokeAccess.speak(PokeAccess.sentences(parts.compact), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A puzzle opening: the keys its sprites are made with are noted, and said on its first frame.
    def self.puzzle
      @keys = []
      @pending = true
      r = yield
      @outcome = r ? :solved : :failed
      r
    ensure
      @keys = nil
      @pending = false
    end

    def self.key_made(key)
      @keys.push(key) if @keys
    end

    # What a puzzle key asks for: its way, or that it is hidden until guessed.
    def self.key_word(key)
      return PokeAccess::I18n.t(:hack_key_hidden) if key.hidden
      PokeAccess::I18n.t(KEY_WORDS[key.dir] || :hack_key_hidden)
    end

    # The keys of the open puzzle still to play, for the info key.
    def self.keys_left
      left = (@keys || []).select { |k| KEY_LEFT.include?(k.state) }
      left.empty? ? [] : [PokeAccess::I18n.t(:hack_seq, :list => left.map { |k| key_word(k) }.join(", "))]
    end

    # True while a puzzle's keys or a Key Node's panel are being said, which a warning goes behind rather than cut.
    def self.reading_keys?
      !@keys.nil? || !@reveal.nil?
    end

    # A key's state changing as the puzzle is played: the next key to press, or that this one was wrong.
    def self.key_state(key, state)
      return unless @keys
      PokeAccess.speak(key_word(key), true) if state == KEY_CURRENT
      PokeAccess.speak(PokeAccess::I18n.t(:hack_key_wrong), true) if state == KEY_WRONG
    end

    # A node about to run: notes what it holds, to tell after whether running it changed anything.
    def self.before_run(s, n)
      @outcome = nil
      @before = [(n.state rescue nil), charged?(s)]
    end

    def self.charged?(s)
      p = PokeAccess.sprite(s, "player")
      (p.charged rescue false) ? true : false
    end

    # A node run: a Key Node's panel closing brings the node back; a Charge Node that changed cuts its own arrival, which
    # it has just made stale, with what the player holds, what its wire does and the ways out; any other that changed or
    # ran a puzzle says how that ended and the node again as it now stands.
    def self.after_run(s, n)
      @published = nil
      return panel_closed(s) if @reveal
      return unless @outcome || @before != [(n.state rescue nil), charged?(s)]
      return charge_moved(s, n) if n.type == :Charge
      ended = @outcome ? [PokeAccess::I18n.t(@outcome == :solved ? :hack_solved : :hack_failed)] : []
      PokeAccess.speak(PokeAccess.sentences(ended + [node_line(s)]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A Key Node's panel shut, the clock running all the while: the node and its ways out again.
    def self.panel_closed(s)
      @reveal = nil
      line = node_line(s)
      PokeAccess.speak(line, true) if line
    end

    # A Charge Node that took or gave the charge.
    def self.charge_moved(s, n)
      parts = [PokeAccess::I18n.t(charged?(s) ? :hack_player_charged : :hack_player_empty), wire_word(s, n)]
      PokeAccess.speak(PokeAccess.sentences(parts + way_words(s)), true)
    end

    # What a Charge Node's wire now does to the node at its far end, or nil with no wire.
    def self.wire_word(s, n)
      target = n.charge_target ? nodes(s)[n.charge_target] : nil
      return nil unless target
      PokeAccess::I18n.t(n.state == 1 ? :hack_wire_on : :hack_wire_off, :name => node_words(target).join(", "))
    end

    # The keys a Key Node reveals of its Locked Node's hidden puzzle, each at its place in the sequence, with what closes
    # the panel, as nothing else does and the clock runs meanwhile. Kept for the info key until it closes; the game opens
    # no panel for a puzzle with no hidden keys.
    def self.revealed(s, n)
      linked = (n.get_data[:linked_type] rescue nil)
      pair = nodes(s).find { |_k, o| o && o.type == linked && o.id == n.id }
      parent = pair ? pair[1] : nil
      return unless parent && parent.puzzle_hidden && parent.puzzle.is_a?(Array)
      rows = []
      (n.keys_to_reveal || []).each_with_index do |shown, i|
        next unless shown && parent.puzzle[i]
        rows.push(PokeAccess::I18n.t(:hack_reveal, :n => i + 1, :dir => PokeAccess::I18n.t(KEY_WORDS[parent.puzzle[i]])))
      end
      return if rows.empty?
      @reveal = PokeAccess.sentences(node_words(n) + [_INTL("Read-Only"), rows.join(", ")])
      close = PokeAccess::Verbosity.hints? ? close_hint : nil
      PokeAccess.speak(PokeAccess.sentences([@reveal, close]), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The two keys that close a Key Node's panel.
    def self.close_hint
      ok = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
      back = PokeAccess::KeyHints.key(:b, PokeAccess::I18n.t(:key_escape))
      PokeAccess::I18n.t(:hack_reveal_close, :ok => ok, :back => back)
    end

    # The Antivirus that has just seen the player, with where it stands; behind a puzzle's keys, not over them.
    def self.alert(sprite)
      s = @scene
      return unless s
      PokeAccess.speak(virus_word(s, sprite, :hack_alert), !reading_keys?)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # An Antivirus losing sight of the player; a restart deactivates them all, which it leaves unsaid.
    def self.alert_off(sprite)
      return unless @scene && (sprite.active rescue false)
      PokeAccess.speak(PokeAccess::I18n.t(:hack_alert_off), false) unless @caught || life_lost?(@scene)
    end

    # True when the lives have dropped since they were last looked at: an Antivirus caught the player.
    def self.life_lost?(s)
      lives = PokeAccess.ivar(s, :@lives)
      lives.is_a?(Integer) && @lives.is_a?(Integer) && lives < @lives
    end

    # Said once when a catch costs a life and the circuit starts over; the last life goes with the game's own message.
    def self.watch_lives(s)
      if life_lost?(s) && PokeAccess.ivar(s, :@lives) > 0
        @caught = true
        PokeAccess.speak(PokeAccess::I18n.t(:hack_caught), true)
      end
      @lives = PokeAccess.ivar(s, :@lives)
    end

    # An Antivirus hidden while the circuit goes on: it touched the charged player, took the charge and left, with no call
    # to tell it by. The circuit's end empties the list instead.
    def self.watch_viruses(s)
      left = (PokeAccess.ivar(s, :@antivirus) || {}).values
      gone = @shown && @shown.any? { |a| left.include?(a) && !a.visible }
      @shown = viruses(s)
      PokeAccess.speak(PokeAccess::I18n.t(:hack_virus_gone), !reading_keys?) if gone
    end

    # Said queued as the moves left fall to half, a quarter, ten and five; the bottom of the screen writes them at every
    # step, which would cost each step its time.
    def self.watch_moves(s)
      limit = PokeAccess.ivar(s, :@move_limit)
      return unless limit
      left = limit - PokeAccess.ivar(s, :@move_count).to_i
      fresh = @moves_left && left != @moves_left
      @moves_left = left
      PokeAccess.speak(_INTL("Moves Remaining: {1}", left), false) if fresh && [limit / 2, limit / 4, 10, 5].include?(left)
    end

    # Each frame: a puzzle's keys once its sprites are made, cutting the node's line, whose ways out are said again after
    # it; what an Antivirus took, the moves and the timer's marks, and the info key's line.
    def self.poll
      s = @scene
      return unless s
      if @pending && @keys && !@keys.empty?
        @pending = false
        PokeAccess.speak(PokeAccess::I18n.t(:hack_seq, :list => @keys.map { |k| key_word(k) }.join(", ")), true)
      end
      watch_lives(s)
      watch_viruses(s)
      watch_moves(s)
      timer_mark(s, :@timer_half_passed, :hack_time_half)
      timer_mark(s, :@timer_fourth_passed, :hack_time_quarter)
      publish(s)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says a timer mark the first frame the scene's flag for it is up.
    def self.timer_mark(s, ivar, key)
      return if @marks[ivar] || !PokeAccess.ivar(s, ivar)
      @marks[ivar] = true
      PokeAccess.speak(PokeAccess::I18n.t(key), false)
    end

    # What the player holds, where the circuit has Charge Nodes to take it from.
    def self.charge_words(s)
      return [] unless nodes(s).values.compact.any? { |n| n.type == :Charge }
      [PokeAccess::I18n.t(charged?(s) ? :hack_player_charged : :hack_player_empty)]
    end

    # Every other node worth naming with where it lies, nearest first: what a look at the board tells, under fog what
    # shows through its hole.
    def self.board_words(s)
      x, y = PokeAccess.ivar(s, :@coords)
      fogged = fog?(s)
      named = nodes(s).to_a.select do |at, n|
        n && n.type != :Base && n.visible && at != [x, y] && (!fogged || in_hole?(s, at[0] - x, at[1] - y))
      end
      named.sort_by { |at, _n| (at[0] - x).abs + (at[1] - y).abs }.map do |at, n|
        PokeAccess::I18n.t(:hack_on_board, :what => node_words(n).join(", "), :where => where(at[0] - x, at[1] - y))
      end
    end

    # Every Antivirus on the board, those on the hunt by the alert's words; under fog too, as the goal.
    def self.virus_words(s)
      viruses(s).map { |a| virus_word(s, a, a.active ? :hack_alert : :hack_virus) }
    end

    # Keeps the info key's line current, once a second, on each move and as the charge, an Antivirus or a puzzle's keys
    # change: a Key Node's panel or the keys left, node, wires, ways, charge, every Antivirus, limits and goal; the row key
    # adds the board.
    def self.publish(s)
      n = node(s)
      words = virus_words(s)
      keys = keys_left
      state = [PokeAccess.ivar(s, :@coords), seconds(s), PokeAccess.ivar(s, :@move_count), charged?(s), words, keys, @reveal]
      return if state == @published
      @published = state.map { |v| v.is_a?(Array) ? v.dup : v }
      place = n ? node_words(n) + node_notes(s, n) + way_words(s) : []
      line = PokeAccess.sentences([@reveal] + keys + place + charge_words(s) + words + limits(s) + [goal_line(s)])
      PokeAccess::Info.set_info(:text, line, PokeAccess.sentences([line] + board_words(s)))
    end
  end
end

PokeAccess::Hooks.around_hook("HackingGame_Scene", :pbScenePlay, :optional => true) do |scene, nxt, _a|
  PokeAccess::HackingMinigame.playing(scene) { nxt.call }
end
# The circuit's first node, and again on a restart; hook_container, as it only reads.
PokeAccess::Hooks.after_hook("HackingGame_Scene", :update_cursor, :optional => true, :hook_container => true) do |s, _r, a|
  PokeAccess::HackingMinigame.opening(s) if a[0]
end
# A step ends here, before the node's puzzle opens by itself; the action key on a node lands here too.
PokeAccess::Hooks.before_hook("HackingGame_Scene", :pbPlayCurrentNode, :optional => true) do |s, _a|
  line = PokeAccess::HackingMinigame.node_line(s)
  PokeAccess.speak(line, true) if line
end
PokeAccess::Hooks.around_hook("HackingGame_Scene", :pbPlayPuzzle, :optional => true) do |_s, nxt, _a|
  PokeAccess::HackingMinigame.puzzle { nxt.call }
end
PokeAccess::Hooks.before_hook("HackingGame_Scene", :pbRunNode, :optional => true) do |s, a|
  PokeAccess::HackingMinigame.before_run(s, a[0])
end
PokeAccess::Hooks.after_hook("HackingGame_Scene", :pbRunNode, :optional => true, :hook_container => true) do |s, _r, a|
  PokeAccess::HackingMinigame.after_run(s, a[0])
end
PokeAccess::Hooks.before_hook("HackingGame_Scene", :pbRevealKeys, :optional => true) do |s, a|
  PokeAccess::HackingMinigame.revealed(s, a[0])
end
# Before, because the original is the question's modal loop.
PokeAccess::Hooks.before_hook("HackingGame_Scene", :pbShowCommandsCustom, :optional => true) do |_s, a|
  PokeAccess.say_dialogue(a[0])
end
PokeAccess::Hooks.after_hook("HackingGame_Scene::HackingKey", :initialize, :optional => true) do |key, _r, _a|
  PokeAccess::HackingMinigame.key_made(key)
end
PokeAccess::Hooks.after_hook("HackingGame_Scene::HackingKey", :state=, :optional => true) do |key, _r, a|
  PokeAccess::HackingMinigame.key_state(key, a[0])
end
PokeAccess::Hooks.after_hook("HackingGame_Scene::HackingAntivirus", :activate, :optional => true) do |sprite, _r, _a|
  PokeAccess::HackingMinigame.alert(sprite)
end
PokeAccess::Hooks.before_hook("HackingGame_Scene::HackingAntivirus", :deactivate, :optional => true) do |sprite, _a|
  PokeAccess::HackingMinigame.alert_off(sprite)
end
PokeAccess::Frame.each_pulse { PokeAccess::HackingMinigame.poll }
PokeAccess::Hooks.clear_info_on("HackingGame_Scene", :pbEndScene)
