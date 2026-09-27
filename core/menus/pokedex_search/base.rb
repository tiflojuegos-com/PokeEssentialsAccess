# Pokedex search screen (pbDexSearch), in two variants every era ships, told apart by the arity of the redraw
# (pbRefreshDexSearch): the grid of filters (grid.rb) and the older list of filters (list.rb). Here the module, the
# redraw's dispatch, the reset of the dedup slots on entering and the grouped command windows.
module PokeAccess
  module DexSearch
    # Dispatches by the redraw's arity (both eras ship both screens): the grid keeps its scene and params for moved.
    def self.refresh(scene, args)
      if args.length >= 2
        @scene = scene
        @params = args[0]
        return main(scene, args[0], args[1])
      end
      list(scene)
    end

    # Forgets the grid and its sub-screen when the search closes.
    def self.close
      @scene = nil
      @params = nil
      @param = nil
    end
  end
end

# Any grouped command window ("category", [rows], ...): its flat index resolved by the window's own getText.
PokeAccess::Menus.def_extractor("Window_ComplexCommandPokemon") do |win, i|
  cmds = (win.commands rescue nil)
  cmds ? win.getText(cmds, i).to_s : ""
end

# Entering the search or a filter sub-screen resets its dedup slots: both reopen on the same index and values.
["PokemonPokedex_Scene", "PokemonPokedexScene"].each do |cn|
  PokeAccess::Hooks.before_hook(cn, :pbDexSearch, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :dex_search)
    PokeAccess::Cursor.reset(scene, :dex_search_param)
  end
  PokeAccess::Hooks.before_hook(cn, :pbDexSearchCommands, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :dex_search_param)
  end
end

PokeAccess::Hooks.after_hook("PokemonPokedex_Scene", :pbRefreshDexSearch) do |scene, _r, args|
  PokeAccess::DexSearch.refresh(scene, args)
end
# The gen-6 era names the same scene without the underscore.
PokeAccess::Hooks.after_hook("PokemonPokedexScene", :pbRefreshDexSearch) do |scene, _r, args|
  PokeAccess::DexSearch.refresh(scene, args)
end
# Around, not after: pbDexSearch is the search loop, which an after-hook would run under the guard, muting its reads.
["PokemonPokedex_Scene", "PokemonPokedexScene"].each do |cn|
  PokeAccess::Hooks.around_hook(cn, :pbDexSearch, :optional => true) do |_scene, nxt, _a|
    begin
      nxt.call
    ensure
      PokeAccess::DexSearch.close
    end
  end
end
