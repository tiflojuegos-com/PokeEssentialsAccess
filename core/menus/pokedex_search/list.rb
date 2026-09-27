# The older list variant of the Pokedex search (pbRefreshDexSearch(params)): a "searchlist" window of the filters and
# a message box with the focused one's help, each filter's choices a sub-list with its own loop
# (pbDexSearchCommands).
module PokeAccess
  module DexSearch
    # The older search screen (pbRefreshDexSearch(params)): its "searchlist" window, claimed from the generic reader,
    # read off its cursor; the message box's help line follows while descriptions are said, and fills the info key.
    def self.list(scene)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "searchlist"))
      return unless win
      txt = PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s)
      return if txt.empty?
      help = help_text(scene)
      PokeAccess::Info.set_info(:text, help) unless help.empty?
      PokeAccess::Cursor.announce(scene, :dex_search, [(win.index rescue nil), txt], true) do
        help.empty? || !PokeAccess::Verbosity.descriptions? ? txt : "#{txt}. #{help}"
      end
    rescue StandardError
      nil
    end

    # The older screen's help line, as its message box holds it now, or "".
    def self.help_text(scene)
      box = PokeAccess.sprite(scene, "messagebox")
      box ? PokeAccess.clean((box.text rescue "").to_s) : ""
    rescue StandardError
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
    rescue StandardError
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
PokeAccess::Keys.on_frame { PokeAccess::DexSearch.aux_poll }
