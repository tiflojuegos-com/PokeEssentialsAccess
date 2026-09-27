# Awakening's Critical Quotes (JessWishes' Fates cut-in on the finishing blow of nine battles): a portrait and a line
# drawn with Bitmap#draw_text, which no capture sees; draw_text is wrapped only while the cut-in runs.
module PokeAccess
  module AwakeningQuotes
    # Runs the cut-in (the block) with Bitmap#draw_text wrapped to speak what it draws, unwrapped after.
    def self.during
      klass = PokeAccess.const_at("Bitmap")
      return yield if klass.nil? || klass.method_defined?(:draw_text__pa_quote)
      klass.send(:alias_method, :draw_text__pa_quote, :draw_text)
      klass.send(:define_method, :draw_text) do |*args|
        PokeAccess::AwakeningQuotes.drawn(args)
        draw_text__pa_quote(*args)
      end
      begin
        yield
      ensure
        klass.send(:alias_method, :draw_text, :draw_text__pa_quote)
        klass.send(:remove_method, :draw_text__pa_quote)
      end
    end

    # Speaks a line the cut-in draws, queued: the text argument, fifth after x, y, width and height, or second after
    # a rect.
    def self.drawn(args)
      text = args.length >= 5 ? args[4] : args[1]
      PokeAccess.speak_clean(text.to_s, false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  around("Critical_Quotes", :initialize) { |_s, nxt, _a| PokeAccess::AwakeningQuotes.during { nxt.call } }
end
