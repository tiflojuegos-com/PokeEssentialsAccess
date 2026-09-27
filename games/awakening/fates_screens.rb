# Three Fates screens with no Essentials window: EquipScreen (talismans, @selected_index over @talismans),
# BallSelectorInterface (the in-battle ball picker, @ball_list and @ball_counts) and Glosario_Personajes (the
# character glossary, @index within page @pagina_actual of @total_paginas).
module PokeAccess
  module AwakeningFates
    # The focused talisman: its name and description (the info key keeps it when verbosity drops it), or for a
    # locked one the screen's locked line instead.
    def self.talisman(scene)
      idx = PokeAccess.ivar(scene, :@selected_index)
      list = PokeAccess.ivar(scene, :@talismans)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      t = list[idx]
      return unless t.is_a?(Hash)
      open = (scene.unlocked?(t[:symbol]) rescue true)
      PokeAccess::Cursor.announce(scene, :awk_talisman, [idx, open ? true : false], true) do
        name = PokeAccess.clean(t[:name].to_s)
        head = PokeAccess::Verbosity.list_entry(name, idx + 1, list.length)
        body = open ? PokeAccess.clean(t[:description].to_s) : locked_talisman(t)
        PokeAccess::Info.set_info(:text, body.empty? ? name : [name, body].join(". "))
        body = "" if open && !PokeAccess::Verbosity.descriptions?
        body.empty? ? head : [head, body].join(". ")
      end
    rescue StandardError
      nil
    end

    # The locked line: the label, the requirement and the progress, from the game's own requirement table.
    def self.locked_talisman(t)
      parts = [PokeAccess::I18n.t(:awk_talisman_locked)]
      req = (::TALISMAN_REQUIREMENTS[t[:symbol]] rescue nil)
      return parts[0] unless req.is_a?(Hash)
      d = PokeAccess.clean(req[:description].to_s)
      parts.push(PokeAccess::I18n.t(:awk_talisman_req, :req => d)) unless d.empty?
      pct = (req[:progress].call rescue nil)
      parts.push(PokeAccess::I18n.t(:awk_talisman_progress, :n => pct.to_i)) unless pct.nil?
      parts.push(PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:awk_talisman_ready), nil, true)) if pct && pct.to_i >= 100 && PokeAccess::Verbosity.hints?
      parts.join(". ")
    rescue StandardError
      PokeAccess::I18n.t(:awk_talisman_locked)
    end

    # Said as the talisman screen opens: the cursed energy (variable 399) and the talisman in each of the two
    # slots (variables 397 and 398), or empty.
    def self.equip_summary(scene)
      parts = [PokeAccess::I18n.t(:awk_energy, :n => ($game_variables[399] || 0).to_i)]
      list = PokeAccess.ivar(scene, :@talismans) || []
      [397, 398].each_with_index do |var, i|
        id = ($game_variables[var] || 0).to_i
        t = list.find { |tal| tal.is_a?(Hash) && tal[:id] == id }
        on = t && id != 0 && (scene.unlocked?(t[:symbol]) rescue false)
        name = on ? PokeAccess.clean(t[:name].to_s) : PokeAccess::I18n.t(:awk_slot_empty)
        parts.push(PokeAccess::I18n.t(:awk_slot, :n => i + 1, :name => name))
      end
      PokeAccess.speak(parts.join(". "), false)
    rescue StandardError
      nil
    end

    # The lore window, drawn where no capture sees it: the whole lore as it opens, then at each scroll step only
    # the lines it brings into view.
    def self.lore(scene)
      t = (scene.send(:selected_talisman) rescue nil)
      return unless t.is_a?(Hash)
      raw = (t[:lore] || "Sin información de lore.").to_s
      scroll = PokeAccess.ivar(scene, :@info_scroll).to_i
      sel = PokeAccess.ivar(scene, :@selected_index)
      prev = PokeAccess::Cursor.current(scene, :awk_lore)
      return unless PokeAccess::Cursor.changed?(scene, :awk_lore, [sel, scroll])
      if @lore_opening
        PokeAccess.speak(PokeAccess.clean(raw), true)
        return
      end
      bmp = (PokeAccess.sprite(scene, "info_window").bitmap rescue nil)
      lines = bmp ? (scene.send(:wrap_text, bmp, raw, bmp.width - 20) rescue nil) : nil
      rows = PokeAccess.ivar(scene, :@info_window_height).to_i / 22
      seen = (prev.is_a?(Array) && prev[0] == sel) ? (prev[1].to_i...(prev[1].to_i + rows)).to_a : []
      shown = lines.is_a?(Array) ? (scroll...(scroll + rows)).reject { |i| seen.include?(i) }.map { |i| lines[i] }.compact : []
      t2 = PokeAccess.clean(shown.join(" "))
      PokeAccess.speak(t2, true) unless t2.empty?
    rescue StandardError
      nil
    end

    def self.lore_opening(on); @lore_opening = on; end

    # Voices the focused ball and how many are left, and in full the description painted under it, which the info
    # key keeps.
    def self.ball(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@ball_list)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      counts = PokeAccess.ivar(scene, :@ball_counts)
      PokeAccess::Cursor.announce(scene, :awk_ball, idx, true) do
        name = (PokeAccess::Data.item_name(list[idx]) || list[idx].to_s)
        n = (counts.is_a?(Array) ? counts[idx] : nil)
        head = n ? PokeAccess::I18n.t(:awk_ball, :name => name, :n => n.to_i) : name.to_s
        desc = list[idx] ? PokeAccess.clean(PokeAccess::Data.item_description(list[idx]).to_s) : ""
        PokeAccess::Info.set_info(:item, list[idx]) if list[idx]
        (desc.empty? || !PokeAccess::Verbosity.descriptions?) ? head : "#{head}. #{desc}"
      end
    rescue StandardError
      nil
    end

    # The focused glossary entry (entry_label, so a locked one stays locked) and, from medium, its page if paged.
    def self.glossary(scene)
      idx = PokeAccess.ivar(scene, :@index)
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      return unless idx.is_a?(Integer) && names.is_a?(Array)
      per = (Glosario_Personajes::OPCIONES_POR_PAGINA rescue 10)
      page = PokeAccess.ivar(scene, :@pagina_actual).to_i
      real = (page * per) + idx
      return unless real >= 0 && real < names.length
      PokeAccess::Cursor.announce(scene, :awk_glos, real, true) do
        name = entry_label(scene, names[real])
        total = PokeAccess.ivar(scene, :@total_paginas).to_i
        if total > 1 && PokeAccess::Verbosity.keep?(:positions, :medium)
          PokeAccess::I18n.t(:awk_glos_page, :name => name, :page => page + 1, :pages => total)
        else
          name
        end
      end
    rescue StandardError
      nil
    end

    # A glossary row as the screen draws it: the translated label when the story has unlocked the character,
    # and the locked word otherwise.
    def self.entry_label(scene, raw)
      key = raw.to_s.downcase.gsub(/\s+/, "")
      unlocked = key.empty? || (scene.send(:glosario_historia)[key.to_sym] rescue true)
      return PokeAccess::I18n.t(:awk_glos_locked) unless unlocked
      shown = (Glosario_Personajes::TRADUCCIONES_PERSONAJES[raw.to_s] rescue nil) || raw.to_s
      PokeAccess.clean(shown)
    rescue StandardError
      PokeAccess.clean(raw.to_s)
    end

    # The biography the glossary opens, page by page: its page number is a local, read off the "n/m" stamp drawn
    # through pbDrawOutlineText while the list's overlay is hidden (the list paints the same stamp).
    @open = nil
    @page = nil

    def self.watch(scene, name); @open = [scene, name.to_s]; @page = nil; end
    def self.unwatch; @open = nil; @page = nil; end

    # Speaks a biography page when a drawn stamp names a new one, the first page shown of a character with the
    # headings above its text; runs on every pbDrawOutlineText.
    def self.on_draw(text)
      return unless @open
      scene, name = @open
      return unless text.to_s =~ /(\d+)\s*\/\s*(\d+)\s*\z/
      i = $1.to_i - 1
      return if i == @page
      return unless (PokeAccess.ivar(scene, :@overlay).visible == false rescue false)
      first = @page.nil?
      @page = i
      t = biography(scene, name, i, first)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # One page of a biography: the character, with heads its painted affinity and place, which page this is, and
    # the text on it, its sibling placeholder named as the page paints it.
    def self.biography(scene, name, page, heads = false)
      data = (PokeAccess.ivar(scene, :@secciones)[name.to_s] rescue nil)
      pages = data.is_a?(Hash) ? data["text"] : nil
      return nil unless pages.is_a?(Array) && !pages.empty?
      i = page.to_i
      i = 0 if i < 0 || i >= pages.length
      text = PokeAccess.clean(PokeAccess::AwakeningStoryGlossary.sibling(pages[i].to_s))
      return nil if text.empty?
      label = entry_label(scene, name)
      label = ([label] + bio_heads(data)).join(". ") if heads
      return "#{label}. #{text}" unless PokeAccess::Verbosity.keep?(:positions, :medium)
      PokeAccess::I18n.t(:awk_glos_bio, :name => label, :page => i + 1, :pages => pages.length, :text => text)
    rescue StandardError
      nil
    end

    # The headings a biography paints above its text, affinity and place, each only when the entry has it.
    def self.bio_heads(data)
      [[:awk_glos_aff, "afinidad"], [:awk_glos_loc, "localidad"]].map do |key, field|
        v = PokeAccess.clean(data[field].to_s)
        v.empty? ? nil : PokeAccess::I18n.t(key, :name => v)
      end.compact
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("EquipScreen", :update_description) { |s, _r, _a| PokeAccess::AwakeningFates.talisman(s) }
  after("BallSelectorInterface", :update_display) { |s, _r, _a| PokeAccess::AwakeningFates.ball(s) }
  after("Glosario_Personajes", :mover_cursor) { |s, _r, _a| PokeAccess::AwakeningFates.glossary(s) }
  # dibujar_lista too, for the entry focused as the screen opens; the announcement is deduped.
  after("Glosario_Personajes", :dibujar_lista) { |s, _r, _a| PokeAccess::AwakeningFates.glossary(s) }
  # mostrar_texto is the biography's loop (args[0] the character), re-entered for each next character.
  around("Glosario_Personajes", :mostrar_texto) do |s, nxt, args|
    PokeAccess::AwakeningFates.watch(s, args[0])
    begin; nxt.call; ensure; PokeAccess::AwakeningFates.unwatch; end
  end
  # Leaving a biography redraws the list inside its loop: the watch goes first, so that stamp is no page turn.
  before("Glosario_Personajes", :dibujar_lista) { |_s, _a| PokeAccess::AwakeningFates.unwatch }
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::AwakeningFates.on_draw(args[5]) }
end

# The talisman screen's opening summary, and its lore window: read whole on each opening, then by scroll step; the
# talisman leaves the info key when the screen ends.
PokeAccess::Game.define("awakening") do
  before("EquipScreen", :main_loop, :optional => true) { |s, _a| PokeAccess::AwakeningFates.equip_summary(s) }
  around("EquipScreen", :open_lore_window, :optional => true) do |scene, nxt, _a|
    PokeAccess::Cursor.reset(scene, :awk_lore)
    PokeAccess::AwakeningFates.lore_opening(true)
    begin; nxt.call; ensure; PokeAccess::AwakeningFates.lore_opening(false); end
  end
  after("EquipScreen", :update_lore_window, :optional => true) { |s, _r, _a| PokeAccess::AwakeningFates.lore(s) }
  after("EquipScreen", :pbEndScreen, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
end
