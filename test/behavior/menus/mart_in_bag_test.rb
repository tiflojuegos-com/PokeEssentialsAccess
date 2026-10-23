# The mart's quantity prompt up to v19 (core/menus/shops.rb): the count in the bag pbChooseNumber writes as it opens,
# shown only when buying, is said once, queued after the amount the prompt starts on, itself queued behind the question.
class MartInBagTest < PokeAccessTest
  # Clears the prompt and the amount the number entry spoke last, module state the per-test reset leaves alone.
  def setup
    super
    PokeAccess::Shops.prompt_close
    PokeAccess::NumberEntry.forget
  end

  test "says the count in the bag after the prompt's first amount, queued" do
    in_prompt do |scene|
      PokeAccess.sprite(scene, "helpwindow").text = "How many Potions would you like?"
      window("In Bag:<r>5  ")
      window("x1<r>$ 200")
    end
    assert_equal [[amount(1, 200), false], ["In Bag: 5", false]], SpeakCapture.log
  end

  test "says the next amount alone" do
    in_prompt do
      window("In Bag:<r>5  ")
      num = window("x1<r>$ 200")
      SpeakCapture.clear
      num.text = "x2<r>$ 400"
    end
    assert_equal [[amount(2, 400), true]], SpeakCapture.log
  end

  test "the amount line is not taken for the count" do
    in_prompt do
      num = window("x1<r>$ 200")
      window("In Bag:<r>5  ")
      SpeakCapture.clear
      num.text = "x2<r>$ 400"
    end
    assert_equal [[amount(2, 400), true], ["In Bag: 5", false]], SpeakCapture.log
  end

  test "only the first window the prompt makes is the count" do
    in_prompt do
      window("In Bag:<r>5  ")
      window("Otra ventana")
      window("x1<r>$ 200")
    end
    assert_equal [[amount(1, 200), false], ["In Bag: 5", false]], SpeakCapture.log
  end

  test "a window left blank by its markup is not taken for the count" do
    in_prompt do
      window("<r>  ")
      window("In Bag:<r>5  ")
      window("x1<r>$ 200")
    end
    assert_equal [[amount(1, 200), false], ["In Bag: 5", false]], SpeakCapture.log
  end

  test "while selling the hidden count window is not said" do
    in_prompt do
      window("In Bag:<r>5  ", false)
      window("x1<r>$ 100")
    end
    assert_equal [[amount(1, 100), false]], SpeakCapture.log
  end

  test "a count no amount followed is dropped when the prompt closes" do
    in_prompt { window("In Bag:<r>5  ") }
    in_prompt { window("x1<r>$ 100") }
    assert_equal [[amount(1, 100), false]], SpeakCapture.log
  end

  test "outside the prompt no window is taken for the count" do
    window("In Bag:<r>5  ")
    window("x1<r>$ 100")
    assert_equal [[amount(1, 100), false]], SpeakCapture.log
  end

  test "once the prompt has closed no window is taken for the count" do
    in_prompt { window("x1<r>$ 100") }
    SpeakCapture.clear
    window("In Bag:<r>5  ")
    window("x2<r>$ 200")
    assert_equal [[amount(2, 200), false]], SpeakCapture.log
  end

  private

  # Runs the block with the mart's prompt open over a scene whose question goes to its helpwindow, as the hook on
  # pbChooseNumber holds it, and closes it after.
  def in_prompt
    scene = World.stub_scene(:@sprites => { "helpwindow" => Window_AdvancedTextPokemon.new("") })
    PokeAccess::Shops.prompt_open(scene)
    yield scene
  ensure
    PokeAccess::Shops.prompt_close
  end

  # A new engine text window (Window_AdvancedTextPokemon, whose text= the reader hooks) given text, hidden when shown
  # is false (the stub has no visible flag, so it counts as shown).
  def window(text, shown = true)
    w = Window_AdvancedTextPokemon.new("")
    def w.visible; false; end unless shown
    w.text = text
    w
  end

  # The amount line as the number entry says it.
  def amount(n, price)
    "#{n}, #{PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => price)}"
  end
end
