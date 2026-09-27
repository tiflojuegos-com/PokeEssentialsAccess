# The v19 mart's quantity prompt (core/menus/shops.rb; Infinite Fusion keeps it) builds the count in the bag in a
# window of its own, as the gen-6 one does; later marts keep it in the scene's qtywindow, which the prompt leaves alone.
# Gamedata pass.
Suite.define("mart: on this era too the prompt's own count in the bag follows its amount, a sprite's does not") do
  shops = PokeAccess::Shops
  ne = PokeAccess::NumberEntry
  win = Struct.new(:visible)
  qty = win.new(true)
  scene = World.stub_scene(:@sprites => { "qtywindow" => qty })
  num = win.new(true)
  price = PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => 300)
  ne.forget
  SpeakCapture.clear
  shops.prompt_open(scene)
  begin
    shops.prompt_text(qty, "In Bag:<r>2")
    ne.on_text(num, "x1<r>$ 300")
    eq "the scene's own qtywindow is not taken for the prompt's", SpeakCapture.lines, ["1, #{price}"]
    shops.prompt_text(win.new(true), "In Bag:<r>2  ")
    ne.on_text(num, "x2<r>$ 600")
    two = "2, #{PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => 600)}"
    eq "the prompt's own window is, after the next amount", SpeakCapture.lines.last(2), [two, "In Bag: 2"]
  ensure
    shops.prompt_close
  end
end
