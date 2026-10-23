# The older list variant of the Pokedex search (pbRefreshDexSearch(params)): a "searchlist" window of the filters and
# a message box with the focused one's help, each filter's choices a sub-list with its own loop
# (pbDexSearchCommands).
module PokeAccess
  module DexSearch
    # The older search screen (pbRefreshDexSearch(params)): its "searchlist" window, claimed from the generic reader,
    # read off its cursor (in_context); the message box's help line follows while descriptions are said, and fills
    # the info key.
    def self.list(scene)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "searchlist"))
      return unless win
      txt = PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s)
      return if txt.empty?
      help = help_text(scene)
      PokeAccess::Info.set_info(:text, help) unless help.empty?
      PokeAccess::Cursor.announce(scene, :dex_search, [(win.index rescue nil), txt], true) do
        row = in_context(scene, win, txt)
        help.empty? || !PokeAccess::Verbosity.descriptions? ? row : "#{row}. #{help}"
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A row after its group's heading ("Sort, Order: ...") when the cursor enters that group, and after the screen's
    # title too on the search's first read.
    def self.in_context(scene, win, txt)
      first = PokeAccess::Cursor.pending?(scene, :dex_search_group)
      g = (win.indexToCommand(win.index)[0] rescue nil)
      head = (g && PokeAccess::Cursor.changed?(scene, :dex_search_group, g)) ? PokeAccess.clean((win.commands[g * 2] rescue "").to_s) : ""
      row = head.empty? ? txt : "#{head}, #{txt}"
      title = first ? PokeAccess.clean((PokeAccess.sprite(scene, "searchtitle").text rescue "").to_s) : ""
      PokeAccess::Util.join_parts([title, row])
    end

    # The older screen's help line, as its message box holds it now, or "".
    def self.help_text(scene)
      box = PokeAccess.sprite(scene, "messagebox")
      box ? PokeAccess.clean((box.text rescue "").to_s) : ""
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end

    # Starts watching the help line a filter's sub-list writes as its cursor moves.
    def self.aux_open(scene)
      @aux = scene
      @aux_wait = true
      PokeAccess::Cursor.reset(scene, :dex_search_help)
    end

    def self.aux_close
      @aux = nil
    end

    # Speaks a changed help line while descriptions are said and keeps it for the info key; the first one waits a
    # frame, so it follows its option.
    def self.aux_poll
      return unless @aux
      return @aux_wait = false if @aux_wait
      t = help_text(@aux)
      return if t.empty?
      return unless PokeAccess::Cursor.changed?(@aux, :dex_search_help, t)
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false) if PokeAccess::Verbosity.descriptions?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The filter sub-lists run their own loop: the help line is watched only while one is open.
PokeAccess::Hooks.around_hook("PokemonPokedexScene", :pbDexSearchCommands, :optional => true) do |scene, nxt, _a|
  PokeAccess::DexSearch.aux_open(scene)
  begin
    nxt.call
  ensure
    PokeAccess::DexSearch.aux_close
  end
end
PokeAccess::Frame.each_pulse { PokeAccess::DexSearch.aux_poll }
