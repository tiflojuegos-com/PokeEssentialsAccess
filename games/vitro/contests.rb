# Vitro's Pokemon Contests (PokeContestScene, 0232_Contest_Core and 0233_Contest_Scene, Tastyredtomato's edit of mej71's script for
# v18): not Sevii's copy, with other methods and messages of its own in a window no core reader looks at. Each message as the
# window takes it, the move menu by its bar (its cursor is a local of pbMoveButtons, and update_selection is defined each time it
# runs), the running order, the hearts, the stars, the applause, the shield mark, the meter of totals, and the results, which show
# only as bars and pictures. And the move-to-forget list of the summary (0238_Patch), which left and right turn to its contest face,
# with a third argument that core's reading takes for the Pokemon of another era's form.
module PokeAccess
  module VitroContests
    ROUNDS = 5
    APPLAUSE_MAX = 5
    # The contest types as the game keeps them, by the word of each category.
    CATEGORY_KEYS = { "Cool" => :cnd_cool, "Beauty" => :cnd_beauty, "Cute" => :cnd_cute, "Smart" => :cnd_smart,
                      "Tough" => :cnd_tough }
    # Where pbMoveButtons puts the bar on the first row; each row is one bar's height below.
    SELECT_TOP = 196
    MOVE_ROWS = 4
    # The marks of the four places of the side panel, top to bottom.
    SHIELD = %w[obliviousone oblivioustwo obliviousthree obliviousfour]
    NERVOUS = %w[nervousone nervoustwo nervousthree nervousfour]
    OUT = %w[nomoveone nomovetwo nomovethree nomovefour]
    STARTLED = %w[startleone startletwo startlethree startlefour]

    # The four contestants as the scene keeps them, the player's first.
    def self.entrants(scene)
      [PokeAccess.ivar(scene, :@pkmn1), PokeAccess.ivar(scene, :@pkmn2), PokeAccess.ivar(scene, :@pkmn3),
       PokeAccess.ivar(scene, :@pkmn4)]
    end

    # A contestant's value of one of the scene's four ivars, the suffix of @pkmn1 to @pkmn4: hearts, total or stars.
    def self.value(scene, pkmn, suffix)
      i = entrants(scene).index { |p| p && p.equal?(pkmn) }
      i ? PokeAccess.ivar(scene, :"@pkmn#{i + 1}#{suffix}") : nil
    end

    def self.name_of(pkmn)
      PokeAccess.clean(pkmn.name.to_s)
    end

    # The running order as the side panel shows it.
    def self.order_of(scene)
      order = PokeAccess.ivar(scene, :@pokeorder)
      order.is_a?(Array) ? order : []
    end

    # A message as its window takes it; the judge's carries a colour tag, which clean drops.
    def self.message(msg)
      PokeAccess.say_dialogue(_INTL(msg.to_s))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The row the move bar stands on, or nil while the menu has no bar.
    def self.cursor(scene)
      bar = PokeAccess.sprite(scene, "selectbar")
      return nil unless bar
      (bar.y - SELECT_TOP) / bar.bitmap.height
    end

    # What the menu shows of a row: its name and place, the grey of the move used last, the type icon, the hearts and the
    # description, each at the battle move reading's level. The cursor also stands on the rows of a Pokemon's missing moves.
    def self.move_parts(scene, id, row)
      return [[PokeAccess::Verbosity.list_entry(PokeAccess::I18n.t(:row_empty), row + 1, MOVE_ROWS), :brief]] if id == 0
      data = ::PBContestMoveData.new(id)
      parts = [[PokeAccess::Verbosity.list_entry(PokeAccess.clean(PBMoves.getName(id).to_s), row + 1, MOVE_ROWS), :brief]]
      parts.push([PokeAccess::I18n.t(:if2_ct_repeat), :brief]) if PokeAccess.ivar(scene, :@pkmn1lastmoveid) == id
      key = CATEGORY_KEYS[data.contestType.to_s]
      parts.push([PokeAccess::I18n.t(:if2_ct_category, :t => PokeAccess::I18n.t(key)), :medium]) if key
      parts.push(["#{_INTL('EXHIBICIÓN')} #{(data.hearts || 4).to_i}", :full])
      parts.push(["#{_INTL('INHIBICIÓN')} #{(data.jam || 0).to_i}", :full])
      parts.push([PokeAccess.clean(pbGetContestMoveDescription(id).to_s), :full])
    end

    # The focused row at the reading's level; the info key keeps it whole, then the side panel.
    def self.move_line(scene, id, row)
      parts = move_parts(scene, id, row)
      whole = PokeAccess::Verbosity.full_line(parts, ". ")
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([whole, panel(scene)]), whole)
      PokeAccess::Verbosity.line(:battle_move, parts, ". ")
    end

    # The bar's row as [key, line] for the menu's watcher.
    def self.focus(scene)
      row = cursor(scene)
      pkmn = PokeAccess.ivar(scene, :@pkmn1)
      return nil unless row && pkmn && pkmn.moves[row]
      id = pkmn.moves[row].id
      [row, lambda { move_line(scene, id, row) }]
    end

    def self.round_text(scene)
      n = PokeAccess.ivar(scene, :@round)
      n.is_a?(Integer) && n >= 1 && n <= ROUNDS ? PokeAccess::I18n.t(:sv_ct_round, :n => n, :tot => ROUNDS) : nil
    end

    # The player's place in the running order, as the panel's highlight shows it; nil while the order lists nobody.
    def self.place_text(scene)
      own = PokeAccess.ivar(scene, :@pkmn1)
      place = order_of(scene).index { |p| p.equal?(own) }
      place ? PokeAccess::I18n.t(:sv_ct_place, :n => place + 1) : nil
    end

    # The names of the running order and the player's place in it, said when a new order is painted; the info key's panel
    # follows it.
    def self.order(scene)
      names = order_of(scene).map { |p| name_of(p) }
      return if names.empty?
      PokeAccess::Cursor.announce(scene, :vitro_ct_order, names, false) do
        PokeAccess::Info.set_info(:text, panel(scene))
        PokeAccess.sentences([PokeAccess::I18n.t(:if2_ct_order, :list => names.join(", ")), place_text(scene)])
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What a row of the side panel shows beyond the name, in words: the round's hearts, the stars, then the marks.
    def self.marks(scene, pkmn, place)
      words = []
      hearts = value(scene, pkmn, "hearts").to_i
      words.push(PokeAccess::I18n.t(:vitro_ct_hearts, :n => hearts)) unless hearts == 0
      stars = value(scene, pkmn, "stars").to_i
      words.push(PokeAccess::I18n.t(:vitro_ct_stars, :n => stars)) if stars > 0
      words.push(PokeAccess::I18n.t(:vitro_ct_shielded)) if PokeAccess.sprite(scene, SHIELD[place])
      words.push(PokeAccess::I18n.t(:vitro_ct_nervous)) if PokeAccess.sprite(scene, NERVOUS[place])
      words.push(PokeAccess::I18n.t(:vitro_ct_startled)) if PokeAccess.sprite(scene, STARTLED[place])
      words.push(PokeAccess::I18n.t(:vitro_ct_out)) if PokeAccess.sprite(scene, OUT[place])
      words
    end

    # A row's name and, when it has one, its trainer, as the panel paints them.
    def self.panel_name(pkmn)
      pkmn.ot.to_s.empty? ? name_of(pkmn) : "#{name_of(pkmn)} #{PokeAccess.clean(_INTL('/ {1}', pkmn.ot))}"
    end

    # The running totals the meters show, in the panel's order.
    def self.totals(scene)
      list = order_of(scene).map { |p| "#{name_of(p)} #{value(scene, p, 'total').to_i}" }
      list.empty? ? nil : PokeAccess::I18n.t(:if2_ct_totals, :list => list.join(", "))
    end

    # The side panel in words: the round, each row with its marks, the player's place and the totals.
    def self.panel(scene)
      rows = []
      order_of(scene).each_with_index { |p, i| rows.push(([panel_name(p)] + marks(scene, p, i)).join(", ")) }
      order = rows.empty? ? nil : PokeAccess::I18n.t(:if2_ct_order, :list => rows.join("; "))
      PokeAccess.sentences([round_text(scene), order, place_text(scene), totals(scene)])
    end

    # Runs a change of a contestant's hearts (the block) and says what it left, as the row's hearts show it.
    def self.heart_change(scene, pkmn)
      before = value(scene, pkmn, "hearts")
      ret = yield
      moved(scene, pkmn, before)
      ret
    end

    def self.moved(scene, pkmn, before)
      now = value(scene, pkmn, "hearts")
      return unless now.is_a?(Integer) && now != before
      PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_hearts, :name => name_of(pkmn), :n => now), false)
      PokeAccess::Info.set_info(:text, panel(scene))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs a change of stars at a place of the panel (the block) and says what it left.
    def self.star_change(scene, place)
      pkmn = order_of(scene)[place]
      before = pkmn ? value(scene, pkmn, "stars") : nil
      ret = yield
      begin
        now = pkmn ? value(scene, pkmn, "stars") : nil
        if now.is_a?(Integer) && now != before
          PokeAccess.speak("#{name_of(pkmn)}, #{PokeAccess::I18n.t(:vitro_ct_stars, :n => now)}", false)
          PokeAccess::Info.set_info(:text, panel(scene))
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
      end
      ret
    end

    # The applause meter's level, said when it shows a new one.
    def self.applause(scene)
      n = PokeAccess.ivar(scene, :@applause)
      return unless n.is_a?(Integer)
      n = [[n, 0].max, APPLAUSE_MAX].min
      PokeAccess::Cursor.announce(scene, :vitro_ct_applause, n, false) do
        PokeAccess::I18n.t(:if2_ct_applause, :n => n, :max => APPLAUSE_MAX)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Which places of the panel show the shield mark, top to bottom.
    def self.shields(scene)
      SHIELD.map { |k| PokeAccess.sprite(scene, k) ? true : false }
    end

    # Says each contestant whose shield mark a repaint has put up, given the marks before it: one move gives it with no message.
    def self.shielded(scene, before)
      order = order_of(scene)
      shields(scene).each_with_index do |on, i|
        next unless on && !before[i] && order[i]
        PokeAccess.speak(PokeAccess::I18n.t(:sv_ct_oblivious, :name => name_of(order[i])), false)
        PokeAccess::Info.set_info(:text, panel(scene))
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The totals the meters show at the end of a round, in place of bars with no number; the round's own hearts join them
    # as they reset, so the first round's meters stand empty and say nothing.
    def self.meters(scene)
      PokeAccess.speak(totals(scene), false) if order_of(scene).any? { |p| value(scene, p, "total").to_i != 0 }
      PokeAccess::Info.set_info(:text, panel(scene))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The results' rows ranked as pbUpdatePositions ranks them: [place, Pokemon, score], first place first.
    def self.standings(scene)
      data = PokeAccess.ivar(scene, :@results_data)
      return [] unless data.is_a?(Array)
      rows = []
      data.each_with_index { |d, i| rows.push([d[:display_score].to_i, i, d[:pokemon]]) }
      ranked = rows.sort_by { |r| [-r[0], r[1]] }
      out = []
      ranked.each_with_index { |r, i| out.push([i + 1, r[2], r[0]]) }
      out
    end

    def self.ranking(rows)
      rows.map { |pos, pkmn, n| PokeAccess::I18n.t(:if2_ct_place, :pos => pos, :name => name_of(pkmn), :n => n) }.join(", ")
    end

    # A phase of the results has filled its bars: the player's place and score, as six phases pass in some eighteen seconds,
    # and the whole table at the last one. The info key keeps the table.
    def self.phase_done(scene, last)
      rows = standings(scene)
      table = ranking(rows)
      PokeAccess::Info.set_info(:text, table)
      return PokeAccess.speak(table, false) if last
      own = PokeAccess.ivar(scene, :@pkmn1)
      row = rows.find { |r| r[1].equal?(own) }
      return unless row
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:sv_ct_place, :n => row[0]),
                                             PokeAccess::I18n.t(:if2_ct_score, :name => name_of(own), :n => row[2])]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A part of the winner's stage as it paints, said and added to what the info key keeps of it.
    def self.stage(scene, pairs)
      text = PokeAccess.sentences(PokeAccess::PaintCapture.lines(pairs))
      kept = PokeAccess.sentences([PokeAccess.ivar(scene, :@access_ct_stage), text])
      scene.instance_variable_set(:@access_ct_stage, kept)
      PokeAccess::Info.set_info(:text, kept)
      PokeAccess.speak(text, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The Pokemon and the move of a repaint of the move list, drawSelectedMove(moveToLearn, moveid, contestMode), with its face kept.
    def self.selected_move(scene, args)
      scene.instance_variable_set(:@access_contest_face, args[2] ? true : false)
      [PokeAccess.ivar(scene, :@pokemon), args[1]]
    end

    # The title the page paints, only as the face turns.
    def self.face_title(scene)
      face = PokeAccess.ivar(scene, :@access_contest_face) ? true : false
      told = PokeAccess.ivar(scene, :@access_face_told) ? true : false
      scene.instance_variable_set(:@access_face_told, face)
      return nil if face == told
      face ? _INTL("MOV. CONCURSO") : _INTL("MOVIMIENTOS")
    end

    # A move of the list as its face paints it: core's reading of the battle face (the block), or the contest face's data, kept
    # for the info key.
    def self.move_detail(scene, mid)
      title = face_title(scene)
      return PokeAccess.sentences([title, yield]) unless PokeAccess.ivar(scene, :@access_contest_face)
      data = ::PBContestMoveData.new(mid)
      key = CATEGORY_KEYS[data.contestType.to_s]
      text = PokeAccess.sentences([title, PBMoves.getName(mid), key ? PokeAccess::I18n.t(:if2_ct_category, :t => PokeAccess::I18n.t(key)) : nil,
                                   "EXHIBICIÓN #{(data.hearts || 0).to_i}", "INHIBICIÓN #{(data.jam || 0).to_i}",
                                   PokeAccess.clean(pbGetContestMoveDescription(mid).to_s)])
      PokeAccess::Info.set_info(:text, text)
      text
    end
  end
end

PokeAccess::Game.define("vitro") do
  before("PokeContestScene", :pbShowMessageWindow, :optional => true) { |_s, a| PokeAccess::VitroContests.message(a[0]) }
  after("PokeContestScene", :pbDrawText, :optional => true) { |s, _r, _a| PokeAccess::VitroContests.order(s) }
  around("PokeContestScene", :pbAdjustHearts, :optional => true) do |s, nxt, a|
    PokeAccess::VitroContests.heart_change(s, a[1]) { nxt.call }
  end
  around("PokeContestScene", :pbDecreaseStarGraphics, :optional => true) do |s, nxt, a|
    PokeAccess::VitroContests.star_change(s, a[0]) { nxt.call }
  end
  around("PokeContestScene", :pbCrowd, :optional => true) do |s, nxt, _a|
    PokeAccess::VitroContests.applause(s)
    ret = nxt.call
    PokeAccess::VitroContests.applause(s)
    ret
  end
  around("PokeContestScene", :pbObliviousGraphic, :optional => true) do |s, nxt, _a|
    before = PokeAccess::VitroContests.shields(s)
    ret = nxt.call
    PokeAccess::VitroContests.shielded(s, before)
    ret
  end
  before("PokeContestScene", :pbShowHeartMeterForAll, :optional => true) { |s, _a| PokeAccess::VitroContests.meters(s) }
  before("PokeContestScene", :pbShowPhaseTitle, :optional => true) { |_s, a| PokeAccess.speak_clean(a[0].to_s, false) }
  around("PokeContestScene", :pbShowPreliminaryResults, :optional => true) do |s, nxt, _a|
    ret = nxt.call
    PokeAccess::VitroContests.phase_done(s, false)
    ret
  end
  around("PokeContestScene", :pbShowRoundResults, :optional => true) do |s, nxt, a|
    ret = nxt.call
    PokeAccess::VitroContests.phase_done(s, a[0] == PokeAccess::VitroContests::ROUNDS)
    ret
  end
  [:pbDrawCelebrationHeader, :pbDrawCelebrationMessage].each do |meth|
    on_paint("PokeContestScene", meth, :optional => true) do |s, pairs, _a|
      PokeAccess::VitroContests.stage(s, pairs)
    end
  end
  clear_info_on("PokeContestScene", :pbEndScene)

  override("PokeAccess::SummaryGen6", :selected_move) do |_mod, _original, args|
    PokeAccess::VitroContests.selected_move(args[0], args[1])
  end
  override("PokeAccess::SummaryGen6", :move_detail_text) do |_mod, original, args|
    PokeAccess::VitroContests.move_detail(args[0], args[2]) { original.call }
  end
  before("PokemonSummaryScene", :pbChooseMoveToForget, :optional => true) do |_scene, _a|
    PokeAccess.speak(PokeAccess::I18n.t(:vitro_forget_keys), false) if PokeAccess::Verbosity.hints?
  end
end

PokeAccess::SceneWatcher.reader("PokeContestScene", :pbMoveButtons, :vitro_ct_move, :optional => true) do |scene|
  PokeAccess::VitroContests.focus(scene)
end
