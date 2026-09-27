module PokeAccess
  # The language the game runs in (not the one the mod speaks), from Essentials' LANGUAGES table indexed by
  # $PokemonSystem.language, for per-language builds; nil for an untranslated build.
  module GameLang
    # Declared language names (English and native) to codes. Keys hold a-z only, as code strips the rest, so an
    # accented spelling has its own key ("Francais" with a cedilla arrives as "franais").
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

    # Whether a LANGUAGES entry's message file ships (Data/<f>, or messages_<f>[_core|_game].dat for a bare
    # name); forks leave template rows naming files they never ship.
    def self.message_file?(f)
      return false if f.nil? || f.to_s.empty?
      return true if File.exist?("Data/#{f}")
      f.to_s.index(".").nil? &&
        (File.exist?("Data/messages_#{f}_core.dat") || File.exist?("Data/messages_#{f}_game.dat") ||
         File.exist?("Data/messages_#{f}.dat"))
    rescue StandardError
      false
    end

    # The declared name of the running language, or nil when there is none or its message file does not ship.
    # Read live, so an in-game language switch is followed.
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

    # The running build's language code (:en, :fr...), or nil when undeclared or unknown; a prefix match covers
    # qualified names ("English (UK)").
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

    # The running build's entry of a language-keyed hash, else the fallback's; a plain value passes through.
    def self.pick(value, fallback)
      return value unless value.is_a?(Hash)
      c = code
      (c && value[c]) || value[fallback]
    end
  end
end
