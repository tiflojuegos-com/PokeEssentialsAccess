# royal's grid pause menu ([ROYAL] - MIS SCRIPTS/007_Menu Parrilla.rb -> class Menu2), which replaces the
# standard pause menu entirely, so neither the generic command reader nor the standard pause reader sees it.
# Its @items entries are [icon_name, label, method] and @selected_item is the cursor; pbActualizarIconosMenu
# redraws on every cursor move (and on open), so the focused command's label (item[1], e.g. "Mochila",
# "Equipo") is read there, deduped by the selected index.
#
# That label field is never drawn -- the grid shows icons only -- which is why one of them went unnoticed:
# the achievements entry is declared ["logros", "Regalo", "openLogros"], carrying the Mystery Gift's label by
# mistake, so with both unlocked the menu read "Regalo" twice in a row and called the achievements the gift.
# The method in field 2 is what the button actually does, so it is what corrects the label; everything else
# keeps using the game's own text, which is right.
module PokeAccess
  module RoyalGridMenu
    @open = 0
    @last = nil

    def self.open!; @open += 1; end
    def self.close!; @open -= 1 if @open > 0; end

    # Speaks the focused command and remembers it, so the return below has something to repeat.
    def self.focus(menu)
      items = PokeAccess.ivar(menu, :@items)
      idx   = PokeAccess.ivar(menu, :@selected_item)
      return unless items.is_a?(Array) && idx && items[idx].is_a?(Array)
      return unless PokeAccess::Cursor.changed?(menu, :pm, idx)
      label = (items[idx][2].to_s == "openLogros") ? "Logros" : items[idx][1]
      return if label.nil? || label.to_s.empty?
      @last = label.to_s
      PokeAccess.speak_clean(@last, true)
    rescue StandardError
      nil
    end

    # The entries the grid dispatches, every one a top-level function the menu reaches through send. Their
    # RETURN is what says the player is back, and it is the only signal that covers all of them: some wrap
    # themselves in pbFadeOutIn and some (Options, a cancelled save) do not. exitMenuPause is left out --
    # it ends the menu instead of returning to it.
    ENTRIES = %w[openDex openParty openBag openTrainerCard openSave openMap
                 openPCStorageFromPauseMenu openTarjetaLiga openLogros openRegaloMisterioso openOptions]

    # Coming back from a submenu: pbActualizarIconosMenu only runs on the four arrow branches, so without
    # this the grid returned to a menu that said nothing until the cursor moved. Gated on the menu being
    # open, because two of these entries are reachable from the field as well.
    def self.returned
      PokeAccess.speak_clean(@last, true) if @open > 0 && @last
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  after("Menu2", :pbActualizarIconosMenu) { |menu, _ret, _args| PokeAccess::RoyalGridMenu.focus(menu) }
  # pbStartPokemonMenu IS this menu's loop -- it dispatches each entry with send from inside it and carries
  # on -- so it is held rather than hooked after, which is what tells the entries below that the menu is
  # still on screen.
  around("Menu2", :pbStartPokemonMenu) do |_s, nxt, _a|
    PokeAccess::RoyalGridMenu.open!
    begin; nxt.call; ensure; PokeAccess::RoyalGridMenu.close!; end
  end
  PokeAccess::RoyalGridMenu::ENTRIES.each do |fn|
    kernel(fn, :after) { |_args, _r| PokeAccess::RoyalGridMenu.returned }
  end
end
