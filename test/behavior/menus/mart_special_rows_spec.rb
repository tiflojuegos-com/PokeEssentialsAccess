# Infinite Fusion's clothes shops on the plain mart window: an action row (a bare symbol in the stock) reads its
# adapter's caption, and the worn item, painted in a colour of its own, says it is worn.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

Suite.define("mart: an action row is read by its caption, and the worn item says so") do
  inner = Object.new
  def inner.isWornItem?(item); item == :TOPHAT; end
  ad = Object.new
  ad.instance_variable_set(:@inner, inner)
  def ad.getAdapter; @inner; end
  def ad.getSpecialItemCaption(s); s == :REMOVE_HAT ? "Remove hat" : nil; end
  def ad.getDisplayName(item); { :TOPHAT => "Chistera", :CAP => "Gorra" }[item]; end
  def ad.getDisplayPrice(_item); "$500"; end
  win = Window_PokemonMart.new
  win.instance_variable_set(:@stock, [:REMOVE_HAT, :TOPHAT, :CAP])
  win.instance_variable_set(:@adapter, ad)
  def win.index; @i || 0; end
  def win.index=(v); @i = v; end
  menus = PokeAccess::Menus
  eq "the action row says its painted caption, not the symbol", menus.focused_text(win), "Remove hat"
  win.index = 1
  eq "the worn hat says it is worn", menus.focused_text(win), "Chistera, $500, #{PokeAccess::I18n.t(:shop_worn)}"
  win.index = 2
  eq "and any other is an ordinary row", menus.focused_text(win), "Gorra, $500"
end
