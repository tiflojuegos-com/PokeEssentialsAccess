# Static check: every i18n key the CODE references must exist in lang/en.txt (the reference language;
# the parity spec already keeps es<->en in sync). Without this, a key used in code but missing from both
# lang files speaks its raw key name at the player and nothing fails -- it happened (the throw_* battle
# commands). Sources checked: literal I18n.t(:key) calls across core+games, the short t(:key) form of the
# same call, plus the known tables whose symbols reach I18n.t indirectly (Config SCHEMA labels/help,
# KIND_BOUNDS units, category names, status/weather/terrain tables, battle CMD_SYMS, Remap button labels).
# Keys built dynamically (:"chr_#{kind}"...) cannot be greppd, so their families are declared as allowed
# prefixes here -- add the prefix when you introduce a new dynamic family.
module I18nRefScan
  # The explicit call. Anchoring ONLY on this shape is what left the settings/remap menu unscanned.
  LONG_RE = /I18n\.t\(:([a-zA-Z0-9_]+)/

  # The short call. The settings/remap menu speaks through ConfigMenu.t, a one-line alias of I18n.t
  # in config_menu.rb, so 29 of its keys (rmp_*, cfg*, cat_remap, rec_*, key_*...) reach the player through
  # a call the long form cannot see: a typo in any of them speaks the raw key name with CI green, which is
  # the failure this spec exists to catch. The leading guard is what keeps the short shape
  # honest -- it must not match some OTHER receiver's t( (a bare "\.t\(" matches anything.t) nor the tail
  # of an identifier that happens to end in t (select(, assert(). Written as an alternation and not as a
  # lookbehind, which the 1.8.7 the mod targets cannot parse.
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

  # Every key a chunk of source references, in either shape.
  def self.keys(src); (long_keys(src) + short_keys(src)).uniq; end
end

Suite.define("static: code-referenced i18n keys exist in lang/en.txt") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  en = {}
  PokeAccess::KVFile.each(File.join(root, "lang", "en.txt"), :strip_value => false) { |k, _v| en[k] = true }
  truthy "lang/en.txt loaded", en.length > 100

  # Empty, and it should stay that way. The exemption list is gone entirely, and the reason is that it
  # could never have been doing its job: both scanners match a LITERAL symbol only -- SHORT_RE is
  # /t\(:([a-zA-Z0-9_]+)/ and an interpolated :"chr_#{n}" has a quote where it wants a letter -- so a
  # runtime-built key never reaches this list to be excused in the first place. Every key it did excuse
  # was written out in full in the source, and there were 16 of them (t(:dir_up), t(:puzzle_solved),
  # t(:chr_row)...). All 16 resolve; the exemption was covering nothing and could only ever have hidden a
  # typo that happened to start with the right four letters.
  #
  # w_ and st_ were never here for the same underlying reason, and surf_, aw_c and lang_ were removed
  # earlier as the same mistake.
  dynamic_prefixes = []

  refs = {}
  long_seen = {}
  short_only = {}
  Dir.glob(File.join(root, "{core,games,plugins}", "**", "*.rb")).each do |f|
    base = File.basename(f)
    src = File.read(f)
    I18nRefScan.long_keys(src).each { |k| long_seen[k] = true; refs[k] ||= base }
    I18nRefScan.short_keys(src).each { |k| short_only[k] = true; refs[k] ||= base }
  end
  short_only.delete_if { |k, _v| long_seen[k] }
  # The scanner can be correct and still not be RUN, and the short shape can be quietly redefined into a
  # copy of the explicit one. Counting what the short shape finds that the explicit one CANNOT catches
  # both: either regression takes this to zero and restores the old blind spot.
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
  PokeAccess::SoundGlossary::ENTRIES.each { |e| table_syms.push(e[2]); table_syms.push(e[3]) }
  table_syms.compact.each { |s| refs[s.to_s] ||= "(table)" }
  # Dropping the surf_ exemption only enforces those keys if the table carrying them actually reached the
  # scan; were Terrain moved or LABEL renamed, the family would go unchecked and this spec would stay
  # green -- the same silent coverage loss it exists to prevent.
  truthy "the surf_ family arrives through Terrain::LABEL", refs.keys.select { |k| k.index("surf_") == 0 }.length >= 10

  missing = refs.keys.reject do |k|
    en[k] || dynamic_prefixes.any? { |p| k.index(p) == 0 }
  end
  eq "every referenced key resolves in lang/en.txt", missing.sort.map { |k| "#{k} (#{refs[k]})" }, []
end

# The scanner's contract, pinned on synthetic lines: a scanner that quietly stops matching turns this whole
# spec into a green no-op, and the short shape exists precisely because the previous pattern matched less
# than it looked like it did.
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

# The false positives the short shape must keep out: another object's t( method, an identifier merely
# ending in t, and the prose in i18n.rb's own header. Any of these would put a non-key in the reference
# list and fail the spec for nothing, which is how a guard gets weakened until it is deleted.
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
