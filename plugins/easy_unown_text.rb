module PokeAccess
  # ClaraDragon's Easy Unown Text (UnownMessage): a sign written in the Unown font, which a screen reader cannot take as
  # letters; its text is said as the sign lays it out, before the wait for a key that closes it.
  module UnownText
    # The sign's wrapped lines as painted, joined back into one text.
    def self.say(pairs)
      t = PokeAccess.clean((pairs || []).map { |r| r[0].to_s }.join(" "))
      PokeAccess.speak(t, true) unless t.strip.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# initialize paints the sign and then runs pbMain, the wait: the capture brackets that paint.
PokeAccess::Hooks.before_hook("UnownMessage", :initialize, :optional => true) do |_s, _a|
  PokeAccess::PaintCapture.arm(:unown_text)
end
PokeAccess::Hooks.before_hook("UnownMessage", :pbMain, :optional => true) do |_s, _a|
  PokeAccess::UnownText.say(PokeAccess::PaintCapture.take_pairs(:unown_text))
end
