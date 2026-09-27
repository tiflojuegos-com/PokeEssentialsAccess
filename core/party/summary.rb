module PokeAccess
  # Summary screen helpers shared by the gen-6 reader (gen6/summary_g6.rb), the modern one (v21/summary_v21.rb)
  # and profiles with a summary of their own.
  module Summary
    @single_page = false

    # Whether a pokemon is an egg, under either era's question.
    def self.egg?(pk)
      return false unless pk
      (pk.egg? rescue (pk.isEgg? rescue false)) ? true : false
    rescue StandardError
      false
    end

    # Speaks the egg page as painted: memo, item, origin and how close it is to hatching. The capture is taken
    # before the egg check, since left armed it would collect the next screen's strings.
    # param pairs the page's capture, already taken, as [text, source] pairs; nil takes it here
    def self.say_egg_page(scene, pk, pairs = nil)
      pairs ||= PokeAccess::PaintCapture.take_pairs(:summary_egg)
      rows = pairs.map { |r| r[0] }
      return unless egg?(pk)
      t = PokeAccess::PaintCapture.text(rows)
      t = PokeAccess::I18n.t(:sm_egg) if t.to_s.strip.empty?
      speak_page(scene, pk, :egg, t, true)
    rescue StandardError
      nil
    end

    # Speaks a summary page and points the info key at its Pokemon: queued on opening, interrupting after, silent
    # on a redraw of the same page; another Pokemon is named first unless the page names it.
    # param page what tells the pages of one Pokemon apart: its number, or the page id of a plugin summary
    # param named true for a page whose text starts with the Pokemon (the data sheet, the egg page)
    def self.speak_page(scene, pk, page, text, named = false)
      return if pk.nil? || text.nil? || text.to_s.empty?
      last = PokeAccess.ivar(scene, :@access_page_key)
      key = [pk.object_id, page, text]
      return if key == last
      scene.instance_variable_set(:@access_page_key, key)
      PokeAccess::Info.set_info(:pokemon, pk)
      switched = !last.nil? && last[0] != pk.object_id
      PokeAccess.speak(switched && !named ? "#{whose(pk)}. #{text}" : text, !last.nil?, :menu)
    end

    # Forgets the page last spoken so its next redraw is read again, as a turn (the Pokemon is kept).
    def self.forget_page(scene)
      last = PokeAccess.ivar(scene, :@access_page_key)
      scene.instance_variable_set(:@access_page_key, last ? [last[0], nil, nil] : nil)
    end

    # A value the summary paints as a Pokedex number: three or four digits, or the question marks of one
    # outside every dex the player has.
    DEX_VALUE = /\A(\d{3,4}|\?{3})\z/

    # The Pokedex number page one paints, or nil: the value on the Dex label's row, else (a label drawn in the
    # background) the topmost value on the right half.
    # param pairs page one's capture, as take_pairs gives it (text, source, x, y)
    def self.painted_dex_number(pairs)
      rows = (pairs || []).select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }
      label = rows.find { |r| r[0].to_s =~ /dex/i }
      cands = if label
                rows.select { |r| (r[3] - label[3]).abs <= 8 && r[2] > label[2] }
              else
                half = (Graphics.width rescue 512) / 2
                rows.select { |r| r[2] > half }.sort_by { |r| r[3] }.first(1)
              end
      v = cands.map { |r| PokeAccess.clean(r[0]) }.find { |t| t =~ DEX_VALUE }
      v ? PokeAccess::DexEntry.unknown_marks(v) : nil
    rescue StandardError
      nil
    end

    # Whose page it is, as the header shows it: the name with its sex sign, and the level.
    def self.whose(pk)
      PokeAccess::I18n.t(:sum_whose, :name => "#{pk.name}#{PokeAccess::Party.sign_phrase(pk)}", :level => pk.level)
    end

    # A slot of the moves page by name, for the reorder cursor: the move in it, empty, or the page's exit
    # row past the four.
    def self.move_slot_name(pk, i)
      return PokeAccess::I18n.t(:sm_exit) if i == 4
      return nil unless pk && i
      m = (pk.moves[i] rescue nil)
      id = m ? PokeAccess::MoveInfo.id_of(m) : nil
      return PokeAccess::I18n.t(:sm_empty_slot) unless PokeAccess::MoveInfo.real_id?(id)
      nm = (m.name rescue nil)
      nm = (PokeAccess::Data.move_name(id) rescue nil) if nm.nil? || nm.to_s.empty?
      (nm.nil? || nm.to_s.empty?) ? PokeAccess::I18n.t(:info_move) : nm.to_s
    end

    # Clears the move-reorder tracking, so a new summary does not compare against a stale swap state.
    def self.reset_reorder
      @reorder_sw = nil
      @reorder_idx = nil
      @reorder_back = false
    end

    # Speaks the move reorder from movesel and movepresel each frame: pick-up, position, and placed or cancelled.
    # Called from pbUpdate, where Input still holds the back key that tells a cancel from a drop.
    def self.reorder_poll(scene)
      mp = PokeAccess.sprite(scene, "movepresel")
      ms = PokeAccess.sprite(scene, "movesel")
      return if mp.nil? || ms.nil?
      pk = PokeAccess.ivar(scene, :@pokemon)
      sw = mp.visible ? true : false
      idx = (ms.index rescue nil)
      if sw != @reorder_sw
        prev = @reorder_sw
        @reorder_sw = sw
        @reorder_idx = idx
        return if prev.nil?
        if sw
          @reorder_back = false
          picked = PokeAccess::I18n.t(:sm_reorder, :name => move_slot_name(pk, (mp.index rescue idx)))
          PokeAccess.speak(PokeAccess::Verbosity.with_hint(picked, PokeAccess::I18n.t(:sm_reorder_hint)), true)
        elsif @reorder_back || idx == 4
          PokeAccess.speak(PokeAccess::I18n.t(:sm_reorder_cancel), true)
        else
          PokeAccess.speak(PokeAccess::I18n.t(:sm_placed, :n => (idx ? idx + 1 : '?')), true)
        end
        return
      end
      @reorder_back = true if sw && (Input.trigger?(Input::B) rescue false)
      return unless sw && idx != @reorder_idx
      @reorder_idx = idx
      return PokeAccess.speak(PokeAccess::I18n.t(:sm_exit), true) if idx == 4
      nm = move_slot_name(pk, idx)
      PokeAccess.speak(PokeAccess::I18n.t(:sm_position, :n => idx + 1) + (nm ? ", " + nm : ""), true)
    rescue StandardError
      nil
    end

    # A ribbon as [name, description], from GameData::Ribbon or gen-6's PBRibbons, or nil.
    def self.ribbon_parts(id)
      return nil unless id
      r = (GameData::Ribbon.get(id) rescue nil)
      return [(r.name rescue nil), (r.description rescue nil)] if r
      name = (PBRibbons.getName(id) rescue nil)
      return nil if name.nil? || name.to_s.empty?
      [name, (PBRibbons.getDescription(id) rescue nil)]
    end

    # A painted key hint: a bracketed key ("[C]: Descripcion") or a sentence that asks for one. Pages composed
    # from the data leave these out, so they are read from the paint.
    HINT = PokeAccess::KeyHints::HINT

    # The key hints among a page's painted lines, each as one sentence: a hint line that does not end a sentence
    # is joined to the next.
    def self.page_hints(lines)
      rows = Array(lines).map { |l| PokeAccess.clean(l.to_s) }.reject { |l| l.empty? }
      out = []
      i = 0
      while i < rows.length
        if rows[i] =~ HINT
          h = rows[i]
          while h !~ /[.!?:]\z/ && h !~ /\A\[/ && i + 1 < rows.length && rows[i + 1] !~ HINT
            i += 1
            h = "#{h} #{rows[i]}"
          end
          out.push(PokeAccess::KeyHints.localize(h =~ /[.!?]\z/ ? h : "#{h}.", nil, true))
        end
        i += 1
      end
      out
    end

    # A page's text with the key hints it paints after it, while key hints are said.
    def self.with_hints(text, lines)
      return text if text.nil? || !PokeAccess::Verbosity.hints?
      hints = page_hints(lines)
      return text if hints.empty?
      "#{text.to_s.strip} #{hints.join(' ')}"
    end

    # The ribbon cell under the cursor: the ribbon or empty, and its place (four to a row, scrolled by
    # @ribbonOffset). Medium adds the place, full the description; the info key keeps all of it.
    def self.ribbon_cell_text(scene, id)
      sel = PokeAccess.sprite(scene, "ribbonsel")
      idx = (sel.index rescue nil)
      row = PokeAccess.ivar_i(scene, :@ribbonOffset) + (idx.is_a?(Integer) ? idx / 4 : 0)
      pos = idx.is_a?(Integer) ? PokeAccess::I18n.t(:pc_pos, :row => row + 1, :col => idx % 4 + 1) : ""
      name, desc = ribbon_parts(id)
      head = name.nil? || name.to_s.empty? ? PokeAccess::I18n.t(:rb_empty) : name.to_s
      desc = nil if desc.to_s.strip.empty?
      PokeAccess::Info.set_info(:text, (desc ? "#{head}. #{desc}" : head) + pos)
      out = head
      out += ". #{desc}" if desc && PokeAccess::Verbosity.keep?(:ribbon, :full)
      PokeAccess::Verbosity.keep?(:ribbon, :medium) ? out + pos : out
    end

    # Speaks the ribbon grid's pick-up cursor (ribbonpresel) as reorder_poll does the moves: picked up, then
    # placed (queued behind the repainted cell) or cancelled with the back button.
    def self.ribbon_poll(scene)
      sel = PokeAccess.sprite(scene, "ribbonsel")
      pre = PokeAccess.sprite(scene, "ribbonpresel")
      return if sel.nil? || pre.nil?
      unless sel.visible
        @ribbon_carry = nil
        return
      end
      carrying = pre.visible ? true : false
      if carrying != @ribbon_carry
        prev = @ribbon_carry
        @ribbon_carry = carrying
        return if prev.nil?
        if carrying
          @ribbon_back = false
          PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:rb_picked), PokeAccess::I18n.t(:rb_picked_hint)), true)
        else
          PokeAccess.speak(PokeAccess::I18n.t(@ribbon_back ? :rb_cancel : :rb_placed), @ribbon_back)
        end
        return
      end
      @ribbon_back = true if carrying && (Input.trigger?(Input::B) rescue false)
    rescue StandardError
      nil
    end

    # Yields (name, pp, total_pp, type name) for each real move of a pokemon, under either era's names. The type
    # is the one the page draws: display_type where the move has it (Hidden Power's own type), else the plain one;
    # name and type pass through MoveInfo.painted.
    def self.each_real_move(pk)
      (pk.moves rescue []).each do |m|
        id = m ? PokeAccess::MoveInfo.id_of(m) : nil
        next unless PokeAccess::MoveInfo.real_id?(id)
        nm = (m.name rescue nil)
        nm = (PokeAccess::Data.move_name(id) rescue nil) if nm.nil? || nm.to_s.empty?
        nm = PokeAccess::I18n.t(:info_move) if nm.nil? || nm.to_s.empty?
        pp = (m.pp rescue nil)
        tot = PokeAccess.attr_of(m, :totalpp, :total_pp)
        ty = (PokeAccess::Data.type_name(m.respond_to?(:display_type) ? m.display_type(pk) : m.type) rescue nil)
        ty = (PokeAccess::Data.move_type_name(id) rescue nil) if ty.nil? || ty.to_s.empty?
        nm, ty = PokeAccess::MoveInfo.painted(m, nm.to_s, ty)
        yield(nm.to_s, pp, tot, ty)
      end
    end

    # The trainer memo as a page paints it: the memo heading and one sentence per painted line, or nil when
    # nothing was painted.
    def self.painted_memo(painted)
      lines = Array(painted).join("\n").split(/\r?\n/).map { |l| PokeAccess.clean(l).strip }.reject { |l| l.empty? }
      body = lines.map { |l| l =~ /[.!?:]\z/ ? l : "#{l}." }.join(" ")
      body.empty? ? nil : "#{PokeAccess::I18n.t(:sm_memo)}. #{body}"
    end

    # The summary header's icons: the ball; fainted, else the status, else active pokerus; cured pokerus, the
    # shiny star and the marks set. "" when the header draws none.
    def self.header_icons(pk)
      parts = []
      b = ball_name(pk)
      parts.push(PokeAccess::I18n.t(:sum_ball, :b => b)) if b
      st = (pk.status rescue nil)
      if (pk.hp rescue 1).to_i <= 0
        parts.push(PokeAccess::I18n.t(:pk_fainted))
      elsif st && st != 0 && st != :NONE
        sn = PokeAccess::Data.status_name(st)
        parts.push(PokeAccess::I18n.t(sn)) if sn && !sn.to_s.empty?
      elsif PokeAccess::Party.pokerus?(pk)
        parts.push(PokeAccess::I18n.t(:pk_pokerus))
      end
      parts.push(PokeAccess::I18n.t(:pk_pokerus_cured)) if pokerus_cured?(pk)
      parts.push(PokeAccess::Party.shiny_word(pk)) if PokeAccess::Party.shiny?(pk)
      marks = PokeAccess::Marking.shown(pk)
      parts.push(PokeAccess::I18n.t(:mk_list, :list => marks.join(", "))) unless marks.empty?
      parts.join(", ")
    rescue StandardError
      ""
    end

    # The name of a Pokemon's ball: modern poke_ball, or gen-6's ballused number turned into its item
    # (pbBallTypeToBall); nil if neither.
    def self.ball_name(pk)
      b = (pk.poke_ball rescue nil)
      if b.nil?
        used = (pk.ballused rescue nil)
        own = used.is_a?(Symbol) && !PokeAccess::Data.item_name(used).nil?
        b = own ? used : (used.nil? ? nil : (pbBallTypeToBall(used) rescue nil))
      end
      return nil if b.nil?
      n = (PokeAccess::Data.item_name(b) rescue nil)
      (n.nil? || n.to_s.empty?) ? nil : n.to_s
    end

    # Whether the Pokemon had pokerus and got over it (stage 2), which the header marks with an icon of its own.
    def self.pokerus_cured?(pk)
      (pk.pokerusStage rescue 0).to_i == 2
    end

    # Page one's trainer lines: original trainer, padded ID, experience and what the next level needs. "On loan"
    # and question marks with no trainer; no experience for a Shadow Pokemon (the caller adds heart_of).
    def self.trainer_facts(pk)
      out = []
      ot = (pk.owner.name rescue nil) || PokeAccess.attr_of(pk, :ot)
      id = (pk.owner.public_id rescue nil) || PokeAccess.attr_of(pk, :publicID)
      if ot.nil? || ot.to_s.empty?
        out.push(PokeAccess::I18n.t(:sum_ot, :name => PokeAccess::I18n.t(:sum_loaned)))
        out.push(PokeAccess::I18n.t(:sum_id, :id => PokeAccess::DexEntry.unknown_marks("?????")))
      else
        out.push(PokeAccess::I18n.t(:sum_ot, :name => ot))
        out.push(PokeAccess::I18n.t(:sum_id, :id => sprintf("%05d", id.to_i))) if id
      end
      return out if shadow?(pk)
      exp = (pk.exp rescue nil)
      out.push(PokeAccess::I18n.t(:sum_exp, :n => exp)) if exp
      left = exp_to_next(pk)
      out.push(PokeAccess::I18n.t(:sum_exp_next, :n => left)) if left
      out
    rescue StandardError
      []
    end

    # Whether a Pokemon is a Shadow Pokemon, under either era's question.
    def self.shadow?(pk)
      v = (pk.shadowPokemon? rescue nil)
      v = (pk.isShadow? rescue nil) if v.nil?
      v ? true : false
    end

    # The heart paragraph page one paints for a Shadow Pokemon, from the page's formatted paragraphs, or nil.
    def self.heart_of(pk, memo)
      return nil unless shadow?(pk)
      t = Array(memo).map { |m| PokeAccess.clean(m.to_s) }.reject { |m| m.empty? }.join(" ")
      t.empty? ? nil : t
    end

    # The held item as page one writes it: its name, or the word for none the page writes in its place. An item kept
    # as a symbol is named through the data: on Ruby 3 the symbol's own name is the id.
    def self.item_fact(pk)
      it = (pk.item rescue nil)
      named = !it.is_a?(Symbol) && it.respond_to?(:name)
      name = (it.nil? || it == 0) ? nil : (named ? (it.name rescue nil) : PokeAccess::Data.item_name(it))
      PokeAccess::I18n.t(:sum_item, :i => (name.nil? || name.to_s.empty?) ? PokeAccess::I18n.t(:sum_none) : name)
    end

    # The experience the next level still needs, asked of the growth rate each era keeps (GameData's own
    # object, gen-6's PBExperience table, or an engine's data provider where it has neither), or nil when it cannot
    # be asked. GameData's gives nil at the top level; the gen-6 page asks its table for the next level, which the
    # table holds at the top one (MAXLEVEL, raised by level caps), so there it paints what is left to the top, 0.
    def self.exp_to_next(pk)
      lvl = pk.level.to_i
      if pk.respond_to?(:growth_rate)
        max = (GameData::GrowthRate.max_level rescue (Settings::MAXIMUM_LEVEL rescue 100)).to_i
        return nil if lvl >= max
        return pk.growth_rate.minimum_exp_for_level(lvl + 1) - pk.exp.to_i
      end
      return PokeAccess::Data.optional(:exp_left, pk) unless defined?(PBExperience)
      PBExperience.pbGetStartExperience(lvl + 1, pk.growthrate) - pk.exp.to_i
    rescue StandardError
      nil
    end

    # The nature the stats page colours its labels by (a mint's where used), or nil: none for a Shadow Pokemon
    # past heart stage 3. A page that decides otherwise overrides this.
    def self.stats_nature(pk)
      return nil if shadow?(pk) && (pk.heartStage rescue 0).to_i > 3
      (pk.nature_for_stats rescue nil) || (pk.nature rescue nil)
    end

    # The stock gen-6 stats page's rows as [PBStats index, stat name key]: speed, index 3, painted last.
    STAT_ROWS = [[0, :st_hp], [1, :st_atk], [2, :st_def], [4, :st_spatk], [5, :st_spdef], [3, :st_speed]]

    # Each stat's EV and IV as an EV and IV page lists them, in its rows' order (STAT_ROWS unless its engine numbers
    # them otherwise); the page's title and what follows the rows are its game's.
    def self.eviv_rows(pk, rows = STAT_ROWS)
      rows.map do |i, key|
        PokeAccess::I18n.t(:sm_eviv_row, :stat => PokeAccess::I18n.t(key), :ev => pk.ev[i].to_i, :iv => pk.iv[i].to_i)
      end
    end

    # The stats the nature raises and lowers (the stats page colours their labels) as a sentence, or nil: from
    # stat_changes, gen-6's index (raised index / 5, lowered index % 5, in Atk, Def, Spe, SpA, SpD order), or a nature
    # symbol whose stats an engine's data provider knows.
    def self.nature_effect_line(pk)
      nat = stats_nature(pk)
      up = down = nil
      if nat.respond_to?(:stat_changes)
        nat.stat_changes.each do |stat, change|
          up = stat if change > 0
          down = stat if change < 0
        end
      elsif nat.is_a?(Integer)
        up = nat / 5 + 1
        down = nat % 5 + 1
        return nil if up == down
      elsif (pair = PokeAccess::Data.optional(:nature_stats, nat))
        up, down = pair
        return nil if up == down
      end
      return nil unless up && down
      PokeAccess::I18n.t(:sm_nature_effect, :up => PokeAccess::Data.stat_name(up), :down => PokeAccess::Data.stat_name(down))
    rescue StandardError
      nil
    end

    # The ability the stats page names, with its description only when the page painted it (the full one, or the
    # short one an engine's data provider gives); nil with no ability. A bare id (a number, or a symbol, which answers
    # name on Ruby 3 with the id itself) is named through the data.
    # param painted the strings the page painted; nil or empty when the page was not captured, which keeps it
    def self.ability_line(pk, painted = nil)
      ab = (pk.ability rescue nil)
      return nil if ab.nil? || ab == 0
      bare = ab.is_a?(Integer) || ab.is_a?(Symbol)
      id = bare ? ab : (ab.id rescue ab)
      name = (!bare && ab.respond_to?(:name)) ? ab.name : PokeAccess::Data.ability_name(id)
      return nil if name.nil? || name.to_s.empty?
      desc = (!bare && ab.respond_to?(:description)) ? ab.description : PokeAccess::Data.ability_description(id)
      desc = PokeAccess.clean(desc.to_s)
      unless painted.nil? || painted.empty?
        rows = painted.map { |r| PokeAccess.clean(r.to_s) }
        shown = [desc, PokeAccess.clean(PokeAccess::Data.optional(:ability_summary, id).to_s)]
        desc = shown.find { |d| !d.empty? && rows.include?(d) } || ""
      end
      desc.empty? ? PokeAccess::I18n.t(:sum_ability, :a => name) : PokeAccess::I18n.t(:sum_ability_desc, :a => name, :d => desc)
    rescue StandardError
      nil
    end

    # Lists a pokemon's moves with the type icon the page draws beside each and their pp, over each_real_move.
    def self.moves_text(pk)
      return nil unless pk && pk.moves
      out = []
      each_real_move(pk) do |nm, pp, tot, ty|
        parts = [[nm, :brief]]
        parts.push([PokeAccess::I18n.t(:mv_type, :t => ty), :medium]) if ty && !ty.to_s.empty?
        parts.push([PokeAccess::I18n.t(:mv_pp, :pp => pp, :tot => tot), :brief]) if pp && tot
        out.push(PokeAccess::Verbosity.line(:summary_move, parts, ". "))
      end
      out.empty? ? PokeAccess::I18n.t(:sm_no_moves) : PokeAccess::I18n.t(:sm_moves, :list => out.join(", "))
    rescue StandardError
      nil
    end

    # Whether this game's summary is a single redrawn page (set true by a profile with such a summary),
    # suppressing the generic per-page reads.
    def self.single_page; @single_page; end

    # Marks the summary as single-page (called from a game file).
    def self.single_page=(v); @single_page = v; end
  end
end

# Arms the egg page's capture under either class name: afresh on drawPage, the dispatcher, and on drawPageOne
# unless drawPage already did, so its header stays in (hooks on the nested drawPageOneEgg are skipped).
# say_egg_page takes it.
PokeAccess::Hooks.variants(["PokemonSummaryScene", "PokemonSummary_Scene"], :drawPageOne, "summary_egg") do |cname|
  a = PokeAccess::Hooks.before_hook(cname, :drawPageOne, :optional => true) do
    PokeAccess::PaintCapture.arm(:summary_egg) unless PokeAccess::PaintCapture.armed?(:summary_egg)
  end
  b = PokeAccess::Hooks.before_hook(cname, :drawPage, :optional => true) { PokeAccess::PaintCapture.arm(:summary_egg) }
  a || b
end

# Entering the move cursor or the ribbon grid forgets the page, so the redraw that ends them is read again.
PokeAccess::Engine.scene_classes("PokemonSummary_Scene", "PokemonSummaryScene").each do |cn|
  %w[pbMoveSelection pbRibbonSelection].each do |m|
    PokeAccess::Hooks.before_hook(cn, m.to_sym, :optional => true) { |s, _a| PokeAccess::Summary.forget_page(s) }
  end
end
