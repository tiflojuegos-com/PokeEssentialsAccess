# Settings.apply on a scratch settings.ini: each line applied as its setting's kind reads it, bind_ and key_ lines
# remapping the controls, the ini rewritten only when it differs from the settings, and the failures it logs.
class SettingsApplyTest < PokeAccessTest
  DEFAULT_KEYS = PokeAccess::Config::KEY_DEFAULTS

  test "applies each line to the setting it names, as that setting's kind reads it" do
    { "auto_guide=true" => [:auto_guide, true], "read_help=false" => [:read_help, false],
      "language=en" => [:language, :en], "sound_nav=basic" => [:sound_nav, :basic],
      "route_limit=time" => [:route_limit, :time], "audio3d_volume=40" => [:audio3d_volume, 40],
      "audio3d_volume=250" => [:audio3d_volume, 100], "audio3d_volume=-5" => [:audio3d_volume, 0],
      " guide_distance = 5 " => [:guide_distance, 5] }.each do |line, (key, want)|
      apply_ini(line)
      assert_equal want, PokeAccess::Config.send(key), "for #{line.inspect}"
    end
  end

  test "drops a value its setting's kind does not take, and the setting keeps what it held" do
    { "guide_distance=abc" => [:guide_distance, 5], "dialogue_pages=yes" => [:dialogue_pages, true],
      "path_algorithm=bogus" => [:path_algorithm, :astar], "hide_unreachable=true" => [:hide_unreachable, :room],
      "language=" => [:language, :en] }.each do |line, (key, held)|
      PokeAccess::Config.send("#{key}=", held)
      apply_ini(line)
      assert_equal held, PokeAccess::Config.send(key), "for #{line.inspect}"
    end
  end

  test "leaves a setting the ini does not name as it stood" do
    PokeAccess::Config.auto_guide = true
    apply_ini("language=en")
    assert_equal true, PokeAccess::Config.auto_guide
  end

  test "takes each bind_ line with a positive code as a button's key" do
    apply_ini("bind_saltar=65", "bind_a=1")
    assert_equal({ :saltar => 65, :a => 1 }, PokeAccess::Config.rebinds)
  end

  test "ignores a bind_ or key_ line whose code is not a positive number" do
    apply_ini("bind_a=0", "bind_b=abc", "bind_c=-3", "key_next=0", "key_prev=abc", "key_where=-1")
    assert_equal [{}, DEFAULT_KEYS], [PokeAccess::Config.rebinds, PokeAccess::Config.keys]
  end

  test "ignores a bind_ or key_ line on a key the engine answers, as F1, F2 and F12, or a fixed gesture holds" do
    apply_ini("bind_a=112", "bind_b=123", "bind_c=13", "bind_x=113", "key_next=112", "key_prev=123", "key_where=120",
              "key_info=113")
    assert_equal [{}, DEFAULT_KEYS], [PokeAccess::Config.rebinds, PokeAccess::Config.keys]
  end

  test "takes a key with Alt on a bind_ or key_ line, and no reserved key with Alt" do
    kb = PokeAccess::Keyboard
    apply_ini("bind_saltar=#{kb.with_alt(65)}", "key_next=#{kb.with_alt(88)}", "bind_a=#{kb.with_alt(0x70)}") do |ini|
      assert_includes File.read(ini), "bind_saltar=#{kb.with_alt(65)}\n"
      assert_includes File.read(ini), "key_next=#{kb.with_alt(88)}\n"
    end
    assert_equal({ :saltar => kb.with_alt(65) }, PokeAccess::Config.rebinds)
    assert_equal kb.with_alt(88), PokeAccess::Config.keys[:next]
  end

  test "drops a key with Alt on the mod's modifiers, and a code with no key" do
    kb = PokeAccess::Keyboard
    apply_ini("key_shift=#{kb.with_alt(16)}", "bind_c=#{kb::ALT_HELD}")
    assert_equal DEFAULT_KEYS[:shift], PokeAccess::Config.keys[:shift]
    assert_nil (PokeAccess::Config.rebinds || {})[:c]
  end

  test "a game action shipped on a key a saved binding uses goes back to the game's keys, while that binding lasts" do
    kb = PokeAccess::Keyboard
    begin
      PokeAccess::Remap.ship(:z => "Alt+T", :y => "Alt+Y")
      apply_ini("bind_x=#{kb.with_alt(0x54)}")
      assert_equal [nil, kb.with_alt(0x59)], [PokeAccess::Remap.shipped(:z), PokeAccess::Remap.shipped(:y)]
      PokeAccess::Config.rebinds = {}
      assert_equal kb.with_alt(0x54), PokeAccess::Remap.shipped(:z)
    ensure
      PokeAccess::Remap.defaults.clear
    end
  end

  test "an action saved on the key it ships on keeps what it ships" do
    kb = PokeAccess::Keyboard
    begin
      PokeAccess::Remap.ship(:z => "Alt+T")
      apply_ini("bind_z=#{kb.with_alt(0x54)}")
      assert_equal kb.with_alt(0x54), PokeAccess::Remap.shipped(:z)
    ensure
      PokeAccess::Remap.defaults.clear
    end
  end

  test "writes no hotkey on what the profile ships it on, and one moved off it" do
    shipped = PokeAccess::Config.key_defaults.dup
    keys = PokeAccess::Config.keys.dup
    begin
      PokeAccess::Remap.ship(:hp => "V")
      apply_ini do |ini|
        refute_includes File.read(ini), "key_hp="
      end
      apply_ini("key_hp=88") do |ini|
        assert_includes File.read(ini), "key_hp=88\n"
      end
    ensure
      PokeAccess::Config.key_defaults = shipped
      PokeAccess::Config.keys = keys
    end
  end

  test "moves the mod hotkey a key_ line names, and ignores an action the mod has no key for" do
    apply_ini("key_next=88", "key_prev=1", "key_bogus=99")
    assert_equal DEFAULT_KEYS.merge(:next => 88, :prev => 1), PokeAccess::Config.keys
  end

  test "unbinds a default hotkey whose key a saved binding uses, and the binding keeps it" do
    apply_ini("bind_l=36")
    assert_equal DEFAULT_KEYS.merge(:hist_prev => nil), PokeAccess::Config.keys, "Home was the L button's"
    assert_equal({ :l => 36 }, PokeAccess::Config.rebinds, "and the L button still has it")
  end

  test "unbinds a default hotkey whose key another mod key moved onto" do
    apply_ini("key_hp=35")
    assert_equal DEFAULT_KEYS.merge(:hp => 35, :hist_next => nil), PokeAccess::Config.keys, "End was the HP key's"
  end

  test "keeps a hotkey the player moved, even onto a key a binding also uses" do
    apply_ini("bind_l=65", "key_hp=65")
    assert_equal DEFAULT_KEYS.merge(:hp => 65), PokeAccess::Config.keys
  end

  test "rewrites the ini as its header, every setting in order, then the binds and only the hotkeys moved" do
    apply_ini("audio3d_volume=250", "obsolete_setting=1", "bind_saltar=65", "key_next=88") do |ini|
      shape = File.read(ini).split("\n").map { |l| l.start_with?("#") ? "#" : l.split("=", 2)[0] }
      settings = PokeAccess::Config.settings.map { |s| s.key.to_s }
      assert_equal ["#", "#"] + settings + ["#", "bind_saltar", "key_next"], shape
    end
  end

  test "writes back each value as the setting now holds it" do
    apply_ini("audio3d_volume=250", "bind_saltar=65", "key_next=88") do |ini|
      written = File.read(ini)
      assert_equal ["audio3d_volume=100", "bind_saltar=65", "key_next=88"],
                   written.split("\n").grep(/\A(audio3d_volume|bind_saltar|key_next)=/)
      assert_equal PokeAccess::Settings.render, written, "the whole file is the settings as they stand"
    end
  end

  test "reads back an ini it wrote to the same settings, binds and hotkeys" do
    config = PokeAccess::Config
    wanted = {}
    config.settings.each { |s| wanted[s.key] = config.send("#{s.key}=", config.next_value(s, 1)) }
    config.rebinds = { :saltar => 65, :l => 76 }
    config.keys[:next] = 88
    with_ini do
      PokeAccess::Settings.write
      Reset.reset_config
      PokeAccess::Settings.apply
    end
    held = {}
    wanted.each_key { |k| held[k] = config.send(k) }
    assert_equal [wanted, { :saltar => 65, :l => 76 }, 88], [held, config.rebinds, config.keys[:next]]
  end

  test "does not rewrite an ini that already says what the settings hold" do
    with_ini do
      PokeAccess::Settings.apply
      assert_equal 0, counting_writes { PokeAccess::Settings.apply }
    end
  end

  test "creates the ini when there is none, with the settings as they stand" do
    with_ini do |ini|
      PokeAccess::Settings.apply
      assert_equal PokeAccess::Settings.render, File.read(ini)
    end
  end

  test "logs an ini it cannot write, and carries on" do
    forgetting_logged("settings_write") do
      with_ini(nil, "missing/settings.ini") { PokeAccess::Settings.apply }
      assert_match(/\AErrno::ENOENT: /, PokeAccess.logged["settings_write"])
    end
  end

  test "applies nothing from an ini it cannot read, and logs why" do
    PokeAccess::Config.auto_guide = true
    forgetting_logged("settings_read") do
      failing(PokeAccess::KVFile, :each) { apply_ini("auto_guide=false") }
      assert_equal true, PokeAccess::Config.auto_guide, "the setting keeps what it held"
      assert_match(/\ARuntimeError: each failed/, PokeAccess.logged["settings_read"])
    end
  end

  test "notes a failure while it applies the ini in the marker file, and returns" do
    note = marked { failing(PokeAccess::Config, :auto_guide=) { apply_ini("auto_guide=true") } }
    assert_match(/: settings apply: auto_guide= failed\n\z/, note)
  end

  private

  # Runs the block with Settings reading and writing a settings.ini of its own (holding text, or none for nil) at rel
  # in a scratch folder, yielding its path; FILE is put back afterwards.
  def with_ini(text = nil, rel = "settings.ini")
    Dir.mktmpdir do |dir|
      ini = File.join(dir, rel)
      File.open(ini, "w") { |f| f.write(text) } if text
      was = PokeAccess::Settings::FILE
      PokeAccess::Settings.send(:remove_const, :FILE)
      PokeAccess::Settings.const_set(:FILE, ini)
      begin
        yield ini
      ensure
        PokeAccess::Settings.send(:remove_const, :FILE)
        PokeAccess::Settings.const_set(:FILE, was)
      end
    end
  end

  # Applies an ini of the given lines, then runs the block with its path while it still exists.
  def apply_ini(*lines)
    with_ini(lines.map { |l| "#{l}\n" }.join) do |ini|
      PokeAccess::Settings.apply
      yield ini if block_given?
    end
  end

  # Runs the block with the mod's once-only log open again for key, its record put back as it was afterwards.
  def forgetting_logged(key)
    memo = PokeAccess.instance_variable_get(:@logged_once) || PokeAccess.instance_variable_set(:@logged_once, {})
    had = memo.key?(key)
    was = memo.delete(key)
    yield
  ensure
    had ? memo[key] = was : memo.delete(key)
  end

  # Runs the block with mod's singleton method meth raising "<meth> failed", put back afterwards.
  def failing(mod, meth)
    real = mod.method(meth)
    mod.define_singleton_method(meth) { |*_args, &_blk| raise "#{meth} failed" }
    yield
  ensure
    mod.define_singleton_method(meth, real)
  end

  # What the block appended to the mod's marker file.
  def marked
    size = File.file?(PokeAccess.marker_file) ? File.size(PokeAccess.marker_file) : 0
    yield
    File.file?(PokeAccess.marker_file) ? File.binread(PokeAccess.marker_file)[size..-1].to_s.gsub("\r\n", "\n") : ""
  end

  # How many times the block wrote the ini.
  def counting_writes
    settings = PokeAccess::Settings
    real = settings.method(:write)
    writes = 0
    settings.define_singleton_method(:write) { writes += 1; real.call }
    yield
    writes
  ensure
    settings.define_singleton_method(:write, real)
  end
end
