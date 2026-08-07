module PokeAccess
  # Awakening's diary glossary (Scene_Glosario in "Diario de Liam Lana"): a sprite tab menu with @commands
  # (Historia, Personajes) and an @index cursor moved by up/down in a blocking loop INSIDE main -- so it is
  # never $scene. SceneWatcher.reader holds the live instance and speaks the focused tab name (deduped).
  AwakeningGlossary = SceneWatcher.reader("Scene_Glosario", :main, :aw_glossary) do |s|
    idx = PokeAccess.ivar(s, :@index)
    cmds = PokeAccess.ivar(s, :@commands)
    ok = idx && cmds.is_a?(Array) && idx >= 0 && idx < cmds.length
    ok ? [idx, cmds[idx].to_s] : nil
  end

  # Everything BEHIND the Historia tab, which was silent end to end: nine chapters (Glosario_Historia), each
  # opening a paged list of sections (Glosario_Historia_Secciones), each opening its text. The tab reader
  # above named the tab and nothing past it.
  #
  # Both lists hide what the story has not unlocked, and each does it its own way: the chapter list stores
  # "--------" in the row itself, the section list decides while drawing. Both are read the way the screen
  # prints them, never from the name behind the placeholder -- these are chapter titles of a story the
  # player has not reached.
  module AwakeningStoryGlossary
    # The trailing "n/m" of the page stamp both of these screens redraw every frame.
    REGEX_PAGE = /(\d+)\s*\/\s*(\d+)\s*\z/

    # The focused chapter. update runs every frame of the chapter list's loop, so the dedup is what turns it
    # into one line per move -- and what gives the opening read, since nothing else announces on entry.
    def self.chapter(scene)
      cmds = PokeAccess.ivar(scene, :@commands)
      i = PokeAccess.ivar(scene, :@index)
      return unless cmds.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < cmds.length
      row = cmds[i]
      PokeAccess::Cursor.announce(scene, :awk_hist_chapter, i, true) do
        locked = row.is_a?(Array) && !row[1]
        name = locked ? PokeAccess::I18n.t(:awk_glos_locked) :
                        PokeAccess.clean((row.is_a?(Array) ? row[0] : row).to_s).to_s.strip
        name.empty? ? nil : PokeAccess::I18n.t(:list_entry, :name => name, :n => i + 1, :tot => cmds.length)
      end
    rescue StandardError
      nil
    end

    # The focused section within a chapter. Paged two per row, so the real index is the page offset plus the
    # cursor -- the same layout the character glossary uses.
    def self.section(scene)
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      i = PokeAccess.ivar(scene, :@index)
      return unless names.is_a?(Array) && i.is_a?(Integer)
      per = (Glosario_Historia_Secciones::OPCIONES_POR_PAGINA rescue 10)
      real = (PokeAccess.ivar(scene, :@pagina_actual).to_i * per) + i
      return unless real >= 0 && real < names.length
      PokeAccess::Cursor.announce(scene, :awk_hist_section, real, true) do
        PokeAccess::I18n.t(:list_entry, :name => section_label(scene, names[real]),
                           :n => real + 1, :tot => names.length)
      end
    rescue StandardError
      nil
    end

    # A section row as the screen draws it: the translated title once unlocked, the locked word otherwise.
    def self.section_label(scene, raw)
      key = raw.to_s.downcase.gsub(/\s+/, "").to_sym
      return PokeAccess::I18n.t(:awk_glos_locked) unless (scene.send(:glosario_historia)[key] rescue true)
      shown = (Glosario_Historia_Secciones::TRADUCCIONES_NOMBRES[raw.to_s] rescue nil) || raw.to_s
      PokeAccess.clean(shown).to_s.strip
    rescue StandardError
      PokeAccess.clean(raw.to_s).to_s.strip
    end

    # A section's text, page by page. Both the page number and the section being shown are LOCALS of
    # mostrar_texto's loop, so both are read off what the loop DRAWS every frame: the title first, then the
    # body, then a "Pagina n/m" stamp. The screen's own answer, which cannot drift from what is displayed.
    #
    # Reading the section from the title rather than from the method's argument is not belt and braces. This
    # copy does NOT recurse to move between sections the way the character glossary does: paging past either
    # end REASSIGNS its own local (nombre = prev_section / next_section) and keeps looping, so the argument
    # the hook was entered with goes stale the moment the player crosses a boundary -- and the reader would
    # announce the previous section's title over the next section's text.
    #
    # The cursor is hidden for exactly as long as a section is open, which is what keeps the LIST's identical
    # page stamp from being taken for a page turn.
    @open = nil
    @title = nil
    @page = nil

    def self.watch(scene); @open = scene; @title = nil; @page = nil; end
    def self.unwatch; @open = nil; @title = nil; @page = nil; end

    def self.on_draw(text)
      return unless @open
      s = text.to_s
      unless s =~ REGEX_PAGE
        @title = s.strip if @title.nil? && !s.strip.empty?
        return
      end
      i = $1.to_i - 1
      title = @title
      @title = nil
      return if i == @page
      return unless (PokeAccess.ivar(@open, :@cursor).visible == false rescue false)
      name = section_for(@open, title)
      return unless name
      @page = i
      t = body(@open, name, i)
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    rescue StandardError
      nil
    end

    # The raw section key behind the title the loop just drew. The title is the FIRST thing it draws each
    # frame, so it is whatever was remembered since the last page stamp.
    def self.section_for(scene, title)
      return nil if title.nil? || title.empty?
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      return nil unless names.is_a?(Array)
      names.detect { |raw| section_label(scene, raw) == title }
    rescue StandardError
      nil
    end

    # One page of a section: the title, which page this is, and the text on it.
    def self.body(scene, name, page)
      pages = (PokeAccess.ivar(scene, :@secciones)[name.to_s] rescue nil)
      return nil unless pages.is_a?(Array) && !pages.empty?
      i = page.to_i
      i = 0 if i < 0 || i >= pages.length
      text = PokeAccess.clean(pages[i].to_s).to_s.strip
      return nil if text.empty?
      PokeAccess::I18n.t(:awk_glos_bio, :name => section_label(scene, name),
                         :page => i + 1, :pages => pages.length, :text => text)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  # NOT update. Pressing the confirm key there runs the WHOLE sections screen inside that one call
  # (Glosario_Historia_Secciones.new is synchronous), and an after-hook makes the engine run the original
  # under the reentrancy guard -- which then drops every hook nested inside it, so the three section readers
  # below never fired and the entire Historia branch stayed as mute as before. draw_commands and
  # update_cursor are the two calls that mean "the chapter list is showing something new": the first on open
  # and on the way back from a section, the second on every arrow.
  after("Glosario_Historia", :draw_commands) do |s, _r, _a|
    PokeAccess::Cursor.reset(s, :awk_hist_chapter)
    PokeAccess::AwakeningStoryGlossary.chapter(s)
  end
  after("Glosario_Historia", :update_cursor) { |s, _r, _a| PokeAccess::AwakeningStoryGlossary.chapter(s) }
  after("Glosario_Historia_Secciones", :mover_cursor) { |s, _r, _a| PokeAccess::AwakeningStoryGlossary.section(s) }
  # dibujar_lista as well, for the read on open: the constructor draws the list and then blocks, and
  # mover_cursor only runs on an arrow.
  after("Glosario_Historia_Secciones", :dibujar_lista) { |s, _r, _a| PokeAccess::AwakeningStoryGlossary.section(s) }
  # Held rather than hooked after: mostrar_texto IS the section's loop, and the section it is showing is its
  # argument. Leaving it redraws the list from INSIDE the loop, so the watch is dropped when that happens --
  # otherwise the list's own page stamp would be read as one last page turn on the way out.
  around("Glosario_Historia_Secciones", :mostrar_texto) do |s, nxt, _args|
    PokeAccess::AwakeningStoryGlossary.watch(s)
    begin; nxt.call; ensure; PokeAccess::AwakeningStoryGlossary.unwatch; end
  end
  before("Glosario_Historia_Secciones", :dibujar_lista) { |_s, _a| PokeAccess::AwakeningStoryGlossary.unwatch }
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::AwakeningStoryGlossary.on_draw(args[5]) }
end
