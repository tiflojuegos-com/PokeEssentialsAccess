# Revival's pause menu, its edited copy of Luka's Modular Menu (PokemonPauseMenu_Scene: a column of buttons, each its
# entry's name over an icon, @entries the entries shown and @index the lit one), driven by PokemonPauseMenu's loop:
# the lit button, with its place, as update moves it, and again on the way back from what it opened.
module PokeAccess
  module RevivalPauseMenu
    @scene = nil

    # The words a button paints: its entry's name (ModularMenu), the player's in place of \PN, which speak cleans.
    def self.label(entry)
      name = (::ModularMenu.name(entry) rescue nil)
      name.nil? ? nil : name.to_s
    end

    # The lit button's line: its words with its place among the buttons shown.
    def self.line(entry, i, scene)
      name = label(entry)
      return nil unless name
      PokeAccess::Verbosity.list_entry(name, i + 1, (PokeAccess.ivar(scene, :@entries) || []).length)
    end

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end

    # Back from an entry while the menu's loop runs: the next update says the lit button again.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :rv_pause) if @scene
    end
  end
end

PokeAccess::Game.define("revival") do
  focus_reader("PokemonPauseMenu_Scene", :on => :update, :items => :@entries, :slot => :rv_pause,
               :hook_container => true) do |entry, i, scene|
    PokeAccess::RevivalPauseMenu.line(entry, i, scene)
  end
  around("PokemonPauseMenu", :pbStartPokemonMenu) do |screen, nxt, _a|
    PokeAccess::RevivalPauseMenu.watch(PokeAccess.ivar(screen, :@scene))
    PokeAccess::MenuReturn.reset_nesting
    begin; nxt.call; ensure; PokeAccess::RevivalPauseMenu.unwatch; end
  end
end

PokeAccess::MenuReturn.on_return { PokeAccess::RevivalPauseMenu.returned }
