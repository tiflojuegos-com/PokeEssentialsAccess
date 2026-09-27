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
end

# Reads the window each builder returns; a builder the game lacks is skipped. The last four are added by games or
# plugins: battle-factory points (\ft), heart scales (\hs), quest points (\qp), achievement points (\apw).
%w[pbDisplayGoldWindow pbDisplayCoinsWindow pbDisplayBattlePointsWindow
   pbDisplayBattleFactoryPointsWindow pbDisplayHeartScalesWindow pbDisplayQuestPointsWindow
   pbDisplayAchievementPointsWindow].each do |meth|
  PokeAccess::Hooks.wrap_global(meth, "hook_money", :after) { |_args, r| PokeAccess.say_money_window(r) }
end
