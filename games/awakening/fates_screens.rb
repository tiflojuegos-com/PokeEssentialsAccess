# Three more Fates screens with no Essentials window behind them.
#
# EquipScreen (0309) equips cursed-energy talismans: @selected_index walks @talismans, each a hash with
# :name, :description and :lore. The description is what the player needs to choose; the lore is flavour and
# is left out so the line stays short while browsing.
#
# BallSelectorInterface (0305) is the in-battle quick ball picker (key R): a row of ball icons with a count
# under each, kept in the parallel arrays @ball_list (item ids) and @ball_counts.
#
# Glosario_Personajes (0303) is the character glossary reached from the diary. Its entries are the keys of
# @nombres_secciones, laid out two per row across pages, with @index the focus inside the current page and
# @pagina_actual / @total_paginas the paging -- so the reader gives the entry plus which page it is on.
module PokeAccess
  module AwakeningFates
    # Voices the focused talisman: its name and what it does, or -- while it is still locked -- what the
    # screen puts there instead.
    #
    # The description was spoken unconditionally and the screen only paints it once the talisman is unlocked
    # (update_description branches on unlocked?); a locked one shows the words "Talisman bloqueado", the
    # requirement and a progress percentage. So the reader handed out the effect the screen is withholding
    # and never said the two things the player is there to find out: that it is locked, and how close it is.
    def self.talisman(scene)
      idx = PokeAccess.ivar(scene, :@selected_index)
      list = PokeAccess.ivar(scene, :@talismans)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      t = list[idx]
      return unless t.is_a?(Hash)
      PokeAccess::Cursor.announce(scene, :awk_talisman, idx, true) do
        name = PokeAccess.clean(t[:name].to_s).to_s.strip
        head = PokeAccess::I18n.t(:list_entry, :name => name, :n => idx + 1, :tot => list.length)
        open = (scene.unlocked?(t[:symbol]) rescue true)
        body = open ? PokeAccess.clean(t[:description].to_s).to_s.strip : locked_talisman(t)
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
      d = PokeAccess.clean(req[:description].to_s).to_s.strip
      parts.push(PokeAccess::I18n.t(:awk_talisman_req, :req => d)) unless d.empty?
      pct = (req[:progress].call rescue nil)
      parts.push(PokeAccess::I18n.t(:awk_talisman_progress, :n => pct.to_i)) unless pct.nil?
      parts.join(". ")
    rescue StandardError
      PokeAccess::I18n.t(:awk_talisman_locked)
    end

    # Voices the focused ball and how many are left.
    def self.ball(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@ball_list)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      counts = PokeAccess.ivar(scene, :@ball_counts)
      PokeAccess::Cursor.announce(scene, :awk_ball, idx, true) do
        name = (PokeAccess::Data.item_name(list[idx]) || list[idx].to_s)
        n = (counts.is_a?(Array) ? counts[idx] : nil)
        n ? PokeAccess::I18n.t(:awk_ball, :name => name, :n => n.to_i) : name.to_s
      end
    rescue StandardError
      nil
    end

    # Voices the focused glossary entry and the page it sits on.
    #
    # The name goes through the screen's own gate: an entry the player has not unlocked is drawn as "------"
    # and reading the real name behind it was a spoiler -- the glossary is a list of characters the story has
    # yet to introduce. The label table the screen prints from is consulted for the same reason.
    def self.glossary(scene)
      idx = PokeAccess.ivar(scene, :@index)
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      return unless idx.is_a?(Integer) && names.is_a?(Array)
      per = (Glosario_Personajes::OPCIONES_POR_PAGINA rescue 8)
      page = PokeAccess.ivar(scene, :@pagina_actual).to_i
      real = (page * per) + idx
      return unless real >= 0 && real < names.length
      PokeAccess::Cursor.announce(scene, :awk_glos, real, true) do
        name = entry_label(scene, names[real])
        total = PokeAccess.ivar(scene, :@total_paginas).to_i
        if total > 1
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
      key = raw.to_s.downcase.gsub(/\s+/, "").to_sym
      unlocked = (scene.send(:glosario_historia)[key] rescue true)
      return PokeAccess::I18n.t(:awk_glos_locked) unless unlocked
      shown = (Glosario_Personajes::TRADUCCIONES_PERSONAJES[raw.to_s] rescue nil) || raw.to_s
      PokeAccess.clean(shown).to_s.strip
    rescue StandardError
      PokeAccess.clean(raw.to_s).to_s.strip
    end

    # The biography the glossary opens on USE, page by page.
    #
    # The page number is a LOCAL of mostrar_texto's own loop, with no ivar behind it and no per-page method
    # to bind to -- so the page is read off the ONE thing the loop puts on screen every frame that names it:
    # the "Pagina n/m" stamp it draws through pbDrawOutlineText. That is the screen's own answer, so it
    # cannot drift from what is displayed.
    #
    # The scene is held while the biography is up so the stamp of the LIST behind it, which is drawn to the
    # same corner in the same words, cannot be mistaken for a page turn: the list's overlay is hidden for
    # exactly as long as a biography is open, and that is what the gate below tests.
    @open = nil
    @page = nil

    def self.watch(scene, name); @open = [scene, name.to_s]; @page = nil; end
    def self.unwatch; @open = nil; @page = nil; end

    # Called for every pbDrawOutlineText the game makes. Cheap by design: a string compare that fails on the
    # first character for all but one draw per frame.
    def self.on_draw(text)
      return unless @open
      scene, name = @open
      return unless text.to_s =~ /(\d+)\s*\/\s*(\d+)\s*\z/
      i = $1.to_i - 1
      return if i == @page
      return unless (PokeAccess.ivar(scene, :@overlay).visible == false rescue false)
      @page = i
      t = biography(scene, name, i)
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    rescue StandardError
      nil
    end

    # One page of a biography: the character, which page this is, and the text on it.
    def self.biography(scene, name, page)
      data = (PokeAccess.ivar(scene, :@secciones)[name.to_s] rescue nil)
      pages = data.is_a?(Hash) ? data["text"] : nil
      return nil unless pages.is_a?(Array) && !pages.empty?
      i = page.to_i
      i = 0 if i < 0 || i >= pages.length
      text = PokeAccess.clean(pages[i].to_s).to_s.strip
      return nil if text.empty?
      PokeAccess::I18n.t(:awk_glos_bio, :name => entry_label(scene, name),
                         :page => i + 1, :pages => pages.length, :text => text)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("EquipScreen", :update_description) { |s, _r, _a| PokeAccess::AwakeningFates.talisman(s) }
  after("BallSelectorInterface", :update_display) { |s, _r, _a| PokeAccess::AwakeningFates.ball(s) }
  after("Glosario_Personajes", :mover_cursor) { |s, _r, _a| PokeAccess::AwakeningFates.glossary(s) }
  # dibujar_lista as well as mover_cursor: the constructor draws the list and then blocks, and mover_cursor
  # only runs on an arrow, so the entry focused when the screen OPENED was never announced. Both go through
  # the same deduped announcement, so the redraw a cursor move triggers does not repeat it.
  after("Glosario_Personajes", :dibujar_lista) { |s, _r, _a| PokeAccess::AwakeningFates.glossary(s) }
  # Held rather than hooked after: mostrar_texto IS the biography's loop. The character and the opening page
  # are its ARGUMENTS, and it calls itself to move to the next character, so each re-entry re-arms the watch
  # with the new name.
  around("Glosario_Personajes", :mostrar_texto) do |s, nxt, args|
    PokeAccess::AwakeningFates.watch(s, args[0])
    begin; nxt.call; ensure; PokeAccess::AwakeningFates.unwatch; end
  end
  # Leaving a biography redraws the list from INSIDE the loop, before the overlay comes back: the watch is
  # dropped there so the list's own page stamp is not read as one last page turn on the way out.
  before("Glosario_Personajes", :dibujar_lista) { |_s, _a| PokeAccess::AwakeningFates.unwatch }
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::AwakeningFates.on_draw(args[5]) }
end
