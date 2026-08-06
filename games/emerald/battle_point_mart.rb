# The "Battle Point Mart" window, which only this game has. It is the Battle Point shop in every respect
# that matters to a reader -- @stock of item ids, an @adapter for name and price, one extra row for cancel --
# but it descends from Window_DrawableCommand instead of Window_PokemonMart, so the mart extractor never
# matched it (focused_text picks an extractor with win.is_a?).
#
# The row builder is core's, shared with the shop window four games have. Only the NAME is this game's, which
# is exactly why the name is registered here: core may not mention a class a single fangame has.
PokeAccess::Menus.def_extractor("Window_PokemonMart_BattlePoints") do |win, i|
  PokeAccess::BattlePointShop.row(win, i)
end
