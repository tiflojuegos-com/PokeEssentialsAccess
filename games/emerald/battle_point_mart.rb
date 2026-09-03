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

# The Battle Point Mart declares its OWN standalone scene class (no PokemonMart_Scene ancestry), so the
# core screen-message net never reaches its prompts ("How many?", the total, "not enough BP") -- wired
# here because the class exists in this game alone.
PokeAccess::Game.define("emerald") do
  [:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |m|
    before("PokemonMart_Scene_BattlePoints", m, :optional => true) do |_s, args|
      PokeAccess.say_dialogue(args[0].to_s) if args[0] && !args[0].to_s.empty?
    end
  end
end
