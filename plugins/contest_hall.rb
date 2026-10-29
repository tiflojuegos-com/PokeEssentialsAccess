module PokeAccess
  # bo4p5687's Pokemon Contests Script (ContestHall::Show, moves from SetContestMoves): the judge's narration through
  # the plugin's own message box, the move menu's data, the round, the running order, the hearts, the applause, the
  # audience's votes, the oblivious marks and the results' bars, which the stage shows only as pictures and bars.
  module ContestShow
    ROUNDS = 5
    APPLAUSE_MAX = 5
    # The contest categories the move list's icons show, by the name the move data gives each.
    CATEGORIES = { "Cool" => :cnd_cool, "Beauty" => :cnd_beauty, "Cute" => :cnd_cute, "Smart" => :cnd_smart,
                   "Tough" => :cnd_tough }
    # The oblivious marks of the four places in the running order, top to bottom.
    OBLIVIOUS = %w[obliviousone oblivioustwo obliviousthree obliviousfour]
    # A results bar starts this far left of the screen and grows to BAR_FULL for the best score.
    BAR_START = -93
    BAR_FULL = 260.0
    @crowd = nil
    @results = nil
    @paints = 0

    # A line of the judge's or the audience's, shown in the plugin's own message box: said as dialogue, its codes
    # (the box's line count, the colours) cleaned away.
    def self.message(text)
      PokeAccess.say_dialogue(text) if text.is_a?(String) && !text.empty?
    end

    # The four contestants as the stage keeps them, the player's first.
    def self.entrants(scene)
      [PokeAccess.ivar(scene, :@pkmn1), PokeAccess.ivar(scene, :@pkmn2), PokeAccess.ivar(scene, :@pkmn3),
       PokeAccess.ivar(scene, :@pkmn4)]
    end

    # A contestant's name as the stage paints it.
    def self.name_of(pkmn)
      PokeAccess.clean(pkmn.name.to_s)
    end

    # The contest data of a move, as the menu reads it: {field => value}, or nil for a move the data lacks.
    def self.data_of(move_id)
      data = ::SetContestMoves.r_move
      i = data[:id].index(move_id)
      return nil unless i
      out = {}
      [:name, :type, :heart, :jam, :description].each { |f| out[f] = data[f][i] }
      out
    end

    # The focused move as the menu shows it: name and place, the grey of the move used last, then the category icon,
    # the appeal and jamming heart pictures and the description, at the battle move reading's level; the info key keeps
    # it whole, followed by the round's standing.
    def self.choice_line(scene, pk, idx)
      d = data_of(pk.moves[idx].id) || {}
      name = (d[:name] || pk.moves[idx].name).to_s
      parts = [[PokeAccess::Verbosity.list_entry(name, idx + 1, pk.numMoves), :brief]]
      last = PokeAccess.ivar(scene, :@pkmn1lastmove)
      parts.push([PokeAccess::I18n.t(:if2_ct_repeat), :brief]) if last && last == name
      cat = CATEGORIES[d[:type].to_s.strip]
      parts.push([PokeAccess::I18n.t(:if2_ct_category, :t => PokeAccess::I18n.t(cat)), :medium]) if cat
      parts.push([PokeAccess::I18n.t(:if2_ct_appeal, :n => d[:heart].to_i), :full]) if d[:heart]
      parts.push([PokeAccess::I18n.t(:if2_ct_jam, :n => d[:jam].to_i), :full]) if d[:jam]
      parts.push([PokeAccess.clean(d[:description].to_s), :full]) if d[:description]
      whole = PokeAccess::Verbosity.full_line(parts, ". ")
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([whole, standing(scene)]), whole)
      PokeAccess::Verbosity.line(:battle_move, parts, ". ")
    end

    # Speaks the menu's focused move once per change; the first of a round is queued.
    def self.choice(scene)
      pk = PokeAccess.ivar(scene, :@pkmn1)
      idx = PokeAccess.ivar(scene, :@selection)
      return unless pk && idx.is_a?(Integer)
      PokeAccess::Cursor.announce(scene, :chall_move, idx, true, false) { choice_line(scene, pk, idx) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The menu as each round opens it: the round its banner showed, the prompt it paints, then the focused move.
    def self.opening(scene)
      round = round_text(scene)
      PokeAccess.speak(round, false) if round
      PokeAccess.speak(PokeAccess.clean(_INTL("Please select a move.")), false)
      PokeAccess::Cursor.reset(scene, :chall_move)
      choice(scene)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The round the banner shows, of the five a contest runs; nil past them.
    def self.round_text(scene)
      n = PokeAccess.ivar(scene, :@round)
      return nil unless n.is_a?(Integer) && n >= 1 && n <= ROUNDS
      PokeAccess::I18n.t(:sv_ct_round, :n => n, :tot => ROUNDS)
    end

    # The side panel's running order, top to bottom, and the player's place in it; nil while it lists nobody.
    def self.order_line(scene)
      order = PokeAccess.ivar(scene, :@pokeorder)
      return nil unless order.is_a?(Array) && !order.empty?
      own = PokeAccess.ivar(scene, :@pkmn1)
      place = order.index { |p| p.equal?(own) }
      parts = [PokeAccess::I18n.t(:if2_ct_order, :list => order.map { |p| name_of(p) }.join(", "))]
      parts.push(PokeAccess::I18n.t(:sv_ct_place, :n => place + 1)) if place
      PokeAccess.sentences(parts)
    end

    # The round's standing while the menu is open: its number, the running order and the player's place.
    def self.standing(scene)
      PokeAccess.sentences([round_text(scene), order_line(scene)])
    end

    # Says the running order when a repaint changes it, while a round is still to come.
    def self.order(scene)
      line = round_text(scene) ? order_line(scene) : nil
      PokeAccess::Cursor.announce(scene, :chall_order, line, false) { line } if line
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The hearts a contestant holds this round, as its row's heart picture shows them; nil for one not competing.
    def self.hearts(scene, pkmn)
      i = entrants(scene).index { |p| p && p.equal?(pkmn) }
      return nil unless i
      [PokeAccess.ivar(scene, :@pkmn1hearts), PokeAccess.ivar(scene, :@pkmn2hearts),
       PokeAccess.ivar(scene, :@pkmn3hearts), PokeAccess.ivar(scene, :@pkmn4hearts)][i]
    end

    # Runs a heart change of pkmn (the block) and says what it moved.
    def self.heart_change(scene, pkmn)
      before = hearts(scene, pkmn)
      r = yield
      moved(scene, pkmn, before)
      r
    end

    # Says a contestant's hearts after a change that moved them and, inside the crowd's turn, the meter it followed.
    def self.moved(scene, pkmn, before)
      now = hearts(scene, pkmn)
      if now.is_a?(Integer) && now != before
        PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_hearts, :name => name_of(pkmn), :n => now), false)
      end
      applause(scene) if @crowd.equal?(scene)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The applause meter's level as its picture shows it, at most five, said when it changes.
    def self.applause(scene)
      n = PokeAccess.ivar(scene, :@applause)
      return unless n.is_a?(Integer)
      n = [[n, 0].max, APPLAUSE_MAX].min
      PokeAccess::Cursor.announce(scene, :chall_applause, n, false) do
        PokeAccess::I18n.t(:if2_ct_applause, :n => n, :max => APPLAUSE_MAX)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs the crowd's turn (the block), whose heart changes also say the meter, and says the level it is left at.
    def self.crowd(scene)
      was = @crowd
      @crowd = scene
      begin
        r = yield
      ensure
        @crowd = was
      end
      applause(scene)
      r
    end

    # The hearts the audience shows a contestant being introduced, as show_heart_vote answers them lit: a count, every
    # heart event (an Array), or none.
    def self.vote(poke, lit)
      n = lit.is_a?(Integer) ? lit : (lit.is_a?(Array) ? lit.length : 0)
      PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_crowd, :name => name_of(poke), :n => n), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Which places in the running order show the oblivious mark, top to bottom.
    def self.marks(scene)
      OBLIVIOUS.map { |k| PokeAccess.sprite(scene, k) ? true : false }
    end

    # Says each contestant whose oblivious mark a repaint has put up, given the marks before it.
    def self.marked(scene, before)
      order = PokeAccess.ivar(scene, :@pokeorder) || []
      marks(scene).each_with_index do |on, i|
        next unless on && !before[i] && order[i]
        PokeAccess.speak(PokeAccess::I18n.t(:sv_ct_oblivious, :name => name_of(order[i])), false)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Holds the results screen while it runs (the block), its labels counted from none.
    def self.results(scene)
      @results = scene
      @paints = 0
      yield
    ensure
      @results = nil
    end

    def self.results?; !@results.nil?; end

    # A label the results screen paints on its text strip, said as painted; from the third on, after the bars that grew
    # since the last one: the preliminary scores, then the final ones.
    def self.results_paint(bitmap, rows)
      scene = @results
      return unless scene && rows.is_a?(Array)
      strip = PokeAccess.sprite(scene, "textbitmap")
      return unless strip && (strip.bitmap.equal?(bitmap) rescue false)
      @paints += 1
      bars = @paints >= 3 ? bars_line(scene) : nil
      PokeAccess.speak(bars, false) if bars
      label = PokeAccess::PaintCapture.text(rows.map { |r| r.is_a?(Array) ? r[0] : nil }.compact)
      PokeAccess.speak(label, false) unless label.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The four bars as each contestant's share of the best score, top to bottom (the player's first); nil while none
    # has grown.
    def self.bars_line(scene)
      list = []
      entrants(scene).each_with_index do |p, i|
        bar = PokeAccess.sprite(scene, "color #{i}")
        next unless p && bar
        n = ((bar.x.to_f - BAR_START) * 100 / BAR_FULL).round
        list.push([name_of(p), [n, 0].max])
      end
      return nil if list.all? { |r| r[1] == 0 }
      list.map { |nm, n| PokeAccess::I18n.t(:chall_bar, :name => nm, :n => n) }.join(", ")
    end
  end
end

# The judge's lines and the audience's reactions go through the plugin's own message box, which the dialogue reader
# never sees.
PokeAccess::Hooks.wrap_kernel("pbMessageDisplayContest", "plugin_contest_hall_message", :before) do |args, _r|
  PokeAccess::ContestShow.message(args[1])
end
# The move menu (its opening each round and each move of its cursor) and the side panel's repaint.
PokeAccess::Hooks.after_hook("ContestHall::Show", :choose_move, :optional => true) do |s, _r, _a|
  PokeAccess::ContestShow.opening(s)
end
PokeAccess::Hooks.after_hook("ContestHall::Show", :set_name_move, :optional => true) do |s, _r, _a|
  PokeAccess::ContestShow.choice(s)
end
PokeAccess::Hooks.after_hook("ContestHall::Show", :pbDrawText, :optional => true) do |s, _r, _a|
  PokeAccess::ContestShow.order(s)
end
# The heart meters, the crowd's turn, the introduction's votes and the oblivious marks.
PokeAccess::Hooks.around_hook("ContestHall::Show", :display_positive_hearts, :optional => true) do |s, nxt, _a|
  PokeAccess::ContestShow.heart_change(s, PokeAccess.ivar(s, :@currentpoke)) { nxt.call }
end
PokeAccess::Hooks.around_hook("ContestHall::Show", :decrease_hearts, :optional => true) do |s, nxt, a|
  PokeAccess::ContestShow.heart_change(s, a[0]) { nxt.call }
end
PokeAccess::Hooks.around_hook("ContestHall::Show", :crowd, :optional => true) do |s, nxt, _a|
  PokeAccess::ContestShow.crowd(s) { nxt.call }
end
PokeAccess::Hooks.after_hook("ContestHall::Show", :show_heart_vote, :optional => true) do |_s, r, a|
  PokeAccess::ContestShow.vote(a[0], r)
end
PokeAccess::Hooks.around_hook("ContestHall::Show", :oblivious_graphic, :optional => true) do |s, nxt, _a|
  before = PokeAccess::ContestShow.marks(s)
  r = nxt.call
  PokeAccess::ContestShow.marked(s, before)
  r
end
# The results: their labels on the text strip, each after the bars it follows.
PokeAccess::Hooks.around_hook("ContestHall::Show", :result_scene, :optional => true) do |s, nxt, _a|
  PokeAccess::ContestShow.results(s) { nxt.call }
end
PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "plugin_contest_hall_results", :before) do |args, _r|
  PokeAccess::ContestShow.results_paint(args[0], args[1]) if PokeAccess::ContestShow.results?
end
