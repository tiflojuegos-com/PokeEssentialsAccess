# Neo PauseMenu (Luka S.J. plugin, EBS-style): reopens PokemonMenu_Scene as a sprite menu -- its entries
# are drawn as bitmaps with no command window, so neither the command-window hook nor the generic
# auto-detect (which both need a SpriteWindow_Selectable to introspect) can see it. Its own loop sets @index and
# calls update every frame, with the entry refs in @entries and their labels in the MenuHandlers module;
# read the focused entry on change. Guarded on @entries + MenuHandlers, so it is a no-op on a vanilla
# command-window PokemonMenu_Scene (and on any game without this plugin). Optional: gen-6 menus have no
# #update at all (their loop lives in pbStartScene), which is variance, not a typo.
module PokeAccess
  # Return signal for the Neo sprite menu: entries run INLINE in the menu's own loop, so coming back lands
  # on the same @index. MenuReturn arms a flag the menu's next update consumes by forgetting the slot.
  # Arming outside the menu is harmless: consuming only clears a dedup slot.
  module NeoMenu
    def self.mark_return; @ret = true; end

    def self.consume_return?
      r = @ret
      @ret = false
      r ? true : false
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonMenu_Scene", :update, :optional => true) do |scene, _r, _a|
  if defined?(MenuHandlers)
    PokeAccess::Cursor.reset(scene, :neo_last) if PokeAccess::NeoMenu.consume_return?
    PokeAccess::Menus.poll_sprite_menu(scene, :@entries, :neo_last) do |entry|
      (MenuHandlers.getName(entry) rescue entry.to_s)
    end
  end
end

PokeAccess::MenuReturn.on_return { PokeAccess::NeoMenu.mark_return }
