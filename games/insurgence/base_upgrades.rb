module PokeAccess
  # Insurgence's secret base upgrade shop (Kernel.buySecretBaseUpgrades, 173_Secret_Base_Code.rb): a list of upgrades
  # and, top right, a "Money:" window the function builds and repaints after a purchase. The window is said, queued,
  # as it is made (its first resizeToFit) and whenever its text changes.
  module InsurgenceUpgrades
    # Runs the shop with its money window watched.
    def self.run
      @open = true
      @window = nil
      @said = nil
      yield
    ensure
      @open = false
      @window = nil
    end

    # A text window just sized: the shop's money window when it is the first one made while the shop runs.
    def self.sized(win)
      return unless @open && @window.nil?
      @window = win
      changed(win)
    end

    # Says the money window's text when it differs from the last said.
    def self.changed(win)
      return unless @open && win.equal?(@window)
      t = PokeAccess.money_window_text(win)
      return if t.nil? || t.empty? || t == @said
      @said = t
      PokeAccess.speak(t, false)
    end
  end
end

PokeAccess::Game.define("insurgence") do
  kernel("buySecretBaseUpgrades", :around) { |_args, nxt| PokeAccess::InsurgenceUpgrades.run { nxt.call } }
  after("Window_UnformattedTextPokemon", :resizeToFit, :optional => true) do |w, _r, _a|
    PokeAccess::InsurgenceUpgrades.sized(w)
  end
  after("Window_UnformattedTextPokemon", :text=) { |w, _r, _a| PokeAccess::InsurgenceUpgrades.changed(w) }
end
