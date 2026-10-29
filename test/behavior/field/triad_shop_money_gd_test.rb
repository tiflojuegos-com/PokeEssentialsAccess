# The Triple Triad card shop's money window on the GameData engine (core/menus/money_window.rb, watched by the shop's
# wrapper in core/field/minigame_text.rb): each half of the shop says the "Dinero:" window it builds itself, queued as
# it is made and once for each new sum a sale or purchase repaints, and no other text window is.

# Both halves of the shop as the game runs them, down to their money: the window, sized again to fit as the stock
# shop does; $triad_meanwhile, when set, opens whatever else comes up while the player chooses; then the deal repaints
# the window (the new sum set twice).
module TriadMoneyStage
  # One half of the shop: the window painted first with before, then with after; answers result.
  def self.shop(before, after, result)
    gold = Window_UnformattedTextPokemon.newWithSize(before, 0, 0, 32, 32)
    gold.resizeToFit(gold.text, 512)
    $triad_meanwhile.call if $triad_meanwhile
    gold.text = after
    gold.text = after
    result
  end
end

def pbBuyTriads
  TriadMoneyStage.shop("Dinero:\n3.000$", "Dinero:\n2.500$", :bought)
end

def pbSellTriads
  TriadMoneyStage.shop("Dinero:\n2.500$", "Dinero:\n2.875$", :sold)
end

# The gamedata stubs have no card shop, so the mod's shop wrapper bound to nothing as it loaded: its registration is
# evaluated again (as the harness serves it) over the two halves above.
triad_path = File.join(Harness::ROOT, "core", "field", "minigame_text.rb")
triad_src = Harness.source(triad_path)
triad_shop = triad_src.match(/^\["pbBuyTriads", "pbSellTriads"\]\.each do \|fn\|\n.*?^end\n/m)
eval(triad_shop[0], TOPLEVEL_BINDING, triad_path, triad_src[0, triad_shop.begin(0)].count("\n") + 1)

class TriadShopMoneyGdTest < PokeAccessTest
  test "the buying half says its money window queued as it opens, and its new sum once when a purchase repaints it" do
    pbBuyTriads
    assert_equal [["Dinero: 3.000$", false], ["Dinero: 2.500$", false]], SpeakCapture.log
  end

  test "the selling half says its money window as it opens and its new sum after a sale" do
    pbSellTriads
    assert_equal [["Dinero: 2.500$", false], ["Dinero: 2.875$", false]], SpeakCapture.log
  end

  test "says only the shop's own money window, not a window made outside it or after it while the player chooses" do
    Window_UnformattedTextPokemon.new("Antes.").text = "Fuera."
    $triad_meanwhile = lambda do
      other = Window_UnformattedTextPokemon.new("Elige una carta.")
      other.resizeToFit(other.text, 200)
      other.text = "Otra carta."
    end
    pbBuyTriads
    Window_UnformattedTextPokemon.new("Después.").text = "Fuera otra vez."
    assert_equal [["Dinero: 3.000$", false], ["Dinero: 2.500$", false]], SpeakCapture.log
  ensure
    $triad_meanwhile = nil
  end

  test "each half answers as the game's function does, its money said" do
    assert_equal [:bought, :sold], [pbBuyTriads, pbSellTriads]
    assert_equal 4, SpeakCapture.log.length
  end

  test "the money is filed under the menu with the shop's other lines, not under the map the shop opens on" do
    filed = []
    PokeAccess::Speech.observe(:triad_shop_money_test) { |message| filed.push([message.text, message.category]) }
    pbBuyTriads
    assert_equal [["Dinero: 3.000$", :menu], ["Dinero: 2.500$", :menu]], filed
  ensure
    PokeAccess::Speech.unobserve(:triad_shop_money_test)
  end
end
