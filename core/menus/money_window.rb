module PokeAccess
  # The money / coins / battle-point side windows (shown by \g \cn \pt in a message) are separate
  # windows, so their value never reaches the dialogue hook. Each pbDisplay*Window returns the window,
  # whose text already carries the game's own localized label and amount (so reading it is engine-agnostic).

  # The cleaned spoken text of a money-style window, or nil.
  def self.money_window_text(win)
    t = (win.text rescue nil)
    return nil if t.nil? || t.to_s.empty?
    clean(t.gsub(/<\/?ar>/i, " ")).gsub(/\s+/, " ").strip
  end

  # Announces a money/coins/battle-points window's contents. Queued, never interrupting: these windows
  # open from INSIDE pbMessageDisplay (the \g \cn \pt control codes), milliseconds after the message that
  # opened them was queued, so an interrupting read cuts the NPC's own sentence to say the amount.
  def self.say_money_window(win)
    t = money_window_text(win)
    speak(t, false) if t && !t.empty?
  end
end

# Each money-style window builder is a top-level method in both engines; read the window it returns.
# No-op for any not defined (gen-6 lacks battle points).
%w[pbDisplayGoldWindow pbDisplayCoinsWindow pbDisplayBattlePointsWindow].each do |meth|
  PokeAccess::Hooks.wrap_global(meth, "hook_money", :after) { |_args, r| PokeAccess.say_money_window(r) }
end
