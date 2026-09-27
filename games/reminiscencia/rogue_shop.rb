# Reminiscencia's rogue mode (switch 152): its shop colours a row blue when the bag holds the item and red when
# it was found and is gone, said as marks; its bag hides the count of every rogue item (pbIsRogueItem?).
PokeAccess::Game.define("reminiscencia") do
  override("PokeAccess::Menus", :mart_marks) do |_mod, original, args|
    item = args[1]
    if $game_switches && $game_switches[152]
      if ($PokemonBag.pbHasItem?(item) rescue false)
        [:rem_shop_have]
      elsif (($game_player.found_items || []).include?(item) rescue false)
        [:rem_shop_known]
      else
        original.call
      end
    else
      original.call
    end
  end
  override("PokeAccess::Menus", :bag_hides_qty?) do |_mod, original, args|
    (pbIsRogueItem?(args[0]) rescue false) ? true : original.call
  end
end
