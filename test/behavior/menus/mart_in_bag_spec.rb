# The mart's quantity prompt up to v19 (core/menus/shops.rb): pbChooseNumber writes the count in the bag into a window
# of its own as it opens, shown only when buying; it is said once, after the amount the prompt starts on.
module MartInBagSpec
  # A text window of the prompt, shown or hidden.
  Win = Struct.new(:visible)

  # The amount line as NumberEntry says it.
  def self.amount(n, price)
    "#{n}, #{PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => price)}"
  end
end

Suite.define("mart: the prompt's count in the bag is said after its first amount, and only while buying") do
  shops = PokeAccess::Shops
  ne = PokeAccess::NumberEntry
  win = MartInBagSpec::Win
  help = win.new(true)
  scene = World.stub_scene(:@sprites => { "helpwindow" => help })
  num = win.new(true)
  ne.forget
  SpeakCapture.clear
  shops.prompt_open(scene)
  begin
    shops.prompt_text(help, "How many Potions would you like?")
    shops.prompt_text(win.new(true), "In Bag:<r>5  ")
    shops.prompt_text(num, "x1<r>$ 200")
    ne.on_text(num, "x1<r>$ 200")
    eq "the amount, interrupting, then the count in the bag, queued", SpeakCapture.log,
       [[MartInBagSpec.amount(1, 200), true], ["In Bag: 5", false]]
    SpeakCapture.clear
    ne.on_text(num, "x2<r>$ 400")
    eq "the next amount alone", SpeakCapture.lines, [MartInBagSpec.amount(2, 400)]
  ensure
    shops.prompt_close
  end

  sell = win.new(true)
  ne.forget
  SpeakCapture.clear
  shops.prompt_open(scene)
  begin
    shops.prompt_text(win.new(false), "In Bag:<r>5  ")
    ne.on_text(sell, "x1<r>$ 100")
    eq "selling, the window is hidden and not said", SpeakCapture.lines, [MartInBagSpec.amount(1, 100)]
  ensure
    shops.prompt_close
  end

  ne.forget
  SpeakCapture.clear
  shops.prompt_text(win.new(true), "In Bag:<r>5  ")
  ne.on_text(win.new(true), "x1<r>$ 100")
  eq "and outside the prompt no window is taken for it", SpeakCapture.lines, [MartInBagSpec.amount(1, 100)]
end
