# Infinite Fusion 2's Glimmer Coins window (games/infinitefusion_hoenn/cosmetics_money.rb): its label and balance said,
# queued, as it opens; a payout counts it to the new balance, which is said once as the payout ends, not on each step
# of the count, whether the payout made the window or was handed the dye-kit shop's; the window and the payout's value
# handed back to the game.

# The game's builder, down to the window it returns: the currency's label over the balance aligned right.
def pbDisplayCosmeticsMoneyWindow(_msgwindow, _x = nil, _y = nil)
  Window_AdvancedTextPokemon.new(_INTL("{2}:\n<ar>{1}</ar>", IfhCosmeticsMoneyGdTest.balance.to_s, "Glimmer Coins"))
end

# The game's payout (MenuUtils.rb), down to its paints: the window it is handed, else one it makes, counted step by
# step to the new balance with the change beside it, then the new balance alone, the text the window keeps once the
# game disposes of it.
def pbReceiveCosmeticsMoney(amount, _show_message = true, msgwindow = nil, goldwindow = nil)
  goldwindow = pbDisplayCosmeticsMoneyWindow(msgwindow) unless goldwindow
  current = IfhCosmeticsMoneyGdTest.balance
  target = current + amount
  step = [amount.abs / 15, 1].max * (amount >= 0 ? 1 : -1)
  sign, color = amount >= 0 ? ["+", "00FF00"] : ["-", "FF0000"]
  while amount >= 0 ? current < target : current > target
    current += step
    current = target if amount >= 0 ? current > target : current < target
    goldwindow.text = "Glimmer Coins:\n<ar>#{current}</ar>\n<ar><c3=#{color}>#{sign} #{amount.abs}</c3></ar>"
  end
  IfhCosmeticsMoneyGdTest.balance = target
  goldwindow.text = "Glimmer Coins:\n<ar>#{target}</ar>"
  :paid
end

# The game's purchase, the payout of the price taken away, over the window the shop shows.
def pbSpendCosmeticMoney(amount, show_message = false, msgwindow = nil, goldwindow = nil)
  pbReceiveCosmeticsMoney(0 - amount, show_message, msgwindow, goldwindow)
end

# The stock money window, which core reads as it opens in the game; no reader of it is bound in this pass.
def pbDisplayGoldWindow(_msgwindow)
  Window_AdvancedTextPokemon.new("Money:\n<ar>$#{IfhCosmeticsMoneyGdTest.money}</ar>")
end

# The game's money payout (MenuUtils.rb, the challenge rewards), counted the same way to the new balance.
def pbReceiveMoney(amount, _show_message = true, msgwindow = nil, goldwindow = nil)
  goldwindow = pbDisplayGoldWindow(msgwindow) unless goldwindow
  target = IfhCosmeticsMoneyGdTest.money + amount
  [IfhCosmeticsMoneyGdTest.money + amount / 2, target].each do |m|
    goldwindow.text = "Money:\n<ar>$#{m}</ar>\n<ar><c3=00FF00>+$#{amount}</c3></ar>"
  end
  IfhCosmeticsMoneyGdTest.money = target
  goldwindow.text = "Money:\n<ar>$#{target}</ar>"
  :paid
end

class IfhCosmeticsMoneyGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "cosmetics_money.rb")

  class << self
    # The player's Glimmer Coins ($Trainer.cosmetics_money) and money ($Trainer.money), as the game keeps them.
    attr_accessor :balance, :money
  end

  # Evaluates the profile file once, as boot does, its wraps bound to the builder and the payout above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # The player starts each test with 450 Glimmer Coins and $3000.
  def setup
    super
    self.class.balance = 450
    self.class.money = 3000
  end

  test "a money payout says the new balance once as it ends, not each step of the count" do
    assert_equal :paid, pbReceiveMoney(1000)
    assert_equal [["Money: $4000", false]], SpeakCapture.log
  end

  test "the balance is said with its label, queued, and the window is the game's" do
    assert_equal "Glimmer Coins:\n<ar>450</ar>", pbDisplayCosmeticsMoneyWindow(nil, 300).text
    assert_equal [["Glimmer Coins: 450", false]], SpeakCapture.log
  end

  test "a payout says the balance as its window opens, then the new one once as it ends, not each step of the count" do
    pbReceiveCosmeticsMoney(300)
    assert_equal [["Glimmer Coins: 450", false], ["Glimmer Coins: 750", false]], SpeakCapture.log
  end

  test "a purchase over the shop's window says the balance it leaves, once" do
    shop = pbDisplayCosmeticsMoneyWindow(nil, 300)
    pbSpendCosmeticMoney(200, false, nil, shop)
    assert_equal [["Glimmer Coins: 450", false], ["Glimmer Coins: 250", false]], SpeakCapture.log
  end

  test "the payout answers as the game's does, and a window made after it is said once, as it opens" do
    assert_equal :paid, pbReceiveCosmeticsMoney(300)
    SpeakCapture.clear
    pbDisplayCosmeticsMoneyWindow(nil)
    assert_equal [["Glimmer Coins: 750", false]], SpeakCapture.log
  end
end
