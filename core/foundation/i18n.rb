module PokeAccess
  # Spoken strings by key: t(:key) reads lang/<code>.txt, falling back to the reference language, then the key
  # name. %{name} placeholders interpolate; plural forms ("key.one=", "key.other=", plus "key.few=" and
  # "key.many=" where the language has them) are picked by vars[:n].
  module I18n
    REFERENCE = :en

    # Each language's plural rule (CLDR); one not listed uses the singular for 1 only.
    PLURAL_RULES = { "fr" => :zero_one, "pt" => :zero_one, "pl" => :polish }

    # A lang/ key written as one of its plural forms: the key and the form.
    PLURAL_KEY = /\A(.+)\.(one|few|many|other)\z/
    @cache = {}
    @langs = nil
    @auto = nil
    @auto_key = nil

    # The automatic choice: not a file but a rule, resolved by auto_lang.
    AUTO = :auto

    # The active language: the player's choice, or auto_lang when the setting is :auto or unset.
    def self.lang
      c = (PokeAccess::Config.language rescue nil)
      (c.nil? || c == AUTO) ? auto_lang : c
    end

    # What :auto resolves to (resolve_auto), memoised on the game's language index once GameLang and SystemLang
    # have loaded (t() already runs while the core loads).
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

    # The first language with a file among: the system's, its shipped neighbour (Catalan to Spanish), the game's
    # declared one, English, Spanish.
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
      s = entry(lang, k, vars) || entry(REFERENCE, k, vars) || k
      vars ? interpolate(s, vars) : s
    end

    # A key's text in one language: its plain entry, or the plural form its file writes for vars[:n].
    def self.entry(code, k, vars)
      tbl = table(code)
      tbl[k] || tbl["#{k}.#{plural_form(code, vars ? vars[:n] : nil)}"]
    end

    # The plural form for n in a language ("one", "few", "many" or "other"). A decimal takes "other" save in
    # French and Portuguese, which go by its whole part; a missing n counts as 0.
    def self.plural_form(code, n)
      i = (n.to_i rescue 0).abs
      rule = PLURAL_RULES[code.to_s]
      return (i <= 1 ? "one" : "other") if rule == :zero_one
      return "other" if n.is_a?(Float) && n != n.floor
      return (i == 1 ? "one" : "other") unless rule == :polish
      return "one" if i == 1
      (2..4).include?(i % 10) && !(12..14).include?(i % 100) ? "few" : "many"
    end

    # The forms a language writes for a key that changes with its count. Polish has no form for a decimal, so a
    # Polish key written by forms only ever takes whole numbers.
    def self.plural_forms(code)
      PLURAL_RULES[code.to_s] == :polish ? %w[one few many] : %w[one other]
    end

    # A number as the active language writes it: a fraction with the separator its decimal_sep entry names.
    def self.number(x)
      x.is_a?(Float) ? x.to_s.sub(".", t(:decimal_sep).to_s) : x.to_s
    end

    # Substitutes %{name} placeholders in a string from a symbol-keyed hash; a missing var yields "".
    def self.interpolate(s, vars)
      s.gsub(/%\{(\w+)\}/) { (vars[$1.to_sym] rescue nil).to_s }
    end

    # The cached string table for a language; a blank code reads REFERENCE ("".to_sym raises on 1.8.7).
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

    # A language's own name (its __language__ entry); :auto is named after what it resolves to, guarded against
    # resolving to :auto, which would recurse forever.
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

    # Language consistency issues as "code:key: reason" strings, [] when in sync: a key missing from a language,
    # duplicated in a file, with differing %{var}s, or with wrong plural forms. "__" keys are ignored.
    def self.parity_issues
      langs = available_languages.dup
      return [] if langs.length < 2
      tables = {}
      langs.each { |c| tables[c] = table(c) }
      out = parity_of(tables)
      langs.each { |c| duplicate_keys(c).each { |k| out.push("#{c}:#{k}: duplicated") } }
      out
    rescue StandardError
      []
    end

    # The parity issues between language tables ({code => {key => text}}), duplicates aside (the tables fold them).
    def self.parity_of(tables)
      langs = tables.keys
      keyed = {}
      langs.each { |c| keyed[c] = by_key(tables[c]) }
      all = keyed.values.map { |h| h.keys }.flatten.reject { |k| k.to_s[0, 2] == "__" }.uniq
      out = []
      all.each do |k|
        present = langs.select { |c| keyed[c].key?(k) }
        langs.reject { |c| present.include?(c) }.each { |c| out.push("#{c}:#{k}: missing") }
        present.each { |c| out.concat(form_issues(c, k, keyed[c][k])) }
        vars = present.map { |c| keyed[c][k].values.map { |s| placeholders(s) } }
        next if vars.flatten(1).uniq.length <= 1
        out.push("#{k}: placeholders differ (#{present.map { |c| "#{c}=#{placeholders(keyed[c][k].values.join(' ')).inspect}" }.join(' ')})")
      end
      out
    end

    # A language table grouped by key: {key => {form => text}}, where a plain entry's form is nil.
    def self.by_key(tbl)
      out = {}
      tbl.each do |k, v|
        m = PLURAL_KEY.match(k)
        (out[m ? m[1] : k] ||= {})[m ? m[2] : nil] = v
      end
      out
    end

    # What is wrong with how one language writes a key's forms: written both plain and by forms, or by forms
    # that are not exactly the ones its plural rule asks for.
    def self.form_issues(code, k, forms)
      return [] if forms.keys == [nil]
      return ["#{code}:#{k}: written both plain and by plural forms"] if forms.key?(nil)
      need = plural_forms(code)
      out = []
      need.each { |f| out.push("#{code}:#{k}.#{f}: plural form missing") unless forms.key?(f) }
      forms.keys.each { |f| out.push("#{code}:#{k}.#{f}: not a plural form of #{code}") unless need.include?(f) }
      out
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
