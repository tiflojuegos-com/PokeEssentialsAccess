# Every i18n key the code references exists in lang/en.txt: the I18n.t(:key) and t(:key) calls, row labels and
# helps, reading declarations, the keys a profile's names(...) gives the battle name tables, the tables a file
# indexes inside a t( call, and the mod's tables whose symbols reach I18n.t indirectly.
class I18nRefsTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))

  # The explicit I18n.t(:key) call.
  LONG_RE = /I18n\.t\(:([a-zA-Z0-9_]+)/

  # The short t(:key) call, as ConfigMenu.t speaks: the leading guard keeps out another receiver's .t( and an
  # identifier merely ending in t (select(, assert().
  SHORT_RE = /(?:^|[^a-zA-Z0-9_.])t\(:([a-zA-Z0-9_]+)/

  # A row's label or help named as a symbol in a hash (":label => :cat_personal"), which reaches the player through
  # a t( call on a variable that neither call shape can see.
  ROW_RE = /:(?:label|help) => :([a-zA-Z0-9_]+)/

  # A reading a plugin or a profile declares, with the keys of its name and of its help. Only the profiles the
  # suite loads reach the registry, so the declarations are read from the source of every one.
  READING_RE = /define_reading\(:[a-zA-Z0-9_]+,\s*:([a-zA-Z0-9_]+),\s*:([a-zA-Z0-9_]+)\)/

  # A profile's names(:table, n => :key, ...) call, which merges its keys (or literal names) into a Config table the
  # battle reader hands to I18n.t; only the profile the suite loads reaches the table, so every call is read.
  NAMES_RE = /\bnames\(\s*:[a-z_]+\s*,([^)]*)\)/m

  # A key given as the value of one of its pairs.
  PAIR_KEY_RE = /=>\s*:([a-z][a-z0-9_]*)/

  # A constant indexed inside a t( call (`I18n.t(STAGE[stage])`), whose literal in the same file holds the keys.
  INDEXED_RE = /\bt\(\s*([A-Z][A-Z0-9_]+)\[/

  # The symbol such a call falls back to when the table has no entry (`t(FACE[dir] || :face_south)`).
  FALLBACK_RE = /\bt\(\s*[A-Z][A-Z0-9_]+\[[^\]]*\]\s*\|\|\s*:([a-zA-Z0-9_]+)/

  # A symbol of a table literal that is not a hash key.
  TABLE_SYMBOL_RE = /(?<![:\w]):([a-z][a-z0-9_]*)\b(?!\s*=>)/

  test "every key a t call, a row, a reading or a names table names exists in lang/en.txt" do
    refs = {}
    sources.each do |base, src|
      (keys(src) + row_keys(src) + reading_keys(src) + names_keys(src)).each { |k| refs[k] ||= base }
    end
    assert_operator refs.length, :>, 200, "the scan found the references"
    assert_equal [], missing(refs, en_keys), "every referenced key resolves in lang/en.txt"
  end

  test "the short t(:key) shape reaches keys the explicit one never names" do
    long = {}
    short = {}
    sources.each do |_base, src|
      scan(src, LONG_RE).each { |k| long[k] = true }
      scan(src, SHORT_RE).each { |k| short[k] = true }
    end
    assert_operator short.keys.count { |k| !long[k] }, :>, 20
  end

  test "every key of a table indexed inside a t call exists in lang/en.txt" do
    refs = {}
    unresolved = []
    sources.each do |base, src|
      found, lost = indexed_keys(src)
      found.each { |k| refs[k] ||= base }
      unresolved.concat(lost.map { |name| "#{name} (#{base})" })
    end
    assert_equal [], unresolved, "each indexed table's literal is in the file that indexes it"
    assert_operator refs.length, :>, 150, "the scan found the indexed tables"
    assert_equal [], missing(refs, en_keys), "every table key resolves in lang/en.txt"
  end

  test "every key the mod's own tables hand to I18n.t exists in lang/en.txt" do
    tables = mod_tables
    assert_equal [], tables.select { |_name, found| found.empty? }.keys, "every table yields keys"
    refs = {}
    tables.each { |name, found| found.each { |k| refs[k] ||= name } }
    assert_operator refs.length, :>, 300, "the tables hold their keys"
    assert_equal [], missing(refs, en_keys), "every table key resolves in lang/en.txt"
  end

  test "a referenced key missing from lang/en.txt is reported with the file that names it" do
    refs = { "loc_arrived" => "a.rb", "no_such_key" => "b.rb", "secs" => "c.rb" }
    assert_equal ["no_such_key (b.rb)"], missing(refs, known(["loc_arrived", "secs.one", "secs.other"]))
  end

  test "a plural key's forms make its base key present, other suffixes do not" do
    have = known(["secs.one", "secs.other", "beats.few", "turns.many", "odd.zero"])
    assert_equal ["beats", "beats.few", "odd.zero", "secs", "secs.one", "secs.other", "turns", "turns.many"],
                 have.keys.sort
  end

  test "the scanner reads both call shapes" do
    {
      'PokeAccess.speak(PokeAccess::I18n.t(:loc_arrived), true)' => ["loc_arrived"],
      'PokeAccess::I18n.t(:secs, :n => count)' => ["secs"],
      'return t(:rmp_none) if list.empty?' => ["rmp_none"],
      'msg = "#{t(:cfg_saved)}"' => ["cfg_saved"],
      'name = (t(:val_on))' => ["val_on"],
      't(:cat_remap)' => ["cat_remap"],
      'a = t(:val_on) + t(:val_off)' => ["val_on", "val_off"]
    }.each { |line, want| assert_equal want, keys(line), "in: #{line}" }
  end

  test "the scanner ignores another object's t(, an identifier ending in t and a comment's prose" do
    [
      'PokeAccess.clean(win.t(:not_a_key))',
      'rows = list.select(:not_a_key)',
      'assert(:not_a_key)',
      'PokeAccess::Cursor.reset(self, :not_a_key)',
      '# every string is t(:not_a_key), with the text per language in',
      'x = 1 # I18n.t(:not_a_key)'
    ].each { |line| assert_equal [], keys(line), "in: #{line}" }
  end

  test "the scanner reads a row's label and help, not in a comment" do
    assert_equal ["cat_personal", "help_personal"], row_keys("{ :label => :cat_personal, :help => :help_personal }")
    assert_equal [], row_keys("# { :label => :cat_personal }")
  end

  test "the scanner reads a reading's name and help, not in a comment" do
    assert_equal ["vb_party", "vbh_party"], reading_keys("Verbosity.define_reading(:party, :vb_party, :vbh_party)")
    assert_equal [], reading_keys("# define_reading(:party, :vb_party, :vbh_party)")
  end

  test "the scanner reads the keys a names table gives, across lines, not its literal names" do
    src = "names(:weather_names, 9 => :w_aroma, 10 => \"Ceniza\")\n" \
          "names(:field_weather_names, :Storm => :w_storm,\n      :Thunder => :w_wind)\n" \
          "def self.names(species); end\n" \
          "# names(:status_names, 6 => :not_a_key)\n"
    assert_equal ["w_aroma", "w_storm", "w_wind"], names_keys(src)
  end

  test "the scanner reads the keys of a table a t call indexes, not its hash keys, and its fallback" do
    src = <<-'SRC'
      STAGE = { 1 => :berry_planted, :dry => :berry_dry,
                wet: :berry_wet }
      BOTTLES = [["rojo", :rmg_rojo], ["azul", :rmg_azul]]
      KINDS = [:kind_ball, :kind_berry]
      UNUSED = [:not_a_key]
      def a(i)
        PokeAccess::I18n.t(STAGE[i] || :berry_fallback) + t(BOTTLES[i][1]) + t(KINDS[i])
      end
    SRC
    want = ["berry_planted", "berry_dry", "berry_wet", "rmg_rojo", "rmg_azul", "kind_ball", "kind_berry",
            "berry_fallback"]
    assert_equal [want, []], indexed_keys(src)
  end

  test "a table a t call indexes with no literal in that file is reported as unresolved" do
    assert_equal [[], ["ELSEWHERE"]], indexed_keys("def a(i); PokeAccess::I18n.t(ELSEWHERE[i]); end")
  end

  private

  # [file basename, source] of every Ruby file in core, games and plugins.
  def sources
    Dir.glob(File.join(ROOT, "{core,games,plugins}", "**", "*.rb")).sort.map { |f| [File.basename(f), File.read(f)] }
  end

  # The keys lang/en.txt defines, read as I18n reads its tables (values unstripped).
  def en_keys
    all = []
    PokeAccess::KVFile.each(File.join(ROOT, "lang", "en.txt"), :strip_value => false) { |k, _v| all.push(k) }
    known(all)
  end

  # { key => true } for each key, and for the base key of each plural form ("secs.one" makes "secs").
  def known(all)
    out = {}
    all.each do |k|
      out[k] = true
      form = PokeAccess::I18n::PLURAL_KEY.match(k)
      out[form[1]] = true if form
    end
    out
  end

  # The referenced keys ({ key => where }) absent from have (the known keys), as sorted "key (where)" lines.
  def missing(refs, have)
    refs.keys.reject { |k| have[k] }.sort.map { |k| "#{k} (#{refs[k]})" }
  end

  # Source with its comments stripped; "#{" opens an interpolation, not a comment.
  def code(src)
    src.gsub(/#(?!\{).*/, "")
  end

  # The keys a chunk of Ruby source references through one regex's first group, comments stripped first.
  def scan(src, re)
    code(src).scan(re).map { |m| m[0] }.uniq
  end

  # The keys a chunk of source references through either call shape.
  def keys(src)
    (scan(src, LONG_RE) + scan(src, SHORT_RE)).uniq
  end

  # The keys named as a row's label or help.
  def row_keys(src)
    scan(src, ROW_RE)
  end

  # The keys of the readings a chunk of source declares: each one's name, then its help.
  def reading_keys(src)
    code(src).scan(READING_RE).flatten.uniq
  end

  # The keys the names(...) calls of a chunk of source give their tables, in order.
  def names_keys(src)
    code(src).scan(NAMES_RE).map { |(pairs)| pairs.scan(PAIR_KEY_RE).flatten }.flatten.uniq
  end

  # [keys, unresolved names]: the symbols (but hash keys) of each table a t( call of the source indexes, and the
  # fallbacks of those calls, then the indexed tables with no literal in the source.
  def indexed_keys(src)
    body = code(src)
    found = []
    lost = []
    body.scan(INDEXED_RE).flatten.uniq.each do |name|
      lit = table_literal(body, name)
      lit ? found.concat(lit.scan(TABLE_SYMBOL_RE).flatten) : lost.push(name)
    end
    [(found + body.scan(FALLBACK_RE).flatten).uniq, lost]
  end

  # The literal assigned to the constant name in body, from its opening bracket to the one that closes it, or nil.
  def table_literal(body, name)
    m = body.match(/\b#{name}\s*=\s*[\{\[]/)
    return nil unless m
    depth = 0
    (m.end(0) - 1...body.length).each do |i|
      depth += 1 if "{[".include?(body[i])
      depth -= 1 if "}]".include?(body[i])
      return body[(m.end(0) - 1)..i] if depth == 0
    end
    nil
  end

  # { table => the keys it hands to I18n.t }: the menu's rows, groups, units, list names and algorithm helps, the
  # status and weather names, the battle, terrain, category, level and key tables, the verbosity groups and readings,
  # the remap buttons and keys, the speech categories, the scheme actions, the dictionaries and the glossary.
  def mod_tables
    c = PokeAccess::Config
    vb = PokeAccess::Verbosity
    menu = PokeAccess::ConfigMenu
    lists = c::LISTS.select { |_kind, (_values, namer)| namer.is_a?(String) }
    symbols = lambda { |values| values.select { |x| x.is_a?(Symbol) } }
    tables = {
      "Config.settings" => c.settings.map { |s| [s.label, s.help] },
      "Config::KIND_BOUNDS" => c::KIND_BOUNDS.values.map { |b| b[3] },
      "Config.groups" => c.groups.map { |g| g.label },
      "Config::LISTS" => lists.map { |kind, (_values, namer)| c.values_of(kind).map { |x| :"#{namer}#{x}" } },
      "Config algorithms" => c.values_of(:algo).map { |a| :"help_algo_#{a}" },
      "Config.status_names" => symbols.call(c.status_names.values),
      "Config.weather_names" => symbols.call(c.weather_names.values),
      "Battle::WEATHER_SYMS" => PokeAccess::Battle::WEATHER_SYMS.values,
      "Battle::TERRAIN_SYMS" => PokeAccess::Battle::TERRAIN_SYMS.values,
      "Battle::FIELD_WEATHER" => PokeAccess::Battle::FIELD_WEATHER.values,
      "BattleScene::CMD_SYMS" => PokeAccess::BattleScene::CMD_SYMS.values,
      "World::Terrain::LABEL" => PokeAccess::World::Terrain::LABEL.values,
      "Locator::TCAT_KEYS" => PokeAccess::Locator::TCAT_KEYS.values,
      "Verbosity::LEVEL_KEYS" => vb::LEVEL_KEYS.values,
      "ConfigMenu::KEYNAMES" => menu::KEYNAMES.values,
      "Verbosity::GROUPS" => vb::GROUPS.map { |row| row[1] },
      "Remap::BUTTONS" => PokeAccess::Remap::BUTTONS.map { |row| row[2] },
      "Remap::MOD_KEYS" => PokeAccess::Remap::MOD_KEYS.map { |row| row[1] },
      "Speech::CATEGORIES" => PokeAccess::Speech::CATEGORIES.map { |row| row[1] },
      "Verbosity.readings" => vb.readings.map { |row| row[1, 2] },
      "Verbosity::OTHERS_ROW" => vb::OTHERS_ROW[1, 2],
      "ConfigMenu::SCHEME_ACTIONS" => menu::SCHEME_ACTIONS.map { |row| row[1, 2] },
      "ConfigMenu::DICTS" => symbols.call(menu::DICTS.values.map { |d| d.values }.flatten),
      "Sound::Glossary" => PokeAccess::Sound::Glossary.entries.map { |e| e.glossary[0, 2] }
    }
    tables.each_with_object({}) { |(name, found), out| out[name] = found.flatten.compact.map { |s| s.to_s }.uniq }
  end
end
