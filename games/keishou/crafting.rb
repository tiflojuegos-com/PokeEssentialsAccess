# Keishou's crafting bench (its Item Crafting UI Plus, read by plugins/item_crafting.rb) also paints how many of the result
# the bag holds, beside the amount (001_UI_ItemCrafting.rb, pbRedrawItem).
PokeAccess::Game.define("keishou") do
  override("PokeAccess::ItemCrafting", :detail_line) do |_m, original, args|
    line = original.call
    have = ($bag.quantity(args[1][0]) rescue nil)
    (line && have) ? "#{line}, #{PokeAccess::I18n.t(:ura_bmart_have, :list => have)}" : line
  end
end
