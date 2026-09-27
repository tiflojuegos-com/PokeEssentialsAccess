# Reminiscencia's rogue mode (switch 152): the shop's row colours said as words (held, found before), an unidentified
# item's description kept back, a rogue item's bag count hidden. The profile is loaded for this suite alone.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

Suite.define("reminiscencia rogue shop: the info key keeps the shop's secret, and the row colours are said") do
  m = PokeAccess::Menus
  meta = (class << m; self; end)
  meta.send(:alias_method, :rem_spec_mart_marks, :mart_marks)
  meta.send(:alias_method, :rem_spec_bag_hides_qty, :bag_hides_qty?)
  had_bag = $PokemonBag
  had_player_found = ($game_player.instance_variable_get(:@found_items) rescue nil)
  begin
    load File.expand_path("../../../games/reminiscencia/rogue_shop.rb", File.dirname(__FILE__))
    $game_switches[152] = true
    bag = Object.new
    def bag.pbHasItem?(item); item == 1; end
    $PokemonBag = bag
    def $game_player.found_items; [2]; end
    ad = Object.new
    def ad.getDisplayName(item); "Objeto#{item}"; end
    def ad.getDisplayPrice(_item); "$ 100"; end
    def ad.getDescription(item); item == 3 ? "???" : "Cura 20 PS."; end
    win = Window_PokemonMart.new
    win.instance_variable_set(:@stock, [1, 2, 3])
    win.instance_variable_set(:@adapter, ad)
    def win.index; @i || 0; end
    def win.index=(v); @i = v; end
    eq "an item in the bag is marked as held", m.focused_text(win),
       "Objeto1, $ 100, #{PokeAccess::I18n.t(:rem_shop_have)}"
    win.index = 1
    eq "one found before as known", m.focused_text(win), "Objeto2, $ 100, #{PokeAccess::I18n.t(:rem_shop_known)}"
    win.index = 2
    eq "an unknown one is plain", m.focused_text(win), "Objeto3, $ 100"
    real = PokeAccess::Data.method(:item_description)
    PokeAccess::Data.define_singleton_method(:item_description) { |id| "Descripcion real #{id}" }
    begin
      falsy "and the info key does not tell its real description", PokeAccess::Info.info_text.to_s.include?("Descripcion real")
    ensure
      PokeAccess::Data.define_singleton_method(:item_description, real)
    end
    truthy "it says the description is unknown, as the shop does",
           PokeAccess::Info.info_text.to_s.include?(PokeAccess::I18n.t(:pdx_unknown_short))
    Object.send(:define_method, :pbIsRogueItem?) { |item| item == 3 }
    truthy "a rogue item's count is hidden in the bag", m.bag_hides_qty?(3)
    Object.send(:remove_method, :pbIsRogueItem?)
  ensure
    meta.send(:alias_method, :mart_marks, :rem_spec_mart_marks)
    meta.send(:remove_method, :rem_spec_mart_marks)
    meta.send(:alias_method, :bag_hides_qty?, :rem_spec_bag_hides_qty)
    meta.send(:remove_method, :rem_spec_bag_hides_qty)
    $game_switches[152] = false
    $PokemonBag = had_bag
    class << $game_player
      remove_method :found_items
    end
  end
end
