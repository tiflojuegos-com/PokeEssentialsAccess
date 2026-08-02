# Static check: every i18n key the CODE references must exist in lang/en.txt (the reference language;
# the parity spec already keeps es<->en in sync). Without this, a key used in code but missing from both
# lang files speaks its raw key name at the player and nothing fails -- it happened (the throw_* battle
# commands). Sources checked: literal I18n.t(:key) calls across core+games, plus the known tables whose
# symbols reach I18n.t indirectly (Config SCHEMA labels/help, KIND_BOUNDS units, category names,
# status/weather/terrain tables, battle CMD_SYMS, Remap button labels). Keys built dynamically
# (:"chr_#{kind}"...) cannot be greppd, so their families are declared as allowed prefixes here -- add
# the prefix when you introduce a new dynamic family.
Suite.define("static: code-referenced i18n keys exist in lang/en.txt") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  en = {}
  PokeAccess::KVFile.each(File.join(root, "lang", "en.txt"), :strip_value => false) { |k, _v| en[k] = true }
  truthy "lang/en.txt loaded", en.length > 100

  # w_ and st_ are deliberately NOT here: their families are not unscannable -- every valid symbol
  # arrives through the status/weather tables below, so exempting the prefix would exempt exactly the
  # keys those tables are meant to enforce (any st_typo in a table would pass CI).
  dynamic_prefixes = ["chr_", "surf_", "dir_", "tcat_", "puzzle_", "aw_c", "lang_"]

  refs = {}
  Dir.glob(File.join(root, "{core,games,plugins}", "**", "*.rb")).each do |f|
    File.read(f).scan(/I18n\.t\(:([a-zA-Z0-9_]+)/) { |m| refs[m[0]] ||= File.basename(f) }
  end
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
  PokeAccess::Remap::BUTTONS.each { |row| table_syms.push(row[2]) }
  PokeAccess::SoundGlossary::ENTRIES.each { |e| table_syms.push(e[2]); table_syms.push(e[3]) }
  table_syms.compact.each { |s| refs[s.to_s] ||= "(table)" }

  missing = refs.keys.reject do |k|
    en[k] || dynamic_prefixes.any? { |p| k.index(p) == 0 }
  end
  eq "every referenced key resolves in lang/en.txt", missing.sort.map { |k| "#{k} (#{refs[k]})" }, []
end
