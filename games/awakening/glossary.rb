module PokeAccess
  # The diary glossary's tab menu (Scene_Glosario, @commands and @index, a blocking loop inside main).
  AwakeningGlossary = SceneWatcher.reader("Scene_Glosario", :main, :aw_glossary) do |s|
    idx = PokeAccess.ivar(s, :@index)
    cmds = PokeAccess.ivar(s, :@commands)
    ok = idx && cmds.is_a?(Array) && idx >= 0 && idx < cmds.length
    ok ? [idx, cmds[idx].to_s] : nil
  end

  # The Historia tab: chapters (Glosario_Historia), each a paged list of sections (Glosario_Historia_Secciones)
  # with its text. Locked rows are read as the screen prints them, never by the name behind.
  module AwakeningStoryGlossary
    # The trailing "n/m" of the page stamp both of these screens redraw every frame.
    REGEX_PAGE = /(\d+)\s*\/\s*(\d+)\s*\z/

    # The focused chapter (deduped), the locked word for a locked one.
    def self.chapter(scene)
      cmds = PokeAccess.ivar(scene, :@commands)
      i = PokeAccess.ivar(scene, :@index)
      return unless cmds.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < cmds.length
      row = cmds[i]
      PokeAccess::Cursor.announce(scene, :awk_hist_chapter, i, true) do
        locked = row.is_a?(Array) && !row[1]
        name = locked ? PokeAccess::I18n.t(:awk_glos_locked) :
                        PokeAccess.clean((row.is_a?(Array) ? row[0] : row).to_s)
        name.empty? ? nil : PokeAccess::Verbosity.list_entry(name, i + 1, cmds.length)
      end
    rescue StandardError
      nil
    end

    # The focused section of a chapter; its index is the page offset plus the cursor.
    def self.section(scene)
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      i = PokeAccess.ivar(scene, :@index)
      return unless names.is_a?(Array) && i.is_a?(Integer)
      per = (Glosario_Historia_Secciones::OPCIONES_POR_PAGINA rescue 10)
      real = (PokeAccess.ivar(scene, :@pagina_actual).to_i * per) + i
      return unless real >= 0 && real < names.length
      PokeAccess::Cursor.announce(scene, :awk_hist_section, real, true) do
        PokeAccess::Verbosity.list_entry(section_label(scene, names[real]), real + 1, names.length)
      end
    rescue StandardError
      nil
    end

    # A section row as the screen draws it: the translated title once unlocked, the locked word otherwise.
    def self.section_label(scene, raw)
      key = raw.to_s.downcase.gsub(/\s+/, "")
      unlocked = key.empty? || (scene.send(:glosario_historia)[key.to_sym] rescue true)
      return PokeAccess::I18n.t(:awk_glos_locked) unless unlocked
      shown = (Glosario_Historia_Secciones::TRADUCCIONES_NOMBRES[raw.to_s] rescue nil) || raw.to_s
      PokeAccess.clean(shown)
    rescue StandardError
      PokeAccess.clean(raw.to_s)
    end

    # A section's text, page by page: the section and page are locals of mostrar_texto's loop, read off its
    # drawn title and "n/m" stamp (the argument goes stale when paging past either end) while @cursor is hidden.
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
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # The raw section key behind the drawn title (the first text drawn after the last page stamp).
    def self.section_for(scene, title)
      return nil if title.nil? || title.empty?
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      return nil unless names.is_a?(Array)
      names.detect { |raw| section_label(scene, raw) == title }
    rescue StandardError
      nil
    end

    # A diary page's text as mostrar_texto paints it: its "siblingA" placeholder named for the sibling of the one
    # playing (Liam under switch 80, Lana under switch 81).
    def self.sibling(text)
      return text.gsub("siblingA", "Liam") if ($game_switches[80] rescue false)
      return text.gsub("siblingA", "Lana") if ($game_switches[81] rescue false)
      text
    end

    # One page of a section: the title, which page this is, and the text on it.
    def self.body(scene, name, page)
      pages = (PokeAccess.ivar(scene, :@secciones)[name.to_s] rescue nil)
      return nil unless pages.is_a?(Array) && !pages.empty?
      i = page.to_i
      i = 0 if i < 0 || i >= pages.length
      text = PokeAccess.clean(sibling(pages[i].to_s))
      return nil if text.empty?
      label = section_label(scene, name)
      return "#{label}. #{text}" unless PokeAccess::Verbosity.keep?(:positions, :medium)
      PokeAccess::I18n.t(:awk_glos_bio, :name => label, :page => i + 1, :pages => pages.length, :text => text)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  # The tab menu redraws itself on every move and when a tab closes back onto it: the tab is said again.
  after("Scene_Glosario", :refresh) do |_s, _r, _a|
    PokeAccess::Cursor.reset(PokeAccess::AwakeningGlossary, :aw_glossary)
  end
  # draw_commands (on open and on return) and update_cursor, not update: update runs the whole sections screen
  # inside itself, and an after-hook's guard would drop the section readers.
  after("Glosario_Historia", :draw_commands) do |s, _r, _a|
    PokeAccess::Cursor.reset(s, :awk_hist_chapter)
    PokeAccess::AwakeningStoryGlossary.chapter(s)
  end
  after("Glosario_Historia", :update_cursor) { |s, _r, _a| PokeAccess::AwakeningStoryGlossary.chapter(s) }
  after("Glosario_Historia_Secciones", :mover_cursor) { |s, _r, _a| PokeAccess::AwakeningStoryGlossary.section(s) }
  # dibujar_lista too, for the read on open (mover_cursor only runs on an arrow).
  after("Glosario_Historia_Secciones", :dibujar_lista) { |s, _r, _a| PokeAccess::AwakeningStoryGlossary.section(s) }
  # mostrar_texto is the section's loop; the list redrawn inside it on leaving drops the watch first (below).
  around("Glosario_Historia_Secciones", :mostrar_texto) do |s, nxt, _args|
    PokeAccess::AwakeningStoryGlossary.watch(s)
    begin; nxt.call; ensure; PokeAccess::AwakeningStoryGlossary.unwatch; end
  end
  before("Glosario_Historia_Secciones", :dibujar_lista) { |_s, _a| PokeAccess::AwakeningStoryGlossary.unwatch }
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::AwakeningStoryGlossary.on_draw(args[5]) }
end
