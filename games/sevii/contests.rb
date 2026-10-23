# Sevii's edited copy of the Pokemon Contests Script (PokeContestScene, adapted to v17): the move menu's data, the
# round, the running order, the hearts, the applause, the crowd's votes, the oblivious mark and the results, which the
# stage shows only as pictures, icons and bars.
module PokeAccess
  module SeviiContests
    ROUNDS = 5
    APPLAUSE_MAX = 5
    # The categories the menu's strip shows, by the row each takes (contestType 0 to 4).
    CATEGORY_KEYS = [:cnd_cool, :cnd_beauty, :cnd_cute, :cnd_smart, :cnd_tough]
    # The oblivious marks of the four places in the running order, top to bottom.
    OBLIVIOUS = %w[obliviousone oblivioustwo obliviousthree obliviousfour]
    @crowd = nil
    @results = nil
    @paints = 0
    @votes = 0

    # The four contestants as the scene keeps them, the player's first.
    def self.entrants(scene)
      [PokeAccess.ivar(scene, :@pkmn1), PokeAccess.ivar(scene, :@pkmn2), PokeAccess.ivar(scene, :@pkmn3),
       PokeAccess.ivar(scene, :@pkmn4)]
    end

    # A contestant's name as the stage paints it.
    def self.name_of(pkmn)
      PokeAccess.clean(pkmn.name.to_s)
    end

    # The contest move whose data the menu shows for a battle move: the first one of its name, as choose_move and
    # set_name_move find it; nil when none is.
    def self.contest_id(move_id)
      name = ::PBMoves.getName(move_id).to_s
      return nil if name.empty?
      (1..::PBContestMoves.maxValue).find { |i| ::PBContestMoves.getName(i) == name }
    end

    # What the strip and the panel show of a contest move: its category, appeal and jamming hearts and description.
    def self.detail_parts(cid)
      return [] unless cid
      data = ::PBContestMoveData.new(cid)
      key = CATEGORY_KEYS[data.contestType.to_i]
      parts = key ? [[PokeAccess::I18n.t(:if2_ct_category, :t => PokeAccess::I18n.t(key)), :medium]] : []
      parts.push([PokeAccess::I18n.t(:if2_ct_appeal, :n => data.hearts.to_i), :full])
      parts.push([PokeAccess::I18n.t(:if2_ct_jam, :n => data.jam.to_i), :full])
      parts.push([PokeAccess.clean(pbGetMessage(::MessageTypes::ContestMoveDescriptions, cid).to_s), :full])
    end

    # The focused move as the menu shows it: name and place, the grey of the move used last, then the strip's and the
    # panel's data at the battle move reading's level; the info key keeps it whole, followed by the round's standing.
    def self.choice_line(scene, pk, idx)
      name = ::PBMoves.getName(pk.moves[idx].id).to_s
      parts = [[PokeAccess::Verbosity.list_entry(name, idx + 1, pk.numMoves), :brief]]
      last = PokeAccess.ivar(scene, :@pkmn1lastmove)
      parts.push([PokeAccess::I18n.t(:if2_ct_repeat), :brief]) if last && last == name
      parts.concat(detail_parts(contest_id(pk.moves[idx].id)))
      whole = PokeAccess::Verbosity.full_line(parts, ". ")
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([whole, standing(scene)]), whole)
      PokeAccess::Verbosity.line(:battle_move, parts, ". ")
    end

    # Speaks the menu's focused move once per change; the first of a round is queued.
    def self.choice(scene)
      pk = PokeAccess.ivar(scene, :@pkmn1)
      idx = PokeAccess.ivar(scene, :@selection)
      return unless pk && idx.is_a?(Integer)
      PokeAccess::Cursor.announce(scene, :sv_ct_move, idx, true, false) { choice_line(scene, pk, idx) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The menu as each round opens it: the round its banner showed, the prompt it paints, then the focused move.
    def self.opening(scene)
      round = round_text(scene)
      PokeAccess.speak(round, false) if round
      PokeAccess.speak(PokeAccess.clean(_INTL("Please select a move.")), false)
      PokeAccess::Cursor.reset(scene, :sv_ct_move)
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
      PokeAccess::Cursor.announce(scene, :sv_ct_order, line, false) { line } if line
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
      PokeAccess::Cursor.announce(scene, :sv_ct_applause, n, false) do
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

    # Runs the crowd's vote for a presented contestant (the block), no hearts unless the crowd shows some, and says
    # how many it showed.
    def self.vote(poke)
      @votes = 0
      r = yield
      begin
        PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_crowd, :name => name_of(poke), :n => @votes), false)
      rescue StandardError => e
        PokeAccess.swallowed(e)
      end
      r
    end

    # The hearts the crowd shows the contestant being voted (character_show_heart's count).
    def self.vote_count(n)
      @votes = n if n.is_a?(Integer)
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

    # A label the results screen paints on its text strip, said as painted; the first two are followed by the bars
    # they bring in: the preliminary scores, then the final ones.
    def self.results_paint(bitmap, rows)
      scene = @results
      return unless scene && rows.is_a?(Array)
      strip = PokeAccess.sprite(scene, "textbitmap")
      return unless strip && (strip.bitmap.equal?(bitmap) rescue false)
      @paints += 1
      label = PokeAccess::PaintCapture.text(rows.map { |r| r.is_a?(Array) ? r[0] : nil }.compact)
      PokeAccess.speak(label, false) unless label.empty?
      bars = bars_line(scene, @paints == 1 ? prelims(scene) : (@paints == 2 ? PokeAccess.ivar(scene, :@winner) : nil))
      PokeAccess.speak(bars, false) if bars
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The preliminary scores of the four rows, the player's first.
    def self.prelims(scene)
      [PokeAccess.ivar(scene, :@prelim1), PokeAccess.ivar(scene, :@prelim2), PokeAccess.ivar(scene, :@prelim3),
       PokeAccess.ivar(scene, :@prelim4)]
    end

    # The rows' bars as each contestant's score, top to bottom; nil without scores.
    def self.bars_line(scene, values)
      return nil unless values.is_a?(Array)
      list = entrants(scene).zip(values).map do |p, v|
        p ? PokeAccess::I18n.t(:if2_ct_score, :name => name_of(p), :n => v.to_i) : nil
      end
      list.compact.empty? ? nil : list.compact.join(", ")
    end
  end
end

# The move menu (its opening each round and each move of its cursor) and the side panel's repaint, the heart meters,
# the crowd's turn, the presentation's votes, the oblivious marks and the results' labels on their strip.
PokeAccess::Game.define("sevii") do
  after("PokeContestScene", :choose_move) { |s, _r, _a| PokeAccess::SeviiContests.opening(s) }
  after("PokeContestScene", :set_name_move) { |s, _r, _a| PokeAccess::SeviiContests.choice(s) }
  after("PokeContestScene", :pbDrawText) { |s, _r, _a| PokeAccess::SeviiContests.order(s) }
  around("PokeContestScene", :pbDisplayAddingPositiveHearts) do |s, nxt, _a|
    PokeAccess::SeviiContests.heart_change(s, PokeAccess.ivar(s, :@currentpoke)) { nxt.call }
  end
  around("PokeContestScene", :pbDecreaseHearts) do |s, nxt, a|
    PokeAccess::SeviiContests.heart_change(s, a[0]) { nxt.call }
  end
  around("PokeContestScene", :pbCrowd) { |s, nxt, _a| PokeAccess::SeviiContests.crowd(s) { nxt.call } }
  around("PokeContestScene", :show_heart_vote) { |_s, nxt, a| PokeAccess::SeviiContests.vote(a[0]) { nxt.call } }
  before("PokeContestScene", :character_show_heart) { |_s, a| PokeAccess::SeviiContests.vote_count(a[0]) }
  around("PokeContestScene", :pbObliviousGraphic) do |s, nxt, _a|
    before = PokeAccess::SeviiContests.marks(s)
    r = nxt.call
    PokeAccess::SeviiContests.marked(s, before)
    r
  end
  around("PokeContestScene", :pbResultsScene) { |s, nxt, _a| PokeAccess::SeviiContests.results(s) { nxt.call } }
  kernel("pbDrawTextPositions") { |args, _r| PokeAccess::SeviiContests.results_paint(args[0], args[1]) }
end
