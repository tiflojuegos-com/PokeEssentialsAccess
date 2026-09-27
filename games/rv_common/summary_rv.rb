module PokeAccess
  # The summary of the engine Reborn, Rejuvenation and Desolation share (PokemonSummaryScene): after the skills page,
  # drawPageFour paints each stat's EV and IV and drawPageFive the moves, with no ribbons page after them. In Reborn
  # and Rejuvenation C on the skills or EV & IV page opens the ability page (drawAbilPage), and the moves page swaps
  # with the Z-moves page (drawZMovePage), whose move cursor draws each Z-move in detail (drawSelectedZeeMove).
  module SummaryRV
    # The EV & IV page's rows as [PBStats index, stat name key]: the engine numbers the stats in the painted order.
    ROWS = [[0, :st_hp], [1, :st_atk], [2, :st_def], [3, :st_spatk], [4, :st_spdef], [5, :st_speed]]

    # Painted moves sit one slot every 64 pixels; the summary's moves column is [left, right, top]: right of x 300,
    # from y 90.
    SLOT_HEIGHT = 64
    COLUMN = [300, 9999, 90]

    # The EV & IV page: its title, each stat's EV and IV, the nature's effect its labels colour and the ability with
    # the description the page paints under it.
    # param painted the texts the page painted
    def self.eviv_text(pk, painted)
      rows = PokeAccess::Summary.eviv_rows(pk, ROWS)
      extra = [PokeAccess::Summary.nature_effect_line(pk), PokeAccess::Summary.ability_line(pk, painted)].compact
      ([PokeAccess::I18n.t(:rv_sum_eviv) + ". " + rows.join(". ") + "."] + extra).join(" ")
    rescue StandardError
      nil
    end

    # Whether the moves page paints the button to the Z-moves: the Pokemon has one at least.
    def self.zmoves?(pk)
      z = (pk.zmoves rescue nil)
      z.is_a?(Array) && z.any? { |m| !m.nil? }
    end

    # The key hint of a button the moves pages paint: the action button, A on the keyboard.
    def self.button_hint(key)
      PokeAccess::I18n.t(key, :key => PokeAccess::KeyHints.key(:x, "A"))
    end

    # The moves page: the moves, then the key to the Z-moves where their button is painted.
    def self.moves_page(pk)
      t = PokeAccess::Summary.moves_text(pk)
      (t && zmoves?(pk)) ? PokeAccess::Verbosity.with_hint(t, button_hint(:rv_sum_to_zmoves)) : t
    end

    # Puts each core page read on the page this summary draws there: 4 is the EV & IV page, 5 the moves.
    # param args Summary.speak_page's arguments (scene, pokemon, page, text), changed in place
    def self.repage(args)
      case args[2]
      when 4 then args[3] = eviv_text(args[1], PokeAccess::PaintCapture.take(:summary_eviv_rv) || [])
      when 5 then args[3] = moves_page(args[1])
      end
      args
    end

    # The ability page as painted: its box, each label with the line under it.
    def self.ability_text(pairs)
      lines = pairs.select { |r| r[1] == :formatted }.map { |r| r[0].to_s.split(/\r?\n/) }.flatten
      PokeAccess::PaintCapture.pair_labels(lines.map { |l| PokeAccess.clean(l) }).join(". ")
    end

    # The slot a height falls in, from a column's top.
    def self.slot_of(y, top)
      ((y.to_f - top) / SLOT_HEIGHT).floor
    end

    # A column of moves as painted, by slot: [name, type name, pp, total pp], nil where the slot is empty. The name is
    # the slot's first text, the PP its "pp/total" figure, the type the Icons/type<TYPE> icon drawn at its height.
    # param pairs the texts as take_pairs gives them
    # param icons the rows drawn through pbDrawImagePositions
    # param column [left, right, top] of the column, the summary's by default
    def self.slots(pairs, icons, column = COLUMN)
      left, right, top = column
      out = []
      pairs.each do |t, _src, x, y|
        next unless x.is_a?(Numeric) && y.is_a?(Numeric) && x >= left && x < right && slot_of(y, top) >= 0
        s = (out[slot_of(y, top)] ||= [nil, nil, nil, nil])
        txt = PokeAccess.clean(t)
        if txt =~ /\A(\d+)\/(\d+)\z/
          s[2] = $1.to_i
          s[3] = $2.to_i
        elsif s[0].nil? && !PokeAccess::Menus.placeholder?(txt)
          s[0] = txt
        end
      end
      icons.each do |r|
        next unless r[0].to_s =~ /Icons\/type(\w+)\z/ && r[2].is_a?(Numeric)
        i = slot_of(r[2], top)
        out[i][1] = PokeAccess::Data.type_name($1.to_sym) if i >= 0 && out[i]
      end
      out.map { |s| (s && s[0]) ? s : nil }
    end

    # One slot as the moves page line reads a move: name, type, and its PP where painted.
    def self.slot_line(slot)
      parts = [[slot[0], :brief]]
      parts.push([PokeAccess::I18n.t(:mv_type, :t => slot[1]), :medium]) if slot[1]
      parts.push([PokeAccess::I18n.t(:mv_pp, :pp => slot[2], :tot => slot[3]), :brief]) if slot[2]
      PokeAccess::Verbosity.line(:summary_move, parts, ". ")
    end

    # The Z-moves page: each slot as painted (a Z-move, or the move that has none), then the key back to the moves.
    def self.zmoves_text(pairs, icons)
      list = slots(pairs, icons).compact.map { |s| slot_line(s) }
      return nil if list.empty?
      PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:rv_sum_zmoves, :list => list.join(", ")),
                                      button_hint(:rv_sum_to_moves))
    end

    # A painted figure of the detail (power, accuracy) as the number the move line words: dashes are none (no
    # damage, never misses), question marks a power that varies.
    def self.figure(text)
      t = PokeAccess.clean(text)
      return t.to_i if t =~ /\A\d+\z/
      t.include?("?") ? 1 : 0
    end

    # The Z-move under the cursor, as painted: the slot's name and type, the category its icon shows, the power and
    # accuracy beside the labels and the description under them.
    # param index the slot the cursor is on
    def self.zmove_detail(pairs, icons, index)
      slot = slots(pairs, icons)[index.to_i]
      return nil unless slot
      left = pairs.select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) && r[2] < COLUMN[0] }
      values = left.select { |r| r[1] == :positions && r[2] > 100 }.sort_by { |r| r[3] }.map { |r| r[0] }
      desc = left.select { |r| r[1] == :dtex }.map { |r| PokeAccess.clean(r[0]) }.join(" ")
      cat = icons.find { |r| r[0].to_s =~ /category\z/ }
      word = cat ? PokeAccess::MoveInfo.category_word(strip_cell(cat)) : nil
      PokeAccess::MoveInfo.leveled(:summary_move, slot[0], slot[1], values[0] ? figure(values[0]) : nil,
                                   values[1] ? figure(values[1]) : nil, :cat => word, :desc => desc)
    end

    # The cell of a strip an icon row shows: its source y over the cell height.
    def self.strip_cell(row)
      h = row[6].to_i > 0 ? row[6].to_i : 28
      row[4].to_i / h
    end

    # The summary scene class, the gen-6 lineage's.
    SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonSummaryScene", "PokemonSummary_Scene")

    # Hooks the pages: the override puts the core's reads on this summary's pages, the rest read what they paint.
    def self.bind
      scene = SCENE
      PokeAccess::Hooks.override("PokeAccess::Summary", :speak_page, :tag => "rv_summary") do |_mod, original, args|
        PokeAccess::SummaryRV.repage(args)
        original.call
      end
      PokeAccess::Hooks.before_hook(scene, :drawPageFour) { |_s, _a| PokeAccess::PaintCapture.arm(:summary_eviv_rv) }
      PokeAccess::Hooks.around_hook(scene, :drawAbilPage, :optional => true) do |s, nxt, args|
        r = nil
        pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
        pk = args[0] || PokeAccess.ivar(s, :@pokemon)
        PokeAccess::Summary.speak_page(s, pk, :ability, PokeAccess::SummaryRV.ability_text(pairs))
        r
      end
      PokeAccess::Hooks.around_hook(scene, :drawZMovePage, :optional => true) do |s, nxt, args|
        r = nil
        pairs = nil
        icons = PokeAccess::PaintCapture.icon_rows { pairs = PokeAccess::PaintCapture.sample { r = nxt.call } }
        pk = args[0] || PokeAccess.ivar(s, :@pokemon)
        PokeAccess::Summary.speak_page(s, pk, :zmoves, PokeAccess::SummaryRV.zmoves_text(pairs, icons))
        r
      end
      PokeAccess::Hooks.around_hook(scene, :drawSelectedZeeMove, :optional => true) do |s, nxt, _a|
        r = nil
        pairs = nil
        icons = PokeAccess::PaintCapture.icon_rows { pairs = PokeAccess::PaintCapture.sample { r = nxt.call } }
        t = PokeAccess::SummaryRV.zmove_detail(pairs, icons, (PokeAccess.sprite(s, "movesel").index rescue 0))
        if t
          PokeAccess::Info.set_info(:text, t)
          PokeAccess.speak(t, true)
        end
        r
      end
    end
  end
end

PokeAccess::SummaryRV.bind if PokeAccess::DataRV.engine?
