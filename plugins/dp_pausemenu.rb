module PokeAccess
  # Marin's Diamond/Pearl Pause Menu (DP_PauseMenu: anil ships it as PauseMenuDP, Pokemon Z as its
  # "Menu Mejorado"): a sprite menu, not a Window_CommandPokemon, so the generic command hook never sees
  # it. Its loop calls update every frame and keeps the cursor in @option and the entries (each
  # [label, ...]) in @options.
  module DPMenu
    # Reads the focused entry on cursor change, deduped per menu instance (a reopened menu is a fresh
    # instance, so it reads its first option without any explicit reset), and keeps the contextual
    # trainer info current so the info key answers with the trainer while the menu is open.
    #
    # Labels go through Menus.button_label, which names the trainer card where the menu labels it with the
    # player's name -- the DP convention, and shared with the two sprite-button menus.
    def self.read(menu)
      PokeAccess::Info.set_info(:trainer, nil)
      list = PokeAccess.ivar(menu, :@options)
      idx  = PokeAccess.ivar(menu, :@option)
      return unless list.is_a?(Array) && idx && list[idx]
      PokeAccess::Cursor.announce(menu, :dpmenu, idx) do
        PokeAccess::Menus.button_label(list[idx][0])
      end
    rescue StandardError
      nil
    end

    @menu = nil

    def self.watch(menu); @menu = menu; end
    def self.unwatch; @menu = nil; end

    # Coming back from a submenu. Every entry is a proc the loop calls inline and then carries on; the loop's
    # redraw block only runs when the cursor MOVED, so the menu reappeared on the same icon and said nothing.
    # Clearing the slot makes the next update place the player again.
    #
    # MenuReturn covers both kinds of entry (the fade of the ones that leave the screen, the message box of
    # the ones that only put up a dialogue); gated on the menu's own loop being held, so nothing happens
    # while it is closed.
    def self.returned
      PokeAccess::Cursor.reset(@menu, :dpmenu) if @menu
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("DP_PauseMenu", :update, :optional => true) { |menu, _r, _a| PokeAccess::DPMenu.read(menu) }

PokeAccess::Hooks.around_hook("DP_PauseMenu", :main, :optional => true) do |menu, nxt, _a|
  PokeAccess::DPMenu.watch(menu)
  PokeAccess::MenuReturn.reset_nesting
  begin; nxt.call; ensure; PokeAccess::DPMenu.unwatch; end
end

PokeAccess::MenuReturn.on_return { PokeAccess::DPMenu.returned }

# Pokemon Z opens its DexNav list (EncounterListUI) from INSIDE the menu loop, and that screen touches
# none of the three return seams -- so coming back left the menu mute until the cursor moved.
PokeAccess::MenuReturn.bare("EncounterListUI", :initialize, :optional => true)
