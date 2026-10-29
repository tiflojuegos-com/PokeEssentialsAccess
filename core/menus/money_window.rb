module PokeAccess
  # The money, coins and points side windows a message opens (\g \cn \pt...): read from the window each
  # pbDisplay*Window returns, whose text carries the game's own label and amount.

  # The cleaned spoken text of a money-style window, or nil.
  def self.money_window_text(win)
    t = (win.text rescue nil)
    return nil if t.nil? || t.to_s.empty?
    clean(t.gsub(/<\/?ar>/i, " ")).gsub(/\s+/, " ").strip
  end

  # Speaks a money-style window's contents, queued: it opens inside pbMessageDisplay, right after the message line.
  def self.say_money_window(win)
    t = money_window_text(win)
    speak(t, false) if t && !t.empty?
  end

  # A money window a function builds by hand from a Window_UnformattedTextPokemon, not a message's: while the function
  # runs, the first such window sized is taken for it, said queued as it is made and again whenever its text changes.
  module MoneyWindow
    # Runs the block, the function's call, with its money window watched; answers the block's value.
    def self.watch
      @open = true
      @window = nil
      @said = nil
      yield
    ensure
      @open = false
      @window = nil
    end

    # A text window just sized: the money window when it is the first one sized while the function runs.
    def self.sized(win)
      return unless @open && @window.nil?
      @window = win
      changed(win)
    end

    # Says the money window's text, filed under the menu, when it differs from the last one said.
    def self.changed(win)
      return unless @open && win.equal?(@window)
      t = PokeAccess.money_window_text(win)
      return if t.nil? || t.empty? || t == @said
      @said = t
      PokeAccess.speak(t, false, :menu)
    end
  end
end

# Reads the window each builder returns; a builder the game lacks is skipped. The last four are added by games or
# plugins: battle-factory points (\ft), heart scales (\hs), quest points (\qp), achievement points (\apw).
%w[pbDisplayGoldWindow pbDisplayCoinsWindow pbDisplayBattlePointsWindow
   pbDisplayBattleFactoryPointsWindow pbDisplayHeartScalesWindow pbDisplayQuestPointsWindow
   pbDisplayAchievementPointsWindow].each do |meth|
  PokeAccess::Hooks.wrap_global(meth, "hook_money", :after) { |_args, r| PokeAccess.say_money_window(r) }
end

# A hand-built money window: the constructor's resizeToFit marks the first one a watched function makes, and text=
# repaints it.
PokeAccess::Hooks.after_hook("Window_UnformattedTextPokemon", :resizeToFit) do |win, _r, _a|
  PokeAccess::MoneyWindow.sized(win)
end
PokeAccess::Hooks.after_hook("Window_UnformattedTextPokemon", :text=) do |win, _r, _a|
  PokeAccess::MoneyWindow.changed(win)
end
