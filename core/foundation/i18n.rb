module PokeAccess
  # Spoken-string localization by symbolic key: every string is t(:key), with the text per language in
  # lang/<code>.txt. A lookup falls back to the reference language then the key name, so a missing entry
  # is visible but never crashes. Interpolation uses %{name} placeholders.
  module I18n
    REFERENCE = :en
    @cache = {}
    @langs = nil

    # The active language symbol (from Config), or the reference language.
    def self.lang
      (PokeAccess::Config.language rescue REFERENCE) || REFERENCE
    end

    # Translates a key for the active language, interpolating vars (a %{name} => value hash).
    def self.t(key, vars = nil)
      k = key.to_s
      s = table(lang)[k] || table(REFERENCE)[k] || k
      vars ? interpolate(s, vars) : s
    end

    # Substitutes %{name} placeholders in a string from a symbol-keyed hash; a missing var yields "".
    def self.interpolate(s, vars)
      s.gsub(/%\{(\w+)\}/) { (vars[$1.to_sym] rescue nil).to_s }
    end

    # The string table for a language code, cached.
    def self.table(code)
      @cache[code.to_s.to_sym] ||= load_table(code)
    end

    # The language codes with a lang/*.txt file.
    def self.available_languages
      return @langs if @langs
      list = []
      (["#{PokeAccess::Paths::LANG}/*.txt", "lang/*.txt"].each do |pat|
        Dir.glob(pat).each do |f|
          c = File.basename(f, ".txt").to_sym
          list.push(c) unless c.to_s.empty? || list.include?(c)
        end
      end rescue nil)
      list.push(REFERENCE) if list.empty?
      @langs = list
    end

    # The human name of a language (its __language__ entry), for the language menu.
    def self.language_name(code)
      table(code)["__language__"] || code.to_s
    end

    # The next language in the cycle (for the language toggle).
    def self.next_language(code)
      langs = available_languages
      return REFERENCE if langs.empty?
      i = (langs.index(code.to_s.to_sym) || 0)
      langs[(i + 1) % langs.length]
    end

    # Language consistency issues, each as a human "code:key: reason" string -- the boot check and the test
    # suite flag a release with any of: a key present in one language file but missing in another (the usual
    # cause of an English line in a Spanish game); a key DUPLICATED within one file (the later one silently
    # wins); or a key whose %{var} placeholders differ between languages (interpolation breaks in one).
    # __meta__ keys (starting "__") are ignored. Returns [] when everything is in sync. Works on a dup of
    # the language cache and computes set differences with reject, never Array#-: a fangame script patch
    # redefines Array#- as an in-place mutator, so the literal `-` would empty the @langs cache.
    def self.parity_issues
      langs = available_languages.dup
      return [] if langs.length < 2
      tables = {}
      langs.each { |c| tables[c] = table(c) }
      all = tables.values.map { |h| h.keys }.flatten.reject { |k| k.to_s[0, 2] == "__" }.uniq
      out = []
      all.each do |k|
        present = langs.select { |c| tables[c].key?(k) }
        langs.reject { |c| present.include?(c) }.each { |c| out.push("#{c}:#{k}: missing") }
        next if present.length < 2
        vars = present.map { |c| placeholders(tables[c][k]) }
        out.push("#{k}: placeholders differ (#{present.map { |c| "#{c}=#{placeholders(tables[c][k]).inspect}" }.join(' ')})") unless vars.uniq.length == 1
      end
      langs.each { |c| duplicate_keys(c).each { |k| out.push("#{c}:#{k}: duplicated") } }
      out
    rescue StandardError
      []
    end

    # The %{var} placeholder names in a string, sorted (so two strings with the same vars in any order match).
    def self.placeholders(s)
      s.to_s.scan(/%\{(\w+)\}/).flatten.sort.uniq
    end

    # The on-disk path of a language file, or nil.
    def self.table_path(code)
      ["#{PokeAccess::Paths::LANG}/#{code}.txt", "lang/#{code}.txt"].find { |p| File.exist?(p) }
    end

    # Keys that appear more than once in a language file (the table hash hides them; the later value wins).
    def self.duplicate_keys(code)
      seen = {}; dupes = {}
      PokeAccess::KVFile.each(table_path(code).to_s, :strip_value => false) do |k, _v|
        dupes[k] = true if seen[k]
        seen[k] = true
      end
      dupes.keys
    rescue StandardError
      []
    end

    # Parses a lang/<code>.txt into a key => value hash. Values keep their leading spaces (part of the
    # spoken text), hence :strip_value false.
    def self.load_table(code)
      h = {}
      PokeAccess::KVFile.each(table_path(code).to_s, :strip_value => false) { |k, v| h[k] = v }
      h
    rescue StandardError
      h
    end
  end
end
