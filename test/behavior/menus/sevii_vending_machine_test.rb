# Sevii's vending machine (games/sevii/vending_machine.rb), the VendingMachineScene of its B2W2 mart script: the
# messages and questions on its own help window, its money window, and the count in the bag of its quantity prompt.

# The vending machine as Sevii defines it, with no superclass: its messages go to its help window, its money window is
# repainted by pbRefresh, and pbChooseNumber shows the question, then makes its two windows, the count in the bag first.
class VendingMachineScene
  attr_reader :sprites
  def initialize(money = "Money:\n$ 3000")
    @sprites = { "helpwindow" => Window_AdvancedTextPokemon.new(""), "moneywindow" => FakeTextWin.new(money) }
  end
  def pbStartBuyScene(_stock, _adapter); :opened; end
  def pbEndBuyScene; :closed; end
  def pbDisplay(msg, _brief = false); @sprites["helpwindow"].text = msg; :shown; end
  def pbDisplayPaused(msg); @sprites["helpwindow"].text = msg; :paused; end
  def pbConfirm(msg); @sprites["helpwindow"].text = msg; true; end
  def pbChooseNumber(helptext, _item, _maximum)
    pbDisplay(helptext, true)
    Window_AdvancedTextPokemon.new("").text = "In Bag:<r>3  "
    Window_AdvancedTextPokemon.new("").text = "x1<r>$ 1500"
    1
  end
end

vending_profiles = PokeAccess::Game.profiles.dup
begin
  vending_path = File.join(Harness::ROOT, "games", "sevii", "vending_machine.rb")
  eval(Harness.source(vending_path), TOPLEVEL_BINDING, vending_path)
ensure
  PokeAccess::Game.profiles.replace(vending_profiles)
  PokeAccess::Game.instance_variable_set(:@profile_name, nil)
end

class SeviiVendingMachineTest < PokeAccessTest
  # Clears the prompt and the amount the number entry spoke last, module state the per-test reset leaves alone.
  def setup
    super
    PokeAccess::Shops.prompt_close
    PokeAccess::NumberEntry.forget
  end

  test "says each message and question its help window shows, queued, as it shows it" do
    machine = VendingMachineScene.new
    assert_equal :paused, machine.pbDisplayPaused("You don't have enough money."), "the message runs as it would"
    assert_equal true, machine.pbConfirm("Selected item: 1 Rare Candy.\r\nPrice: $1500."), "the question answers"
    machine.pbDisplayPaused("1 Rare Candy dropped down!")
    assert_equal [["You don't have enough money.", false], [PokeAccess.clean("Selected item: 1 Rare Candy.\r\nPrice: $1500."), false],
                  ["1 Rare Candy dropped down!", false]], SpeakCapture.log
  end

  test "says the money as the machine opens, queued, and again when a purchase changes it" do
    keeping_live_scene do
      machine = VendingMachineScene.new
      assert_equal :opened, machine.pbStartBuyScene([], nil)
      PokeAccess::InfoWindow.tick
      machine.sprites["moneywindow"].text = "Money:\n$ 1500"
      PokeAccess::InfoWindow.tick
    end
    assert_equal [[money("$ 3000"), false], [money("$ 1500"), false]], SpeakCapture.log
  end

  test "says no money once the machine closes" do
    keeping_live_scene do
      machine = VendingMachineScene.new
      machine.pbStartBuyScene([], nil)
      PokeAccess::InfoWindow.tick
      assert_equal :closed, machine.pbEndBuyScene
      machine.sprites["moneywindow"].text = "Money:\n$ 1500"
      SpeakCapture.clear
      PokeAccess::InfoWindow.tick
    end
    assert_nothing_spoken
  end

  test "the quantity prompt says its question, the first amount, then the count in the bag, queued" do
    assert_equal 1, VendingMachineScene.new.pbChooseNumber("Selected item: Rare Candy.", 1, 99)
    assert_equal [["Selected item: Rare Candy.", false], [amount(1, 1500), false], ["In Bag: 3", false]],
                 SpeakCapture.log
  end

  private

  # The money window's text as the information window says it.
  def money(amount)
    PokeAccess.clean_fields("Money:\n#{amount}")
  end

  # The amount line as the number entry says it.
  def amount(n, price)
    "#{n}, #{PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => price)}"
  end

  # Runs the block, then puts back the scene whose windows were being watched.
  def keeping_live_scene
    held = PokeAccess::InfoWindow.live
    yield
  ensure
    held ? PokeAccess::InfoWindow.enter(held) : PokeAccess::InfoWindow.leave
  end
end
