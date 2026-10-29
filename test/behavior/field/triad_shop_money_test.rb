# The Triple Triad card shop's money window on the gen-6 engine (core/menus/money_window.rb, watched by the shop's
# wrapper in core/field/minigame_text.rb): said queued as the shop builds it, ahead of the card it draws, and once for
# each new sum a purchase repaints; no text window outside the shop is said, before it opens or after it closes.
class TriadShopMoneyTest < PokeAccessTest
  OPEN = "Dinero:\n3.000$".freeze

  test "both halves of the shop say their money window as they open, queued ahead of the card beside the row" do
    [:pbBuyTriads, :pbSellTriads].each do |shop|
      SpeakCapture.clear
      shopping([OPEN], [4]) { send(shop) }
      assert_equal [["Dinero: 3.000$", false], [card(4), false]], SpeakCapture.log, shop.to_s
    end
  end

  test "a purchase that repaints the window says the new sum once, as painted" do
    shopping(["Money:\n$3,000", "Money:\n$2,500", "Money:\n$2,500"], []) { pbBuyTriads }
    assert_equal [["Money: $3,000", false], ["Money: $2,500", false]], SpeakCapture.log
  end

  test "a text window outside the shop says nothing, before it opens or after it closes" do
    Window_UnformattedTextPokemon.new("Antes.").text = "Fuera."
    shopping([OPEN], []) { pbBuyTriads }
    Window_UnformattedTextPokemon.new("Después.").text = "Fuera otra vez."
    assert_equal [["Dinero: 3.000$", false]], SpeakCapture.log
  end

  test "coming back to the shop says its money again" do
    2.times { shopping([OPEN], []) { pbBuyTriads } }
    assert_equal [["Dinero: 3.000$", false]] * 2, SpeakCapture.log
  end

  private

  # A card's line, as the shop's card reader says it.
  def card(species)
    PokeAccess::TripleTriad.card_text(species)
  end

  # Runs the block with the shop stub painting money in its window and walking its focus over rows.
  def shopping(money, rows)
    was = [$triad_shop_money, $triad_shop_script]
    $triad_shop_money = money
    $triad_shop_script = rows
    yield
  ensure
    $triad_shop_money, $triad_shop_script = was
  end
end
