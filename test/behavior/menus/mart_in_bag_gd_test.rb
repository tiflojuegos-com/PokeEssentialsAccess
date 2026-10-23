# The v19 mart's quantity prompt on this era (core/menus/shops.rb) leaves a scene's own count-in-bag qtywindow to that
# scene, and a mart without one is not reported as a window gone silent.
class MartInBagGdTest < PokeAccessTest
  # Clears the prompt and the amount the number entry spoke last, module state the per-test reset leaves alone.
  def setup
    super
    PokeAccess::Shops.prompt_close
    PokeAccess::NumberEntry.forget
  end

  test "the scene's own qtywindow is not taken for the prompt's count" do
    in_prompt do |scene|
      PokeAccess.sprite(scene, "qtywindow").text = "In Bag:<r>2"
      window("x1<r>$ 300")
    end
    assert_equal [[amount(1, 300), false]], SpeakCapture.log
  end

  test "a count window the prompt makes after its first amount follows the next one" do
    in_prompt do |scene|
      PokeAccess.sprite(scene, "qtywindow").text = "In Bag:<r>2"
      num = window("x1<r>$ 300")
      window("In Bag:<r>2  ")
      SpeakCapture.clear
      num.text = "x2<r>$ 600"
    end
    assert_equal [[amount(2, 600), true], ["In Bag: 2", false]], SpeakCapture.log
  end

  test "a mart scene without the prompt's loop (pbChooseNumber) binds without reporting it missing" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\APokemonMart_Scene#/)
  end

  test "a mart laid out without a qtywindow, its count left to the prompt, is not reported as a window gone silent" do
    scene = PokemonMart_Scene.new
    scene.sprites.delete("qtywindow")
    silent = PokeAccess::InfoWindow.silent
    kept = silent.dup
    silent.clear
    PokeAccess::InfoWindow.enter(scene)
    PokeAccess::InfoWindow.tick
    assert_equal [], silent.grep(/\APokemonMart_Scene\./)
  ensure
    PokeAccess::InfoWindow.leave
    silent.replace(kept) if kept
  end

  private

  # Runs the block with the mart's prompt open over a scene keeping its own qtywindow, as the hook on pbChooseNumber
  # holds it, and closes it after.
  def in_prompt
    scene = World.stub_scene(:@sprites => { "qtywindow" => Window_AdvancedTextPokemon.new("") })
    PokeAccess::Shops.prompt_open(scene)
    yield scene
  ensure
    PokeAccess::Shops.prompt_close
  end

  # A new text window given text.
  def window(text)
    w = Window_AdvancedTextPokemon.new("")
    w.text = text
    w
  end

  # The amount line as the number entry says it.
  def amount(n, price)
    "#{n}, #{PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => price)}"
  end
end
