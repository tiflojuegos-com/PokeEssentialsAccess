module PokeAccess
  # Infinite Fusion 2's payouts (MenuUtils.rb), which count a balance window to the new balance, paint that last and
  # dispose of it: pbReceiveCosmeticsMoney for Glimmer Coins (the heart-scale exchange, a Present, and the dye-kit
  # shop through pbSpendCosmeticMoney, over that shop's window) and pbReceiveMoney for money (the challenge rewards).
  # The balance a payout ends on is said once. The Glimmer Coins window (pbDisplayCosmeticsMoneyWindow), also opened by
  # the dye-kit shop and the \cm message code, is read as core reads the stock money windows, queued, as it is made;
  # core reads the money window that way already.
  module IF2Payouts
    # Takes a window just made as the running payout's, when that payout makes its own.
    def self.take(win)
      @payout[0] ||= win if @payout
    end

    # Says a Glimmer Coins window as it is made, taken for the running payout's.
    def self.made(win)
      take(win)
      PokeAccess.say_money_window(win)
    end

    # Runs a payout over win, the window it is handed, or nil for the one it makes; says the balance its window shows
    # last once it returns, and answers its value.
    def self.payout(win)
      outer = @payout
      @payout = [win]
      ret = yield
      PokeAccess.say_money_window(@payout[0]) if @payout[0]
      ret
    ensure
      @payout = outer
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("pbDisplayCosmeticsMoneyWindow", :after) { |_a, win| PokeAccess::IF2Payouts.made(win) }
  kernel("pbDisplayGoldWindow", :after) { |_a, win| PokeAccess::IF2Payouts.take(win) }
  kernel("pbReceiveCosmeticsMoney", :around) { |args, nxt| PokeAccess::IF2Payouts.payout(args[3]) { nxt.call } }
  kernel("pbReceiveMoney", :around) { |args, nxt| PokeAccess::IF2Payouts.payout(args[3]) { nxt.call } }
end
