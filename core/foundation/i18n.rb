module PokeAccess
  # Spoken-string localization by symbolic key: every string is t(:key), with the text per language in
  # lang/<code>.txt. A lookup falls back to the reference language then the key name, so a missing entry
  # is visible but never crashes. Interpolation uses %{name} placeholders.
  module I18n
    REFERENCE = :en
    @cache = {}
    @langs = nil
    @auto = nil
    @auto_key = nil

    # The automatic choice: not a file but a rule, resolved by auto_lang.
    AUTO = :auto

    # The active language symbol: the player's explicit choice, or the automatic resolution when the
    # setting is :auto (or unset).
    def self.lang
      c = (PokeAccess::Config.language rescue nil)
      (c.nil? || c == AUTO) ? auto_lang : c
    end

    # What :auto resolves to: the system's language, then the one the game declares it is running in, then
    # English, then Spanish -- the first the mod has a file for. Memoised on the game's language index, the
    # one input that moves during play (an in-game language switch), and only once both detectors have
    # loaded: t() already runs while the core is loading, and a verdict taken before GameLang exists would
    # pin English for the rest of the session.
    def self.auto_lang
      key = (defined?($PokemonSystem) && $PokemonSystem) ? ($PokemonSystem.language rescue nil) : nil
      return @auto if @auto && @auto_key == key
      pick = resolve_auto
      if defined?(PokeAccess::GameLang) && defined?(PokeAccess::SystemLang)
        @auto = pick
        @auto_key = key
      end
      pick
    end

    # The player's own language first: the mod's voice is the mod's interface, not the game's text. A system
    # language the mod lacks tries its shipped neighbour (Catalan to Spanish) before the game's declaration.
    def self.resolve_auto
      avail = available_languages
      sys = (PokeAccess::SystemLang.code rescue nil)
      near = (PokeAccess::SystemLang.neighbour(sys) rescue nil)
      game = (PokeAccess::GameLang.code rescue nil)
      [sys, near, game, REFERENCE, :es].each { |c| return c if c && avail.include?(c) }
      REFERENCE
    end

    # Drops the memoised automatic verdict, so the next lookup resolves again (tests).
    def self.forget_auto
      @auto = nil
      @auto_key = nil
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

    # The string table for a language code, cached. A blank code reads the reference table: "".to_sym raises
    # under 1.8.7, and a raw language setting is the one place a blank can come from.
    def self.table(code)
      sym = code.to_s.empty? ? REFERENCE : code.to_s.to_sym
      @cache[sym] ||= load_table(sym)
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

    # The human name of a language (its __language__ entry) for the language menu; the automatic entry is
    # named after what it resolved to. resolve_auto only ever answers with a code from lang/, so it cannot
    # answer :auto -- but the recursion here would HANG the game rather than misread a word, so the one
    # thing it must not do is trust that.
    def self.language_name(code)
      if code.to_s == AUTO.to_s
        pick = auto_lang
        return code.to_s if pick.to_s == AUTO.to_s
        return t(:lang_auto, :name => language_name(pick))
      end
      table(code)["__language__"] || code.to_s
    end

    # The next entry of the language cycle (for the toggle): automatic first, then every file in lang/.
    def self.next_language(code)
      cycle = [AUTO].concat(available_languages)
      cur = code.to_s.empty? ? AUTO : code.to_s.to_sym
      i = (cycle.index(cur) || 0)
      cycle[(i + 1) % cycle.length]
    end

    # Language consistency issues, each as a human "code:key: reason" string -- the boot check and the test
    # suite flag a release with any of: a key present in one language file but missing in another (the usual
    # cause of an English line in a Spanish game); a key DUPLICATED within one file (the later one silently
    # wins); or a key whose %{var} placeholders differ between languages (interpolation breaks in one).
    # __meta__ keys (starting "__") are ignored. Returns [] when everything is in sync. Works on a dup of
    # the language cache, which is memoised and must survive the check.
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
    rescue StandardError => e
      (PokeAccess.log_once("i18n_dupes_#{code}", e) rescue nil)
      []
    end

    # Parses a lang/<code>.txt into a key => value hash. Values keep their leading spaces (part of the
    # spoken text), hence :strip_value false.
    def self.load_table(code)
      h = {}
      PokeAccess::KVFile.each(table_path(code).to_s, :strip_value => false) { |k, v| h[k] = v }
      h
    rescue StandardError => e
      (PokeAccess.log_once("i18n_load_#{code}", e) rescue nil)
      h
    end
  end
end
