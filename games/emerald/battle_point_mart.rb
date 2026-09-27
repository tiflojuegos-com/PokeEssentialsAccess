# Emerald's Battle Point Mart, read as a shop under its own class names and with the mart's lifecycle.
PokeAccess::Menus.def_extractor("Window_PokemonMart_BattlePoints") do |win, i|
  PokeAccess::Shops.row(win, i)
end

# Its scene has no PokemonMart_Scene ancestry, so the core screen-message net never reaches its prompts.
PokeAccess::Game.define("emerald") do
  [:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |m|
    before("PokemonMart_Scene_BattlePoints", m, :optional => true) do |_s, args|
      PokeAccess.say_screen_message(args)
    end
  end
end

PokeAccess::InfoWindow.watch("PokemonMart_Scene_BattlePoints", "qtywindow", :bpm_bag,
                             PokeAccess::Shops::MART_LIFECYCLE.merge(:reading => [:shop_item, :medium]))
PokeAccess::InfoWindow.watch("PokemonMart_Scene_BattlePoints", "coinswindow", :bpm_points, PokeAccess::Shops::MART_LIFECYCLE)
