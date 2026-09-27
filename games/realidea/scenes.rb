# Two of Realidea's own scenes: the refutation screen the move CHIGAUYO opens in battle (Danganronpa), said as it
# waits for a key and as the argument breaks; and the ending's credits (Credit#textofade1, and textofade before
# them), each block said once as it is painted, though Credit repaints one of them every frame.
module PokeAccess
  module RealideaScenes
    # The DANGER banner the screen waits under, with the key that breaks it.
    def self.danger
      parts = [PokeAccess::I18n.t(:rea_dg_danger)]
      parts.push(PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:rea_dg_key))) if PokeAccess::Verbosity.hints?
      PokeAccess.speak(PokeAccess.sentences(parts), true)
    end

    # A credits block as one line: its heading, then its names ("MÚSICA: emdasche, Kunning Fox, Jobless Music").
    def self.credits_text(raw)
      lines = raw.to_s.gsub(/<\/?[A-Za-z][^>]*>/, "").split("\n").map { |l| PokeAccess.clean(l) }.reject { |l| l.empty? }
      return "" if lines.empty?
      lines.length > 1 ? "#{lines[0]}: #{lines[1..-1].join(', ')}" : lines[0]
    end

    # Speaks a credits block, queued behind whatever is being said; with a holder (the Credit scene), only when its
    # text differs from the block that holder painted last.
    def self.credits(raw, holder = nil)
      t = credits_text(raw)
      return if t.empty?
      return if holder && !PokeAccess::Cursor.changed?(holder, :rea_credits, t)
      PokeAccess.speak(t, false)
    end
  end
end

PokeAccess::Game.define("realidea") do
  before("Danganronpa", :actu, :optional => true) { |_s, _a| PokeAccess::RealideaScenes.danger }
  before("Danganronpa", :rompido, :optional => true) { |_s, _a| PokeAccess.speak(PokeAccess::I18n.t(:rea_dg_break), true) }
  before("Credit", :textofade1, :optional => true) { |s, a| PokeAccess::RealideaScenes.credits(a[0], s) }
  kernel("textofade", :before) { |a, _r| PokeAccess::RealideaScenes.credits(a[0]) }
end
