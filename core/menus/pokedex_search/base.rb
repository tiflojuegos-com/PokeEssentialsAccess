# Pokedex search screen (pbDexSearch), in two variants every era ships, told apart by the arity of the redraw
# (pbRefreshDexSearch): the grid of filters (grid.rb) and the older list of filters (list.rb). Here the module, the
# redraw's dispatch, the reset of the dedup slots on entering and the grouped command windows.
module PokeAccess
  module DexSearch
    # Dispatches by the redraw's arity (both eras ship both screens): the grid keeps its scene and params for moved. A
    # true or false second argument is the list's own flag for cutting in (Rejuvenation 14's), not the grid's.
    def self.refresh(scene, args)
      if args.length >= 2 && args[1] != true && args[1] != false
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

    # A row with the type icons the engine Reborn and Rejuvenation share paints (<icon=typeFIRE>) as the types' names.
    def self.typed(row)
      row.gsub(/<icon=type(\w+)>/) do
        id = $1
        name = (PokeAccess::Data.type_name(id.to_sym) rescue nil)
        " #{name.nil? || name.to_s.empty? ? PokeAccess::Util.capitalized(id) : name} "
      end
    end

    # One of the search's windows, in the scene's sprites or, where a fork keeps the Pokedex's apart (Rejuvenation 14),
    # in its @pokedexSprites.
    def self.sprite(scene, name)
      PokeAccess.sprite(scene, name) || (PokeAccess.ivar(scene, :@pokedexSprites) || {})[name]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A filter's sub-screen opening: its dedup slots reset, those of the older screen's one sub-list window too, which
    # every filter shares and which reopens on the value it was left on.
    def self.sub_list_opened(scene)
      PokeAccess::Cursor.reset(scene, :dex_search_param)
      aux = sprite(scene, "auxlist")
      PokeAccess::Cursor.reset(aux, :cmd_focus) if aux
    end
  end
end

# Any grouped command window ("category", [rows], ...): its flat index resolved by the window's own getText, its type
# icons named.
PokeAccess::Menus.def_extractor("Window_ComplexCommandPokemon") do |win, i|
  cmds = (win.commands rescue nil)
  cmds ? PokeAccess::DexSearch.typed(win.getText(cmds, i).to_s) : ""
end

# Entering the search or a filter sub-screen resets its dedup slots: both reopen on the same index and values.
["PokemonPokedex_Scene", "PokemonPokedexScene"].each do |cn|
  PokeAccess::Hooks.before_hook(cn, :pbDexSearch, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :dex_search)
    PokeAccess::Cursor.reset(scene, :dex_search_param)
    PokeAccess::Cursor.reset(scene, :dex_search_group)
  end
  PokeAccess::Hooks.before_hook(cn, :pbDexSearchCommands, :optional => true) do |scene, _a|
    PokeAccess::DexSearch.sub_list_opened(scene)
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
