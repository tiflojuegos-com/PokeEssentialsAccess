module PokeAccess
  # The fixed panel a pause menu paints beside its options (level cap, money, badges, map, shortcut keys...), said
  # after the focused option on open: only the lines new since the last opening. Readers leave out any clock.
  module PausePanel
    @last = []

    # Says the lines not said at the last opening, minus shortcut keys while hints are off. Uses reject, not
    # Array#-, which Pokemon Z redefines.
    # param lines the panel's lines in reading order, or one string for a panel of one line
    def self.say(lines)
      now = PokeAccess::KeyHints.gate(Array(lines)).map { |l| PokeAccess::KeyHints.localize(PokeAccess.clean(l.to_s)) }.reject { |l| l.empty? }
      fresh = now.reject { |l| @last.include?(l) }
      @last = now
      PokeAccess.speak(PokeAccess.sentences(fresh), false, :menu) unless fresh.empty?
    end

    # The panel's lines from a menu's capture, minus painted option labels, dropped before rows are joined so a label
    # cannot join a panel row at its height.
    def self.lines(pairs, labels = [])
      skip = Array(labels).map { |l| PokeAccess.clean(l.to_s) }
      PokeAccess::PaintCapture.lines(pairs) { |r| !skip.include?(PokeAccess.clean(r[0].to_s)) }
    end
  end
end
