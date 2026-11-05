# What each profile ships its keys on, read from its source and its imports': a name a key can have, an action of the
# remap screen, no key no entry can take, none with Alt for the mod's modifiers, and no two actions on one key.
require File.expand_path(File.join(File.dirname(__FILE__), "imports"))

class KeyDefaultsTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  Remap = PokeAccess::Remap
  Keyboard = PokeAccess::Keyboard
  DECLARED = /\b(?:field_)?key_defaults[ (]\s*((?::\w+\s*=>\s*(?:"[^"]*"|nil)(?:,\s*)?)+)/
  ROW = /\bremap_extra\(:(\w+)/
  NAME = /\A(?:None|Alt|Tab|(?:Alt\+)?(?:[A-Z0-9]|F\d{1,2}))\z/
  # What each game ships: the mod keeps its letters, and a game's action on one of them moves to Alt plus it, to Alt when
  # it is on the mod's Shift, and to no key, or only that key, when the game has it on another too.
  SHIPPED = {
    "ashenfrost" => { :ashen_move_info => "Alt+M", :ashen_skip => "F7", :l => "Q" },
    "awakening" => { :awk_map => "Alt+M", :awk_lens => "Alt+J", :awk_info => "Alt+G", :z => "Alt+T" },
    "decades" => { :decades_type_chart => "Alt+T", :decades_ctrl => "Tab" },
    "desolation" => { :des_speed_m => "None" },
    "insurgence" => { :ins_speed => "Alt+M", :ins_item4 => "Alt+T" },
    "opalo" => { :op_anthem_t => "Alt+T", :op_anthem_i => "Alt+I" },
    "perseida" => { :clara_map => "Alt+M", :clara_cometry => "Alt+T" },
    "realidea" => { :rea_m => "Alt+M" },
    "reminiscencia" => { :fast_travel => "Alt+T" },
    "sevii" => { :sv_speed => "Alt" },
    "soulstones1" => { :ss1_mark => "Alt" },
    "uranium" => { :ura_close_list => "None" },
    "vitro" => { :vitro_save => "Alt+T", :vitro_quests => "Alt+J", :vitro_map => "Alt+M" }
  }
  # The names the READMEs' tables give those games.
  README_NAMES = {
    "ashenfrost" => "Ashen Frost", "awakening" => "Awakening", "decades" => "Decades", "desolation" => "Desolation", "insurgence" => "Insurgence", "opalo" => "Ópalo",
    "perseida" => "Perseida", "realidea" => "Realidea", "reminiscencia" => "Reminiscencia", "sevii" => "Sevii",
    "soulstones1" => "Soulstones", "uranium" => "Uranium", "vitro" => "GS Vitro"
  }

  test "no profile ships a key it should not" do
    declaring = profiles.reject { |_name, source| source !~ DECLARED }
    assert_operator declaring.length, :>=, 2, "the scan read the profiles that ship keys"
    assert_equal [], declaring.map { |name, source| problems(name, source) }.flatten
  end

  test "the READMEs' tables give each game the keys it ships, and no others" do
    { "README.es.md" => "Ninguna", "README.en.md" => "None" }.each do |file, none|
      text = File.read(File.join(ROOT, file), :encoding => "UTF-8")
      SHIPPED.each do |game, map|
        name = README_NAMES[game]
        have = text.scan(/^\| #{Regexp.escape(name)} \| ([^|]+?) \|/).flatten.map { |cell| cell.sub(/,.*\z/, "") }
        want = map.values.map { |spec| spec == "None" ? none : spec.split("+").map { |part| "`#{part}`" }.join(" + ") }
        assert_equal want.sort, have.sort, "#{name} in #{file}"
      end
    end
  end

  test "each game ships the keys listed here, and no other game ships any" do
    shipped = {}
    profiles.each do |name, source|
      map = {}
      source.scan(DECLARED) { |found| found[0].scan(/:(\w+)\s*=>\s*"([^"]*)"/) { |sym, spec| map[sym.to_sym] = spec } }
      shipped[name] = map unless map.empty?
    end
    assert_equal SHIPPED, shipped
  end

  test "reports a bad name, an action off the remap screen, a reserved key, a modifier with Alt and two on one key" do
    source = <<-RUBY
      remap_extra(:row, :M, :label)
      key_defaults(:row => "alt+m", :nowhere => "N")
      field_key_defaults(:c => "Alt+F1")
      key_defaults :shift => "Alt+K", :x => "Alt+Q", :y => "Alt+Q"
      key_defaults(:z => "T")
    RUBY
    assert_equal ["p: bad name alt+m for row", "p: nowhere is no action of the remap screen", "p: c on a reserved key",
                  "p: shift takes no key with Alt", "p: info, z on one key", "p: x, y on one key"],
                 problems("p", source)
  end

  test "a mod key moved leaves its letter free, and a profile that ships nothing has nothing to report" do
    assert_equal [], problems("p", %(key_defaults(:info => "N", :z => "T")\n))
    assert_equal [], problems("p", "remap_extra(:row, :M, :label)\n")
  end

  test "any number of actions on no key is fine, and Alt alone is a key like another" do
    source = %(remap_extra(:one, :M, :l)\nremap_extra(:two, :O, :l)\nkey_defaults(:one => "None", :two => "None"))
    assert_equal [], problems("p", source)
    source = %(remap_extra(:one, :M, :l)\nremap_extra(:two, :O, :l)\nkey_defaults(:one => "Alt", :two => "Alt"))
    assert_equal ["p: one, two on one key"], problems("p", source)
  end

  # Each profile with its source: its own files' and its imports'.
  def profiles
    Dir.glob(File.join(ROOT, "games", "*", "manifest.rb")).sort.map do |manifest|
      dir = File.dirname(manifest)
      imports = eval(File.read(manifest))[:imports] || []
      dirs = [dir] + imports.map { |name| File.join(ROOT, "games", name) }
      [File.basename(dir), dirs.map { |d| Dir.glob(File.join(d, "**", "*.rb")).sort.map { |f| File.read(f) } }.join("\n")]
    end
  end

  # What is wrong with what a profile's source ships, as lines naming it.
  def problems(name, source)
    shipped = []
    source.scan(DECLARED) { |map| map[0].scan(/:(\w+)\s*=>\s*("[^"]*"|nil)/) { |sym, spec| shipped.push([sym.to_sym, spec.delete('"')]) } }
    rows = source.scan(ROW).flatten.map { |sym| sym.to_sym }
    bad = shipped.map { |sym, spec| problem(sym, spec, rows) }.compact
    bad.map { |line| "#{name}: #{line}" } + clashes(shipped).map { |line| "#{name}: #{line}" }
  end

  # What is wrong with one action shipped on one key, or nil.
  def problem(sym, spec, rows)
    return nil if spec == "nil" && Remap.mod_action?(sym)
    return "bad name #{spec} for #{sym}" unless spec =~ NAME
    code = Keyboard.code_for(spec)
    return "#{sym} is no action of the remap screen" unless Remap.mod_action?(sym) || rows.include?(sym) || Remap::BUTTONS.assoc(sym)
    return "#{sym} on a reserved key" if Remap::RESERVED.key?(Keyboard.key_of(code))
    return "#{sym} takes no key with Alt" if Remap::PLAIN_KEYS.include?(sym) && Keyboard.alt_code?(code)
    nil
  end

  # The keys two actions end on: the mod's keys where the profile leaves or moves them, and each game action shipped.
  def clashes(shipped)
    named = shipped.select { |_sym, spec| spec =~ NAME }
    keys = PokeAccess::Config::KEY_DEFAULTS.dup
    named.each { |sym, spec| keys[sym] = Keyboard.code_for(spec) if Remap.mod_action?(sym) }
    named.reject { |sym, _spec| Remap.mod_action?(sym) }.each { |sym, spec| keys[sym] = Keyboard.code_for(spec) }
    keys.reject { |_sym, code| code.nil? || code == Keyboard::NO_KEY }.group_by { |_sym, code| code }.values.select { |all| all.length > 1 }.map do |all|
      "#{all.map { |sym, _code| sym.to_s }.sort.join(', ')} on one key"
    end
  end
end
