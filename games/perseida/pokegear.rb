# Perseida's Pokegear (PokemonMenu2 in 0218_Menu_Pokedex II, opened by openPokedexII from the map and the pause menu): Luka's
# Neo PauseMenu under another name, rows of sprites with no command window. The row under the cursor is said by its
# MenuHandlers name; what the screen also paints, the trainer's name and ID, is the info key's. It closes with no fade, so
# the pause menu it may have opened from is told it has come back.
module PokeAccess
  module PerseidaPokegear
    # The row under the cursor with its place in the list, when it changes or an entry returns to the menu; the first
    # one queued.
    def self.poll(scene)
      entries = PokeAccess.ivar(scene, :@entries)
      idx = PokeAccess.ivar(scene, :@index)
      return unless entries.is_a?(Array) && idx.is_a?(Integer) && entries[idx]
      PokeAccess::Info.set_info(:trainer, nil)
      PokeAccess::Cursor.reset(scene, :perseida_gear) if PokeAccess::NeoMenu.consume_return?
      PokeAccess::Cursor.announce(scene, :perseida_gear, idx, true, false) do
        PokeAccess::Verbosity.list_entry(MenuHandlers.getName(entries[idx]), idx + 1, entries.length)
      end
    end
  end
end

PokeAccess::Game.define("perseida") do
  after("PokemonMenu2_Scene", :update, :optional => true) { |scene, _r, _a| PokeAccess::PerseidaPokegear.poll(scene) }
  around("PokemonMenu2", :pbStartPokemonMenu2, :optional => true) do |_screen, nxt, _a|
    PokeAccess::PerseidaPause.painting(false) { nxt.call }
  end
  after("PokemonMenu2", :pbStartPokemonMenu2, :optional => true, :hook_container => true) do |_screen, _r, _a|
    PokeAccess::MenuReturn.fire
  end
end
