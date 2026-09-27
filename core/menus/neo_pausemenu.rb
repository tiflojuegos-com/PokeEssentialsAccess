# Neo PauseMenu (Luka S.J.'s plugin): PokemonMenu_Scene as a sprite menu with no command window; the focused entry of
# @entries is read by its MenuHandlers name on change. :optional, since gen-6 menus have no #update.
module PokeAccess
  # Return signal for the Neo menu: MenuReturn arms a flag its next update consumes by resetting the dedup slot.
  module NeoMenu
    def self.mark_return; @ret = true; end

    def self.consume_return?
      r = @ret
      @ret = false
      r ? true : false
    end
  end
end

# Each frame: sets the info key's trainer answer (the loop never updates the map) and reads the focused entry.
PokeAccess::Hooks.after_hook("PokemonMenu_Scene", :update, :optional => true) do |scene, _r, _a|
  if defined?(MenuHandlers)
    PokeAccess::Info.set_info(:trainer, nil)
    PokeAccess::Cursor.reset(scene, :neo_last) if PokeAccess::NeoMenu.consume_return?
    PokeAccess::Menus.poll_sprite_menu(scene, :@entries, :neo_last) do |entry|
      (MenuHandlers.getName(entry) rescue entry.to_s)
    end
  end
end

PokeAccess::MenuReturn.on_return { PokeAccess::NeoMenu.mark_return }
