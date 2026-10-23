# A reader that breaks keeps the screen going and leaves one marker line: a raising extractor falls back to the
# window's own list, a raising scene-watcher block skips its frames, an unregistered capability answers false (what the
# game simply lacks is no failure) and an unloadable MapInfos is given up on once; and a menu's help leaves with it.
class FailurePathsTest < PokeAccessTest
  # A command window whose extractor raises, with its option list and cursor.
  class BrokenWindow
    attr_accessor :index
    def initialize(commands); @commands = commands; @index = 0; end
  end

  test "a raising extractor falls back to the window's own list and is named in the marker once" do
    saved = PokeAccess::Menus::EXTRACTORS.dup
    PokeAccess::Menus.def_extractor("#{self.class}::BrokenWindow") { |_w, _i| raise "este extractor revienta" }
    win = BrokenWindow.new(["Curar", "Luchar"])
    win.index = 1
    said = []
    lines = marker_lines { 2.times { said.push(PokeAccess::Menus.focused_text(win)) } }
    assert_equal ["Luchar", "Luchar"], said, "each read still answers, from the window's own list"
    assert_equal ["extractor #{self.class}::BrokenWindow: RuntimeError: este extractor revienta"], lines
  ensure
    PokeAccess::Menus::EXTRACTORS.replace(saved)
  end

  test "a scene-watcher block that raises says nothing, keeps polling and is logged once" do
    boom = PokeAccess::SceneWatcher.reader("FailurePathsNoSuchScreen", :main, :failure_paths_boom) do |_s|
      raise "bloque roto"
    end
    boom.watch(Object.new)
    lines = marker_lines { 2.times { boom.poll } }
    assert_nothing_spoken
    assert_equal 1, lines.length, lines.inspect
    assert_match(/\Ascene_watcher_failure_paths_boom: RuntimeError: bloque roto @ /, lines[0])
  ensure
    boom.unwatch if boom
  end

  test "an unregistered capability answers false and is logged once" do
    said = []
    lines = marker_lines { 2.times { said.push(PokeAccess::Engine.has?(:failure_paths_no_such_cap)) } }
    assert_equal [false, false], said
    assert_equal ["cap_failure_paths_no_such_cap: capacidad no registrada"], lines
  end

  test "a probe answers whether the game has the class, the method or the engine, and logs no absence" do
    { "Window_DrawableCommand" => true, "Window_DrawableCommand#update" => true,
      "Window_DrawableCommand#initialize" => true, "Window_DrawableCommand#" => true, "PokeAccess::Menus" => true,
      "Window_DrawableCommand#failure_paths_absent" => false, "PokeAccess::DIR_DELTA#keys" => false,
      "FailurePathsAbsentClass" => false, "FailurePathsAbsentClass#update" => false,
      :gen6 => true, :gamedata => false }.each do |probe, has|
      said = nil
      lines = marker_lines { said = PokeAccess::Engine.has?(probe) }
      assert_equal has, said, probe.inspect
      assert_equal [], lines, probe.inspect
    end
  end

  test "an unloadable MapInfos is tried once, its maps left unnamed, and logged once" do
    loc = PokeAccess::Locator
    saved = loc.instance_variable_get(:@mapinfos)
    loc.instance_variable_set(:@mapinfos, nil)
    tries = 0
    names = []
    lines = with_failing_rxdata(lambda { tries += 1 }) do
      with_fresh_log("mapinfos") { marker_lines { 6.times { names.push(loc.map_name(9035)) } } }
    end
    assert_equal [nil] * 6, names, "no name is made up for a map"
    assert_equal 1, tries, "the file is tried once, not once per name"
    assert_equal ["mapinfos: Data/MapInfos no cargable"], lines
  ensure
    loc.instance_variable_set(:@mapinfos, saved)
  end

  test "a menu's help line stays in the info key until the last menu closes" do
    ch = PokeAccess::CommandHelp
    ch.enter(:plain)
    ch.note(Object.new, :plain, "Sube o baja el volumen.")
    ch.enter(:plain)
    ch.leave
    assert_equal "Sube o baja el volumen.", PokeAccess::Info.info_text, "a menu opened over it closing leaves it"
    ch.leave
    assert_nil PokeAccess::Info.info_text, "the last menu closing takes it"
  ensure
    ch.leave while ch.current
  end

  test "a help held for its menu's first frames is dropped when the menu closes before saying it" do
    ch = PokeAccess::CommandHelp
    ch.enter(:plain)
    ch.note(Object.new, :plain, "Sube o baja el volumen.")
    assert_nothing_spoken "held while the menu opens"
    ch.leave
    2.times { ch.release }
    assert_nothing_spoken
  ensure
    ch.leave while ch.current
  end

  test "a menu closing leaves the info key on what it points at other than its help" do
    ch = PokeAccess::CommandHelp
    ch.enter(:plain)
    PokeAccess::Info.set_info(:pokemon, Poke.build(:name => "Chispa"))
    held = PokeAccess::Info.info_text
    ch.leave
    refute_nil held
    assert_equal held, PokeAccess::Info.info_text
  ensure
    ch.leave while ch.current
  end

  private

  # The marker lines written while the block runs, without their time stamp.
  def marker_lines
    path = PokeAccess.marker_file
    from = File.file?(path) ? File.size(path) : 0
    yield
    return [] unless File.file?(path)
    File.open(path, "rb") { |f| f.seek(from); f.read }.to_s.split(/\r?\n/).map { |l| l.sub(/\A.*?[+-]\d{4}: /, "") }
  end

  # The block's value with the game's pbLoadRxData raising after calling on_try, the game's own put back after.
  def with_failing_rxdata(on_try)
    Object.send(:alias_method, :failure_paths_load, :pbLoadRxData)
    Object.send(:define_method, :pbLoadRxData) do |_path|
      on_try.call
      raise "no se puede cargar"
    end
    yield
  ensure
    Object.send(:alias_method, :pbLoadRxData, :failure_paths_load)
    Object.send(:remove_method, :failure_paths_load)
  end

  # The block's value with key unlogged, so its first failure is written afresh; what was logged before is put back.
  def with_fresh_log(key)
    logged = PokeAccess.instance_variable_get(:@logged_once)
    logged = PokeAccess.instance_variable_set(:@logged_once, {}) if logged.nil?
    had = logged.key?(key)
    was = logged.delete(key)
    yield
  ensure
    if had
      logged[key] = was
    else
      logged.delete(key)
    end
  end
end
