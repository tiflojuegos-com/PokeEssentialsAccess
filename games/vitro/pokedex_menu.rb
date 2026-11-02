# Vitro's list of Pokedexes (PokemonPokedexMenu_Screen, 0159_Pokedex_Menu, from the pause menu's openDex when there are several): core
# reads its Window_DexesList, with the seen and owned the headings name. What it leaves: pbRefresh runs as a Pokedex returns, so the
# row is said again; and pbPokedexMenu counts as one screen for the pause menu, which would say its own entry over the list when a
# Pokedex's fade ends, and says it now when the list closes.
PokeAccess::Game.define("vitro") do
  after("PokemonPokedexMenu_Scene", :pbRefresh, :optional => true) do |scene, _r, _a|
    win = PokeAccess.sprite(scene, "commands")
    PokeAccess::Cursor.reset(win, :cmd_focus) if win
  end
end

PokeAccess::MenuReturn.bare_fn("pbPokedexMenu")
