# Every i18n key the code references exists in lang/en.txt: literal I18n.t(:key) and t(:key) calls, row labels and
# helps, reading declarations and the known tables whose symbols reach I18n.t indirectly.
module I18nRefScan
  # The explicit I18n.t(:key) call.
  LONG_RE = /I18n\.t\(:([a-zA-Z0-9_]+)/

  # The short t(:key) call, as ConfigMenu.t speaks: the leading guard keeps out another receiver's .t( and an
  # identifier merely ending in t (select(, assert().
  SHORT_RE = /(?:^|[^a-zA-Z0-9_.])t\(:([a-zA-Z0-9_]+)/

  # The keys a chunk of Ruby source references through a given shape. Comments are stripped first:
  # i18n.rb's own header says "every string is t(:key)" and would otherwise be read as a reference.
  def self.scan(src, re)
    out = []
    src.gsub(/#(?!\{).*/, "").scan(re) { |m| out.push(m[0]) }
    out.uniq
  end

  # The keys referenced through the explicit I18n.t( call.
  def self.long_keys(src); scan(src, LONG_RE); end

  # The keys referenced through the short t( call.
  def self.short_keys(src); scan(src, SHORT_RE); end

  # A row's label or help named as a symbol in a hash (":label => :cat_personal"), which reaches the player through
  # a t( call on a variable that neither call shape can see.
  ROW_RE = /:(?:label|help) => :([a-zA-Z0-9_]+)/

  # The keys named as a row's label or help.
  def self.row_keys(src); scan(src, ROW_RE); end

  # A reading a plugin or a profile declares, with the keys of its name and of its help. Only the profiles the
  # suite loads reach the registry, so the declarations are read from the source of every one.
  READING_RE = /define_reading\(:[a-zA-Z0-9_]+,\s*:([a-zA-Z0-9_]+),\s*:([a-zA-Z0-9_]+)\)/

  # The keys of the readings a chunk of source declares.
  def self.reading_keys(src)
    out = []
    src.gsub(/#(?!\{).*/, "").scan(READING_RE) { |m| out.push(m[0], m[1]) }
    out.uniq
  end

  # Every key a chunk of source references, in either shape.
  def self.keys(src); (long_keys(src) + short_keys(src)).uniq; end
end

Suite.define("static: code-referenced i18n keys exist in lang/en.txt") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  en = {}
  PokeAccess::KVFile.each(File.join(root, "lang", "en.txt"), :strip_value => false) do |k, _v|
    en[k] = true
    form = PokeAccess::I18n::PLURAL_KEY.match(k)
    en[form[1]] = true if form
  end
  truthy "lang/en.txt loaded", en.length > 100

  # Exempt key prefixes. Empty, and meant to stay so: the scanners never match a runtime-built key anyway.
  dynamic_prefixes = []

  refs = {}
  long_seen = {}
  short_only = {}
  Dir.glob(File.join(root, "{core,games,plugins}", "**", "*.rb")).each do |f|
    base = File.basename(f)
    src = File.read(f)
    I18nRefScan.long_keys(src).each { |k| long_seen[k] = true; refs[k] ||= base }
    I18nRefScan.short_keys(src).each { |k| short_only[k] = true; refs[k] ||= base }
    I18nRefScan.row_keys(src).each { |k| refs[k] ||= base }
    I18nRefScan.reading_keys(src).each { |k| refs[k] ||= base }
  end
  short_only.delete_if { |k, _v| long_seen[k] }
  truthy "the short t(:key) shape found keys the explicit one cannot", short_only.length > 20
  truthy "the scan found a realistic number of references", refs.length > 200

  table_syms = []
  PokeAccess::Config::SCHEMA.each { |row| table_syms.push(row[4], row[5]) }
  PokeAccess::Config::KIND_BOUNDS.each_value { |b| table_syms.push(b[3]) if b[3] }
  PokeAccess::Config::CATEGORIES.each { |row| table_syms.push(row[1]) }
  (PokeAccess::Config.categories rescue []).each { |c| table_syms.push(:"tcat_#{c}") }
  (PokeAccess::Config.status_names rescue {}).each_value { |v| table_syms.push(v) if v.is_a?(Symbol) }
  (PokeAccess::Config.weather_names rescue {}).each_value { |v| table_syms.push(v) if v.is_a?(Symbol) }
  [:WEATHER_SYMS, :TERRAIN_SYMS, :FIELD_WEATHER].each do |cn|
    t = (PokeAccess::Battle.const_get(cn) rescue nil)
    t.each_value { |v| table_syms.push(v) } if t.is_a?(Hash)
  end
  cmd = (PokeAccess::BattleScene::CMD_SYMS rescue nil)
  cmd.each_value { |v| table_syms.push(v) } if cmd.is_a?(Hash)
  lbl = (PokeAccess::Terrain::LABEL rescue nil)
  lbl.each_value { |v| table_syms.push(v) } if lbl.is_a?(Hash)
  PokeAccess::Remap::BUTTONS.each { |row| table_syms.push(row[2]) }
  PokeAccess::Remap::MOD_KEYS.each { |row| table_syms.push(row[1]) }
  PokeAccess::Speech::CATEGORIES.each { |row| table_syms.push(row[1]) }
  PokeAccess::Verbosity.readings.dup.push(PokeAccess::Verbosity::OTHERS_ROW).each { |row| table_syms.push(row[1], row[2]) }
  PokeAccess::Verbosity::LEVEL_KEYS.each_value { |v| table_syms.push(v) }
  PokeAccess::ConfigMenu::KEYNAMES.each_value { |v| table_syms.push(v) }
  PokeAccess::ConfigMenu::SCHEME_ACTIONS.each { |row| table_syms.push(row[1]) }
  PokeAccess::ConfigMenu::DICTS.each_value { |d| d.each_value { |v| table_syms.push(v) if v.is_a?(Symbol) } }
  PokeAccess::SoundGlossary::ENTRIES.each { |e| table_syms.push(e[2]); table_syms.push(e[3]) }
  table_syms.compact.each { |s| refs[s.to_s] ||= "(table)" }
  truthy "the surf_ family arrives through Terrain::LABEL", refs.keys.select { |k| k.index("surf_") == 0 }.length >= 10

  missing = refs.keys.reject do |k|
    en[k] || dynamic_prefixes.any? { |p| k.index(p) == 0 }
  end
  eq "every referenced key resolves in lang/en.txt", missing.sort.map { |k| "#{k} (#{refs[k]})" }, []
end

# The scanner's contract on synthetic lines: both call shapes are read.
Suite.define("static: the i18n reference scanner reads both call shapes") do
  seen = {
    'PokeAccess.speak(PokeAccess::I18n.t(:loc_arrived), true)' => "loc_arrived",
    'PokeAccess::I18n.t(:secs, :n => count)' => "secs",
    'return t(:rmp_none) if list.empty?' => "rmp_none",
    'msg = "#{t(:cfg_saved)}"' => "cfg_saved",
    'name = (t(:val_on))' => "val_on",
    't(:cat_remap)' => "cat_remap"
  }
  seen.each { |line, key| truthy "scanner reads #{key} in: #{line}", I18nRefScan.keys(line).include?(key) }
end

# The lookalikes the short shape keeps out: another object's t(, an identifier ending in t, a comment's prose.
Suite.define("static: the i18n reference scanner ignores lookalikes") do
  ignored = [
    'PokeAccess.clean(win.t(:not_a_key))',
    'rows = list.select(:not_a_key)',
    'assert(:not_a_key)',
    'PokeAccess::Cursor.reset(self, :not_a_key)',
    '# every string is t(:not_a_key), with the text per language in'
  ]
  ignored.each { |line| falsy "scanner ignores: #{line}", I18nRefScan.keys(line).include?("not_a_key") }
end
