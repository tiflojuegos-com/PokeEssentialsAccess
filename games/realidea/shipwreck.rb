# The sunken ship's puzzles (Barco Hundido): the telegraph (Morse) and the wheel (Timon), each a blocking loop held
# by an around-hook and read by the per-frame poller; the sea chart's route, said when the wheel's map opens or the
# chart is examined in the bag; and the Chinchou puzzle on map 278, whose three fish the arrow keys move.
module PokeAccess
  module RealideaShipwreck
    @active = nil
    @kind = nil
    @fish_last = nil
    @fish_pos = nil
    @fish_still = 0
    @fish_drift = {}
    @fish_pushed = nil

    def self.hold(scene, kind); @active = scene; @kind = kind; end
    def self.release; @active = nil; @kind = nil; end

    def self.poll
      fish_poll
      return unless @active
      @kind == :morse ? morse(@active) : timon(@active)
    rescue StandardError
      nil
    end

    # The telegraph's alphabet as its guide (GUIA2) paints it: "." a dot, "-" a dash.
    MORSE = [["A", ".-"], ["B", "-..."], ["C", "-.-."], ["D", "-.."], ["E", "."], ["F", "..-."], ["G", "--."],
             ["H", "...."], ["I", ".."], ["J", ".---"], ["K", "-.-"], ["L", ".-.."], ["M", "--"], ["N", "-."],
             ["O", "---"], ["P", ".--."], ["Q", "--.-"], ["R", ".-."], ["S", "..."], ["T", "-"], ["U", "..-"],
             ["V", "...-"], ["W", ".--"], ["X", "-..-"], ["Y", "-.--"], ["Z", "--.."]]
    # Symbols per painted row; V jumps to the next one.
    MORSE_ROW = 4

    # Telegraph: the painted keys as it opens, each symbol entered with the row and place it is painted in (@numero,
    # which V moves on a row), the symbols cleared, and the guide's alphabet while M shows it.
    def self.morse(scene)
      morse_symbols(scene)
      morse_keys(scene)
      morse_guide(scene)
    rescue StandardError
      nil
    end

    # Once, queued: the keys the panel paints (and M for the guide once it is owned); with the puzzle assist, how
    # many symbols the answer has.
    def self.morse_keys(scene)
      return unless PokeAccess::Cursor.changed?(scene, :rea_morse_keys, true)
      parts = []
      if PokeAccess::Verbosity.hints?
        parts.push(PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:rea_morse_keys)))
        guide = PokeAccess.sprite(scene, "help1")
        parts.push(PokeAccess::I18n.t(:rea_morse_guide_key)) if guide && (guide.visible rescue false)
      end
      target = PokeAccess.ivar(scene, :@secuenciacorrecta)
      if PokeAccess::Puzzles.assist? && target.is_a?(Array)
        parts.push(PokeAccess::I18n.t(:rea_morse_goal, :n => target.length))
      end
      line = PokeAccess.sentences(parts)
      PokeAccess.speak(line, false) unless line.empty?
    end

    # A symbol entered: dot or dash with where it is painted ("raya, fila 1, 2"), or with the assist its place in
    # the answer; the row cleared when the symbols go.
    def self.morse_symbols(scene)
      seq = PokeAccess.ivar(scene, :@secuencia)
      return unless seq.is_a?(Array)
      prev = PokeAccess.ivar(scene, :@pa_morse_len)
      scene.instance_variable_set(:@pa_morse_len, seq.length)
      return if prev.nil? || prev == seq.length
      if seq.length < prev
        PokeAccess.speak(PokeAccess::I18n.t(:rea_morse_clear), true) if seq.empty?
        return
      end
      PokeAccess.speak(symbol_line(scene, seq), true)
    end

    # The last symbol's line: its place in the painted rows, or with the assist in the answer.
    def self.symbol_line(scene, seq)
      sym = PokeAccess::I18n.t(seq.last.to_s == "raya" ? :rea_dash : :rea_dot)
      target = PokeAccess.ivar(scene, :@secuenciacorrecta)
      if PokeAccess::Puzzles.assist? && target.is_a?(Array)
        return PokeAccess::I18n.t(:rea_morse, :sym => sym, :n => seq.length, :tot => target.length)
      end
      n = PokeAccess.ivar_i(scene, :@numero, seq.length)
      n = 1 if n < 1
      PokeAccess::I18n.t(:rea_morse_slot, :sym => sym, :row => (n - 1) / MORSE_ROW + 1, :col => (n - 1) % MORSE_ROW + 1)
    end

    # The guide's alphabet as M shows it, and its key to close it.
    def self.morse_guide(scene)
      help = PokeAccess.sprite(scene, "help")
      shown = help ? ((help.visible rescue false) ? true : false) : false
      return unless PokeAccess::Cursor.changed?(scene, :rea_morse_guide, shown) && shown
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(guide_text, PokeAccess::I18n.t(:rea_morse_guide_close)), true)
    end

    # "A: punto raya. B: raya punto punto punto..." for the whole table.
    def self.guide_text
      dot = PokeAccess::I18n.t(:rea_dot)
      dash = PokeAccess::I18n.t(:rea_dash)
      MORSE.map { |letter, code| "#{letter}: #{code.split('').map { |c| c == '.' ? dot : dash }.join(' ')}" }.join(". ")
    end

    # The chart's red line from Esoteria to Kanto, as the compass points the wheel names.
    ROUTE = %w[O NO NE E S E]
    # The wheel's compass points, the game's own abbreviations, and the direction each stands for.
    POINTS = { "N" => :dir_n, "NE" => :dir_ne, "E" => :dir_e, "SE" => :dir_se, "S" => :dir_s, "SO" => :dir_so,
               "O" => :dir_o, "NO" => :dir_no }

    # A compass point of the wheel ("NO", or "[NO]" as an entry) as its direction word.
    def self.point_word(abbr)
      a = PokeAccess.clean(abbr.to_s).delete("[]").strip
      key = POINTS[a]
      key ? PokeAccess::I18n.t(key) : a
    end

    # The chart as it is painted: the red line from Esoteria to Kanto, leg by leg.
    def self.route_text
      PokeAccess::I18n.t(:rea_chart_route, :list => ROUTE.map { |p| point_word(p) }.join(", "))
    end

    # Ship's wheel: the heading, the headings entered, the keys the wheel paints as it opens, and the chart while F
    # shows it.
    def self.timon(scene)
      heading(scene)
      timon_entries(scene)
      timon_keys(scene)
      timon_chart(scene)
    rescue StandardError
      nil
    end

    # The wheel's live heading: the first of @posiciones, the game's compass points, which left and right rotate.
    def self.heading(scene)
      pos = PokeAccess.ivar(scene, :@posiciones)
      return unless pos.is_a?(Array) && pos[0]
      dir = PokeAccess.clean(pos[0].to_s)
      return if dir.empty?
      PokeAccess::Cursor.announce(scene, :rea_timon_dir, dir, true) { point_word(dir) }
    end

    # True while the compass (BOL2) is owned: the wheel then paints its log and takes headings.
    def self.compass?(scene)
      extra = PokeAccess.sprite(scene, "extra")
      extra ? ((extra.visible rescue false) ? true : false) : false
    end

    # The headings entered: each one with its place in the log, the log emptied as it resets; with the puzzle
    # assist, out of the answer's length.
    def self.timon_entries(scene)
      return unless compass?(scene)
      got = PokeAccess.ivar(scene, :@combinaciontimon)
      return unless got.is_a?(Array)
      target = PokeAccess.ivar(scene, :@combinacion)
      PokeAccess::Cursor.announce(scene, :rea_timon, got.length, false) do
        if got.empty?
          PokeAccess::I18n.t(:rea_timon_empty)
        elsif PokeAccess::Puzzles.assist? && target.is_a?(Array)
          PokeAccess::I18n.t(:rea_timon, :dir => point_word(got.last), :n => got.length, :tot => target.length)
        else
          PokeAccess::I18n.t(:rea_timon_entry, :dir => point_word(got.last), :n => got.length)
        end
      end
    end

    # Once, queued: the keys the wheel paints, C to enter a heading with the compass and F for the chart with it.
    def self.timon_keys(scene)
      return unless PokeAccess::Cursor.changed?(scene, :rea_timon_keys, true) && PokeAccess::Verbosity.hints?
      parts = []
      parts.push(PokeAccess::I18n.t(:rea_timon_key_enter)) if compass?(scene)
      chart = PokeAccess.sprite(scene, "extra1")
      parts.push(PokeAccess::I18n.t(:rea_timon_key_chart)) if chart && (chart.visible rescue false)
      line = PokeAccess::KeyHints.localize(PokeAccess.sentences(parts))
      PokeAccess.speak(line, false) unless line.to_s.empty?
    end

    # The chart's route when F opens it over the wheel, with the key the chart paints to close it.
    def self.timon_chart(scene)
      chart = PokeAccess.sprite(scene, "mapa")
      shown = chart ? ((chart.visible rescue false) ? true : false) : false
      return unless PokeAccess::Cursor.changed?(scene, :rea_timon_chart, shown) && shown
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(route_text, PokeAccess::I18n.t(:rea_chart_back)), true)
    end

    # Examining the sea chart in the bag (examinarobj with MAPAMAR): its route, said under the empty box that
    # shows the chart.
    def self.examined(item)
      id = PokeAccess.const_at("PBItems::MAPAMAR")
      PokeAccess.speak(route_text, true) if id && item == id
    rescue StandardError
      nil
    end

    # The Chinchou puzzle: its map, the switch that runs it and the three fish the arrows move (the Chinchou, then
    # the two Carvanha).
    FISH_MAP = 278
    FISH_SWITCH = 366
    FISH = [3, 4, 5]
    # The top-left tile of the grid the puzzle's picture (Flechasminijuego) paints; rows and columns count from 1.
    GRID_ORIGIN = [13, 6]
    # The green circle the Chinchou has to reach.
    GOAL = [16, 11]
    # The terrain tags of the currents the picture's arrows mark.
    CURRENT_TAGS = [38, 39, 40]
    # Frames the fish must stand still, currents done, before their places are said.
    FISH_SETTLE = 6

    # True while the puzzle runs.
    def self.fish_active?
      (($game_map.map_id rescue 0) == FISH_MAP && ($game_switches[FISH_SWITCH] rescue false)) ? true : false
    end

    # The three fish events (nil for one the map lacks).
    def self.fish_events
      FISH.map { |id| ($game_map.events[id] rescue nil) }
    end

    # A fish as it is said: its species by its sprite, its row and column on the painted grid, and whether a current
    # carried it since the last time.
    def self.fish_line(ev, drifted)
      name = (PokeAccess::Locator.sprite_species(ev.character_name.to_s) rescue nil)
      name = ev.name.to_s if name.nil? || name.to_s.empty?
      vars = { :name => name, :row => ev.y - GRID_ORIGIN[1] + 1, :col => ev.x - GRID_ORIGIN[0] + 1 }
      PokeAccess::I18n.t(drifted ? :rea_fish_drift : :rea_fish_at, vars)
    end

    # Where the three fish are, in order.
    # param drift { event id => the current tile it was first seen on } since the last line
    def self.fish_status(drift = {})
      PokeAccess.sentences(fish_events.compact.map { |ev| fish_line(ev, drift[ev.id] && drift[ev.id] != [ev.x, ev.y]) })
    end

    # The puzzle's line for its start and the info key: what the arrows move, the painted grid, and the fish.
    def self.fish_title
      exit_key = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:rea_fish_exit))
      intro = PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:rea_fish_intro), exit_key)
      PokeAccess.sentences([intro, PokeAccess::I18n.t(:rea_fish_board), fish_status])
    end

    # The puzzle as the locator and the info key know it: one stage, live while switch 366 runs it, whose green
    # circle the locator lists only then.
    def self.fish_puzzle
      { :kind => :stages,
        :stages => [{ :when => lambda { fish_active? }, :title => lambda { fish_title },
                      :spots => [{ :at => GOAL, :label => :rea_fish_circle }] }] }
    end

    # An arrow the puzzle took (gambaizda, gambadcha, gambabajo or gambarriba): the fish are awaited afresh.
    def self.fish_push
      @fish_pushed = true
      @fish_still = 0
    end

    # Each frame of the puzzle: notes a fish on a current, and once the three have stood still for FISH_SETTLE frames
    # says where they are if they moved, or that none did after an arrow.
    def self.fish_poll
      unless fish_active?
        fish_reset
        return
      end
      evs = fish_events.compact
      evs.each do |ev|
        tag = ($game_map.terrain_tag(ev.x, ev.y) rescue 0)
        @fish_drift[ev.id] ||= [ev.x, ev.y] if CURRENT_TAGS.include?(tag)
      end
      pos = evs.map { |ev| [ev.x, ev.y] }
      if @fish_last.nil?
        @fish_last = pos
        @fish_pos = pos
        @fish_drift = {}
        return
      end
      if pos != @fish_pos || evs.any? { |ev| (ev.moving? rescue false) }
        @fish_pos = pos
        @fish_still = 0
        return
      end
      @fish_still += 1
      return if @fish_still < FISH_SETTLE
      pushed = @fish_pushed
      @fish_pushed = nil
      if pos == @fish_last
        PokeAccess.speak(PokeAccess::I18n.t(:rea_fish_stuck), true) if pushed
        return
      end
      @fish_last = pos
      PokeAccess.speak(fish_status(@fish_drift), true)
      @fish_drift = {}
    end

    # Forgets the puzzle's frame state (it is off, or the map changed).
    def self.fish_reset
      @fish_last = nil
      @fish_pos = nil
      @fish_still = 0
      @fish_drift = {}
      @fish_pushed = nil
    end
  end
end

PokeAccess::Caches.register(:realidea_shipwreck) { PokeAccess::RealideaShipwreck.fish_reset }

PokeAccess::Game.define("realidea") do
  [["Morse", :actu, :morse], ["Timon", :actu, :timon]].each do |cname, meth, kind|
    around(cname, meth) do |scene, nxt, _a|
      PokeAccess::RealideaShipwreck.hold(scene, kind)
      begin
        nxt.call
      ensure
        PokeAccess::RealideaShipwreck.release
      end
    end
  end
  poll_each_frame { PokeAccess::RealideaShipwreck.poll }
  kernel("examinarobj", :before) { |a, _r| PokeAccess::RealideaShipwreck.examined(a[0]) }
  %w[gambaizda gambadcha gambabajo gambarriba].each do |f|
    kernel(f, :before) { |_a, _r| PokeAccess::RealideaShipwreck.fish_push }
  end
  puzzle(PokeAccess::RealideaShipwreck::FISH_MAP, PokeAccess::RealideaShipwreck.fish_puzzle)
end
