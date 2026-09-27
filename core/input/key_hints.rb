module PokeAccess
  # The keys the games name in their hints ("[A] Curar", "Pulsa C para acceder"), said as the player has them now:
  # the key bound with the mod's remap, else the one mkxp-z's F1 moved it to. Only the key token changes, and only
  # for the letters the profile lists as buttons (Config.key_hint_letters).
  module KeyHints
    # The letters RPG Maker XP's default keyboard gives the standard buttons, for a game that keeps them.
    RGSS_LETTERS = { "Z" => :a, "X" => :b, "C" => :c, "A" => :x, "S" => :y, "D" => :z, "Q" => :l, "W" => :r }

    # What a sentence puts before the key it asks for ("pulsa la tecla Z", "press Z", "appuie sur C"), in the
    # games' and the mod's languages; the second list names the key without a verb ("con la tecla D").
    VERBS = "pulsa|pulse|pulsando|pulsas|presiona|presionando|aprieta|press|pressing|appuie sur|appuyez sur|dr\\S{1,2}cke|naci\\S{1,2}nij|pressione|carrega"
    KEY_WORDS = "(?:la\\s+|el\\s+|the\\s+|sur\\s+la\\s+)?(?:tecla\\s+|key\\s+|touche\\s+|bot\\S{1,2}n\\s+)?"
    NAMED = "con la tecla|la tecla|con el bot\\S{1,2}n|el bot\\S{1,2}n|the key|la touche"

    # A painted line or sentence that is a key hint: a bracketed key leading it ("[C]: Descripcion"), or a verb that
    # asks for one ("Pulsa F para leer la descripcion completa"), in the games' languages.
    HINT = /\A\[[^\]]{1,16}\]|\A(pulsa|presiona|aprieta|press|appuie|appuyez|dr\S{1,2}cke|naci\S{1,2}nij|pressione|carrega)\s/i

    # The bracketed key that leads a hint line, with the colon after it.
    KEY_TOKEN = /\A\[[^\]]{1,16}\]\s*:?\s*/

    # A screen's painted lines, less its key hints while the verbosity leaves hints out: a hint with a count keeps
    # the count without its key, and a dropped hint takes the "LABEL:" line above it along.
    def self.gate(lines)
      return lines if PokeAccess::Verbosity.hints?
      out = []
      lines.each do |l|
        t = PokeAccess.clean(l.to_s)
        next out.push(l) unless t =~ HINT
        rest = t.sub(KEY_TOKEN, "")
        next out.push(rest) if rest != t && rest =~ /\d/
        out.pop if out.last && PokeAccess.clean(out.last.to_s) =~ /:\z/
      end
      out
    end

    # A painted text, less its key-hint sentences while the verbosity leaves hints out; a sentence ends at a stop
    # before a space or the end, so "6.9 kg" stays whole.
    def self.gate_sentences(text)
      return text if PokeAccess::Verbosity.hints?
      sentences = text.to_s.scan(/.+?(?:[.!?]+(?=\s|\z)|\z)/m).map { |s| s.strip }
      return text unless sentences.any? { |s| s =~ HINT }
      sentences.reject { |s| s.empty? || s =~ HINT }.join(" ")
    end

    # The spoken name of the key the player bound to an action with the mod's remap, or nil while it keeps its own.
    def self.bound_name(sym)
      vk = (PokeAccess::Config.rebinds[sym] rescue nil)
      vk ? PokeAccess::ConfigMenu.keyname(vk) : nil
    end

    # The key to say for an action: the one bound with the mod, else the one F1 moved it to, else the game's.
    # param painted the key's name as the game has it by default
    def self.key(sym, painted)
      bound_name(sym) || PokeAccess::NativeKeys.name(sym, painted) || painted
    end

    # The letters this game paints in its hints and the buttons they stand for (the profile's table).
    def self.table
      PokeAccess::Config.key_hint_letters
    end

    # A hint with each key token of a moved button replaced by the key used now: bracketed ("[A] Curar"), labelling
    # a line ("C/X: Salir") and, with sentences, asked for by a verb ("pulsa la tecla Z"); unlisted letters stay.
    # param letters the painted letters and the buttons they stand for, by default the profile's
    def self.localize(text, letters = nil, sentences = false)
      return text if text.nil? || (PokeAccess::Remap.no_rebinds? && !PokeAccess::NativeKeys.active?)
      letters ||= table
      return text if letters.nil? || letters.empty?
      alt = letters.keys.sort_by { |k| -k.length }.map { |k| Regexp.escape(k) }.join("|")
      swap = lambda { |tok| key(letters[tok], tok) }
      out = text.to_s.gsub(/\[(#{alt})\]/) { "[#{swap.call($1)}]" }
      out = out.gsub(/(\A|\s)((?:#{alt})(?:\/(?:#{alt}))*)(\s?:)(?=\s)/) { $1 + $2.split("/").map { |t| swap.call(t) }.join("/") + $3 }
      return out unless sentences
      out.gsub(/\b(?:(#{VERBS})(\s+#{KEY_WORDS})|(#{NAMED})(\s+))(#{alt})(?![A-Za-z])/i) do
        "#{$1}#{$2}#{$3}#{$4}#{swap.call($5)}"
      end
    end
  end
end
