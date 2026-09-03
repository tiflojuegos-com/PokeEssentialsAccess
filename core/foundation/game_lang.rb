module PokeAccess
  # The language the GAME is running in, which is not the language the MOD speaks. A fangame shipped as
  # several per-language builds (Pokemon Z: es, en, fr) paints different words in each, and a transcription
  # of an image must say what THAT build painted -- reading a Spanish transcription to someone running the
  # English build would report a screen that is not there.
  #
  # Asked of the game rather than guessed: seven of the gen-6 dumps declare Essentials' own LANGUAGES table
  # ([display name, message file] pairs) and $PokemonSystem.language indexes it, which is the very decision
  # the game makes when it picks its own text. An empty or absent table means the build was never
  # translated, so it runs in whatever language it was authored in -- nil here, and the profile says what
  # that is.
  module GameLang
    # Declared names to language codes. The author writes these by hand, so the English and the native
    # spelling both appear in the wild, and the ACCENT-STRIPPED spellings are here as their own keys:
    # under 1.8.7 a String is bytes, downcase touches ascii only, and the lookup key drops everything
    # outside a-z -- so "Francais" with a cedilla arrives as "franais", not as "francais".
    NAMES = {
      "english" => :en, "ingles" => :en,
      "spanish" => :es, "espanol" => :es, "espaol" => :es, "castellano" => :es,
      "french" => :fr, "francais" => :fr, "franais" => :fr, "frances" => :fr,
      "german" => :de, "deutsch" => :de, "aleman" => :de,
      "italian" => :it, "italiano" => :it,
      "portuguese" => :pt, "portugues" => :pt, "portugus" => :pt,
      "polish" => :pl, "polski" => :pl, "polaco" => :pl,
      "japanese" => :ja, "korean" => :ko
    }

    # The LANGUAGES table wherever the era keeps it (gen-6 top-level, modern Settings::), or nil.
    def self.languages_table
      t = (::LANGUAGES rescue nil)
      t = (::Settings::LANGUAGES rescue nil) unless t.is_a?(Array)
      t.is_a?(Array) ? t : nil
    end

    # A LANGUAGES entry only counts when the message file it names actually ships: the Essentials template
    # comes with ["English","english.dat"] rows and lazy forks leave them in without ever shipping the
    # file (infinitefusion_hoenn declares en+fr over a lone messages.dat). The file's absence is what
    # separates a declaration the game lives by from template residue -- reminiscencia's index 0 names a
    # spanish.dat nobody ships (its base text is already Spanish) while its English entry's file is real,
    # and the game itself only changes language when the file loads.
    def self.message_file?(f)
      return false if f.nil? || f.to_s.empty?
      return true if File.exist?("Data/#{f}")
      f.to_s.index(".").nil? &&
        (File.exist?("Data/messages_#{f}_core.dat") || File.exist?("Data/messages_#{f}.dat"))
    rescue StandardError
      false
    end

    # The name the game declares for the language it is running in, or nil when it declares none (or the
    # declared entry's message file does not ship). Reads $PokemonSystem.language live, so a game with an
    # in-game language switch is followed as the player flips it.
    def self.declared_name
      table = languages_table
      return nil unless table && !table.empty?
      i = ($PokemonSystem.language.to_i rescue 0)
      i = 0 if i < 0 || i >= table.length
      entry = table[i]
      name = entry.is_a?(Array) ? entry[0] : entry
      file = entry.is_a?(Array) ? entry[1] : nil
      return nil if name.nil? || name.to_s.empty?
      return nil unless message_file?(file)
      name.to_s
    rescue StandardError
      nil
    end

    # The running build's language code (:en, :fr, ...), or nil when the game declares none or names a
    # language this table does not know. A prefix match catches the qualified spellings ("English (UK)",
    # "Espanol latino") without listing every one.
    def self.code
      n = declared_name
      return nil unless n
      key = n.to_s.downcase.gsub(/[^a-z]/, "")
      return NAMES[key] if NAMES.has_key?(key)
      hit = NAMES.keys.find { |k| key.index(k) == 0 }
      hit ? NAMES[hit] : nil
    rescue StandardError
      nil
    end

    # Picks the entry matching the running build from a language-keyed hash, falling back to the language
    # the strings were authored in. A plain value passes straight through, so a game shipped as a single
    # build needs no hash at all.
    def self.pick(value, fallback)
      return value unless value.is_a?(Hash)
      c = code
      (c && value[c]) || value[fallback]
    end
  end
end
