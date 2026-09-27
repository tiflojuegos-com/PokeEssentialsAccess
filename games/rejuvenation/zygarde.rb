module PokeAccess
  # Rejuvenation's Zygarde page of the summary (drawZygardePage, the sixth page of a Zygarde with a custom form,
  # "ZYGARDE CORES"): each stat's label and value, with the cores invested in it as cells; the types as icons; the
  # ability, the core effect and the cores left. C opens the allocation (coreAllocation): a selector over the six stats,
  # the type and the ability that up and down move and left and right change, each change redrawing the page.
  module RejuvZygarde
    # The heights the page paints each stat at (its zcellY), top to bottom, and its other rows.
    STAT_Y = [76, 108, 140, 172, 204, 236]
    TITLE_Y = 16
    TYPE_Y = 284
    ABILITY_Y = 316
    CORES_Y = 320
    EFFECT_Y = 348
    HINT_Y = 350

    # Where the right panel starts: the name, level, cores left and hint sit to its left.
    PANEL_X = 200

    # The figure space the stat values are right-justified with.
    FIGURE_SPACE = [0x2007].pack("U")

    # The strings painted at height y, left to right, as one line; from min_x on only.
    def self.row(pairs, y, min_x = 0)
      rows = Array(pairs).select { |r| r[3] == y && r[2].to_i >= min_x }.sort_by { |r| r[2].to_i }
      rows.map { |r| PokeAccess.clean(r[0].to_s.gsub(FIGURE_SPACE, " ")) }.reject { |t| t.empty? }.join(" ")
    end

    # The cores invested in each stat, as the page counts its cells.
    def self.cores(pk)
      Array(pk.customForm.checkFlag?(:CoreInvestment))
    rescue StandardError
      []
    end

    # The selector's row i as the page shows it: a stat's label and value with its cores, the type row with the names
    # of the types its icons show, or the ability row.
    def self.line(pk, pairs, i)
      if i < STAT_Y.length
        "#{row(pairs, STAT_Y[i], PANEL_X)}, #{PokeAccess::I18n.t(:rj_zyg_cores, :n => cores(pk)[i].to_i)}"
      elsif i == STAT_Y.length
        types = [(pk.type1 rescue nil), (pk.type2 rescue nil)].compact.uniq
        names = types.map { |t| (PokeAccess::DataRV.type_name(t) rescue nil) || t.to_s.capitalize }
        "#{row(pairs, TYPE_Y, PANEL_X)} #{names.join(', ')}"
      else
        row(pairs, ABILITY_Y, PANEL_X)
      end
    end

    # The whole page: its title, the stats, the type, the ability, the core effect and the cores left, then its key
    # hint while key hints are said.
    def self.page_text(pk, pairs)
      lines = [row(pairs, TITLE_Y)] + (0..7).map { |i| line(pk, pairs, i) }
      lines.push(row(pairs, EFFECT_Y, PANEL_X), row(pairs, CORES_Y))
      PokeAccess.sentences(lines + [PokeAccess::KeyHints.gate_sentences(row(pairs, HINT_Y))])
    end

    # The selector, while the allocation shows it.
    def self.selector(scene)
      sel = PokeAccess.sprite(scene, "statsel")
      (sel && sel.visible) ? sel : nil
    end

    # Runs a draw of the page and reads it: the whole page, or while allocating the row under the selector with the
    # cores left, the first time with the hint that closes it. A draw that paints nothing (a Pokemon with no cores,
    # reached with up or down on this page) says nothing.
    # param args drawZygardePage's (pokemon, allocation)
    def self.draw(scene, args)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      pk = args[0]
      return ret if pk.nil? || Array(pairs).empty?
      scene.instance_variable_set(:@access_rj_zyg, pairs)
      sel = args[1] ? selector(scene) : nil
      if sel.nil?
        PokeAccess::Cursor.reset(scene, :rj_zyg_sel)
        PokeAccess::Summary.speak_page(scene, pk, :rj_zygarde, page_text(pk, pairs))
      else
        first = PokeAccess::Cursor.current(scene, :rj_zyg_sel).nil?
        PokeAccess::Cursor.store(scene, :rj_zyg_sel, sel.index)
        hint = first ? PokeAccess::KeyHints.gate_sentences(row(pairs, HINT_Y)) : nil
        PokeAccess.speak(PokeAccess.sentences([line(pk, pairs, sel.index), row(pairs, CORES_Y), hint]), true)
      end
      ret
    end

    # Each frame of the allocation: says the row the selector lands on, from the page last drawn.
    def self.follow(scene)
      sel = selector(scene)
      return if sel.nil? || PokeAccess::Cursor.current(scene, :rj_zyg_sel).nil?
      return unless PokeAccess::Cursor.changed?(scene, :rj_zyg_sel, sel.index)
      pk = PokeAccess.ivar(scene, :@pokemon)
      PokeAccess.speak(line(pk, PokeAccess.ivar(scene, :@access_rj_zyg), sel.index), true) if pk
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("PokemonSummaryScene", :drawZygardePage, :optional => true) do |scene, nxt, args|
    PokeAccess::RejuvZygarde.draw(scene, args) { nxt.call }
  end

  after("PokemonSummaryScene", :pbUpdate, :optional => true) do |scene, _r, _a|
    PokeAccess::RejuvZygarde.follow(scene)
  end
end
