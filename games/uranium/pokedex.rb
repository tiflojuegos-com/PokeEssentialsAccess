module PokeAccess
  # Uranium's Black/White Pokedex: the species list (Window_Pokedex over Window_DrawableCommandDex, not a
  # Window_DrawableCommand), read through the core's Window_Pokedex row and said again when the list takes the focus
  # back; the forms page, which paints its counters on opening and a form's name only when C cycles to it; the entry
  # page and the registration page after a capture, headed by a caption the core would take for the name; and the
  # search, whose rows paint their label apart from the value.
  module UraniumDex
    # The search rows' labels, painted by Window_ComplexCommandPokemon#drawItem beside each value (row 6 is START).
    SEARCH_LABELS = { 1 => "NAME", 2 => "COLOR", 3 => "TYPE 1", 4 => "TYPE 2", 5 => "ORDER" }

    # The captions the entry pages paint at their top: the info page's and the registration page's.
    HEADERS = ["INFO", "Pokédex registration completed."]

    # Says the focused species once per change of row or of the list under it, while the list has the focus.
    def self.update(win)
      return unless win.active
      idx = win.index
      cmds = PokeAccess.ivar(win, :@commands)
      return unless idx && idx >= 0 && cmds.is_a?(Array) && idx < cmds.length
      PokeAccess::Cursor.announce(win, :ura_dex, [idx, cmds[idx]], true, false) { PokeAccess::Menus.focused_text(win) }
    end

    # Forgets the species list's last read, so its focus is said again (queued) when the list is back on screen.
    def self.refocus(scene)
      PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "pokedex"), :ura_dex)
    end

    # Runs the forms page's opening and says its painted lines (title, forms seen, shiny seen), queued.
    def self.forms_opened
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      t = PokeAccess::PaintCapture.lines(pairs).join(". ")
      PokeAccess.speak(t, false) unless t.empty?
      ret
    end

    # Runs a form redraw and says what it paints: the species, then the form.
    def self.form_shown
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      t = pairs.map { |p| PokeAccess.clean(p[0].to_s) }.reject { |s| s.empty? }.join(", ")
      PokeAccess.speak(t, true) unless t.empty?
      ret
    end

    # An entry page's capture without its caption, each painted line whole (the number beside the name, a value
    # beside its label), as capture rows placed at the line's first row.
    def self.entry_pairs(pairs)
      heads = HEADERS.map { |h| PokeAccess.clean(_INTL(h)) }
      rows = (pairs || []).reject { |r| heads.include?(PokeAccess.clean(r[0].to_s)) }
      placed = rows.select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }
      lines = placed.map { |r| r[3] }.uniq.sort.map do |y|
        on = placed.select { |r| r[3] == y }.sort_by { |r| r[2] }
        [on.map { |r| PokeAccess.clean(r[0].to_s) }.reject { |t| t.empty? }.join(" "), on[0][1], on[0][2], y]
      end
      lines + (rows - placed)
    end

    # Runs the registration page a capture opens and says the entry it paints, as the info page is read, with the
    # key that goes on.
    def self.registered(species)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      rows = PokeAccess::PaintCapture.laid_out(entry_pairs(pairs))
      types = PokeAccess::DexEntry.gen6_types(nil, species, true)
      t = PokeAccess::DexEntry.painted_entry(rows, true, types)
      return ret unless t
      t = PokeAccess.sentences([t, PokeAccess::TitleScreen.hint]) if PokeAccess::Verbosity.hints?
      PokeAccess.speak(t, true)
      ret
    end

    # A search row as painted: its label and its value, an empty filter ("-", "--") said as such; START alone.
    def self.search_text(win, i)
      value = (win.getText(win.commands, i) rescue "").to_s
      value = PokeAccess::I18n.t(:dxs_unset) if PokeAccess::Menus.placeholder?(value)
      label = SEARCH_LABELS[i]
      label ? "#{_INTL(label)}: #{value}" : value
    end

    # Says the focused search row once per change of row or of its value, the first read queued.
    def self.search_focus(win)
      return unless win.active
      i = win.index
      return if i.nil? || i < 0
      t = search_text(win, i)
      PokeAccess::Cursor.announce(win, :ura_dex_search, [i, t], true, false) { t }
    end

    # A value sublist's row, marked where the icon beside the value in use is drawn (lastsel).
    def self.aux_row(win, i)
      t = ((PokeAccess.ivar(win, :@commands) || [])[i]).to_s
      t = PokeAccess::I18n.t(:dxs_unset) if PokeAccess::Menus.placeholder?(t)
      i == PokeAccess.ivar(win, :@lastsel) ? "#{t}, #{PokeAccess::I18n.t(:ura_dex_applied)}" : t
    end

    # Says a value sublist's title and its value in use as the sublist opens (both painted above it), queued ahead
    # of its first row.
    def self.aux_opened(scene, commands, sel, title)
      PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "auxlist"), :cmd_focus)
      value = (commands.is_a?(Array) ? commands[sel.to_i] : nil).to_s
      value = PokeAccess::I18n.t(:dxs_unset) if PokeAccess::Menus.placeholder?(value)
      t = [PokeAccess.clean(title.to_s), PokeAccess.clean(value)].reject { |s| s.empty? }.join(": ")
      PokeAccess.speak(t, false) unless t.empty?
    end

    # After the search closes: the results count the list's corner paints when a search is on show, then the list's
    # focus again.
    def self.searched(scene)
      refocus(scene)
      return unless PokeAccess.ivar(scene, :@searchResults)
      box = PokeAccess.sprite(scene, "sresult")
      t = box ? PokeAccess.clean((box.text rescue "").to_s.gsub(/<r>/i, " ")) : ""
      PokeAccess.speak(t, false) unless t.empty?
    end
  end
end

PokeAccess::Game.define("uranium") do
  after("Window_DrawableCommandDex", :update) { |win, _r, _a| PokeAccess::UraniumDex.update(win) }
  around("PokedexFormScene", :pbStartScene) { |_s, nxt, _a| PokeAccess::UraniumDex.forms_opened { nxt.call } }
  around("PokedexFormScene", :pbUpdate) { |_s, nxt, _a| PokeAccess::UraniumDex.form_shown { nxt.call } }
  override("PokeAccess::DexEntry", :gen6_info) do |_mod, original, args|
    args[1] = PokeAccess::UraniumDex.entry_pairs(args[1])
    original.call
  end
  around("PokemonPokedexScene", :pbStartDexEntryScene) do |_s, nxt, args|
    PokeAccess::UraniumDex.registered(args[0]) { nxt.call }
  end
  around("PokemonPokedexScene", :pbDexEntry) do |scene, nxt, _a|
    begin
      nxt.call
    ensure
      PokeAccess::UraniumDex.refocus(scene)
    end
  end
  around("Window_ComplexCommandPokemon", :update) do |win, nxt, _a|
    PokeAccess.dedicate(win)
    r = nxt.call
    PokeAccess::UraniumDex.search_focus(win)
    r
  end
  screen_reader("Window_CommandPokemonWhiteArrow") { |win, i| PokeAccess::UraniumDex.aux_row(win, i) }
  # The BW search above is the game's only one: the stock search's reading of each repaint stays quiet.
  override("PokeAccess::DexSearch", :list) { |_m, _o, _a| nil }
  before("PokemonPokedexScene", :pbDexSearchCommands) do |scene, args|
    PokeAccess::UraniumDex.aux_opened(scene, args[0], args[1], args[2])
  end
  around("PokemonPokedexScene", :pbDexSearch) do |scene, nxt, _a|
    PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "searchlist"), :ura_dex_search)
    r = nxt.call
    PokeAccess::UraniumDex.searched(scene)
    r
  end
end
