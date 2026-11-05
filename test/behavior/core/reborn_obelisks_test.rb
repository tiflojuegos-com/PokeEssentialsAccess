# Reborn's White Shard obelisks: named for what they do, and with the puzzle assist a map whose obelisk waits for a password says
# so on arriving, by the password its first page checks. The profile is evaluated through the harness.
class RebornObelisksTest < PokeAccessTest
  def self.loaded
    @loaded ||= begin
      path = File.join(Harness::ROOT, "games", "reborn", "skip_obelisks.rb")
      eval(File.read(path, :encoding => "UTF-8"), TOPLEVEL_BINDING, path)
      true
    end
  end

  def setup
    super
    self.class.loaded
    @was = PokeAccess::Config.puzzle_assist
  end

  def teardown
    PokeAccess::Config.puzzle_assist = @was
    [2226, 2227, 99].each { |s| $game_switches[s] = false }
    World.clear_events
    super
  end

  test "an obelisk is named for what it does; other events and other shards are not" do
    assert_equal t(:reb_obelisk), mod.name_of(event("White Shard", :sprite => "obelisk2"))
    assert_nil mod.name_of(event("White Shard", :sprite => "")), "not drawn yet"
    assert_nil mod.name_of(event("Light Shard", :sprite => "obelisk")), "another kind of shard"
  end

  test "with the assist, says on arriving which password shows the obelisk of the map" do
    on(true) do
      obelisk(10, [2226, 2227])
      assert_equal [t(:reb_obelisk_hint)], arriving
    end
    on(true) do
      obelisk(10, [2226])
      assert_equal [t(:reb_obelisk_hint_blindstep)], arriving
    end
  end

  test "says nothing without the assist, with the password on, or with no obelisk on the map" do
    on(false) do
      obelisk(10, [2226, 2227])
      assert_equal [], arriving
    end
    on(true) do
      obelisk(10, [2226, 2227])
      $game_switches[2227] = true
      assert_equal [], arriving
    end
    on(true) { assert_equal [], arriving }
  end

  test "says nothing once its puzzle is done, a later page standing" do
    on(true) do
      obelisk(10, [2226, 2227], :switch1_valid => true, :switch1_id => 99)
      $game_switches[99] = true
      assert_equal [], arriving
    end
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mod; PokeAccess::RebornObelisks; end

  def on(assist)
    PokeAccess::Config.puzzle_assist = assist
    World.clear_events
    yield
  end

  def arriving
    SpeakCapture.clear
    mod.arrival
    SpeakCapture.lines
  end

  def event(name, opts = {})
    TestGameEvent.new(:id => 9, :name => name, :pages => [TestPage.new(:trigger => 1, :sprite => opts.fetch(:sprite, ""))])
  end

  # An obelisk as the maps build it: a first page that checks the switches, one drawn behind its self switch, and a last one
  # standing once its puzzle is done, behind the condition given.
  def obelisk(id, switches, done = { :switch1_valid => true, :switch1_id => 99 })
    list = switches.map { |s| TestCmd.new(111, [0, s, 0]) } + [TestCmd.new(116, []), TestCmd.new(0, [])]
    pages = [TestPage.new(:trigger => 3, :sprite => "", :list => list),
             TestPage.new(:trigger => 1, :sprite => "obelisk2", :condition => { :self_switch_valid => true, :self_switch_ch => "A" }),
             TestPage.new(:trigger => 0, :sprite => "", :condition => done)]
    $game_map.events[id] = TestGameEvent.new(:id => id, :name => "White Shard", :pages => pages)
  end
end
