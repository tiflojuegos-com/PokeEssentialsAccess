# Yuko115's Blackjack (BES, pbBlackJack, a top-level function with its own loop): the offers and the results are standard
# messages, so what is added is the player's total, the one number it paints, said whenever it changes.
module PokeAccess
  module BesBlackjack
    @playing = false
    @last_total = nil

    # Runs the game's loop with its paint watched; the total said last is forgotten as it starts and as it ends.
    def self.playing
      @playing = true
      @last_total = nil
      yield
    ensure
      @playing = false
      @last_total = nil
    end

    # The player's total, painted alone before each offer to draw a card, said once per value and queued behind the
    # messages that came before it.
    # param rows the text positions a paint was handed, [text, x, y, ...] each
    def self.painted(rows)
      return unless @playing && rows.is_a?(Array) && rows.length == 1 && rows[0].is_a?(Array)
      total = rows[0][0].to_s.strip
      return unless total =~ /\A\d+\z/
      return if total == @last_total
      @last_total = total
      PokeAccess.speak(PokeAccess::I18n.t(:bjack_total, :n => total), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbBlackJack", "plugin_bes_blackjack", :around) do |_args, call_next|
  PokeAccess::BesBlackjack.playing { call_next.call }
end
PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "plugin_bes_blackjack_total", :before) do |args, _r|
  PokeAccess::BesBlackjack.painted(args[1])
end
