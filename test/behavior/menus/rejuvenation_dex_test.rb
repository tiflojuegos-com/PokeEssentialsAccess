# Rejuvenation's Pokedex (games/rejuvenation/pokedex.rb): its list rows, whose fifth field is the base stats and the
# sixth the number, its header with the dex's counts, and the menu of regions it opens with once two dexes are open.

# The dex screen's methods the profile follows, as Rejuvenation's PokedexScene has them; the header windows and the
# region list are the scene's own.
class PokemonPokedexScene
  def pbRefreshMainMenu(index, *_opts); index; end
  def pbStartRegionScene; @activeScene = :region; end
  def pbUpdate(_sprites = nil); nil; end
end

class RejuvenationDexTest < PokeAccessTest
  # The player's Pokedex: Bulbasaur seen in its form 0; Squirtle seen in forms 0 and 1, and caught in form 0.
  class Dex
    SEEN = { :BULBASAUR => [0], :SQUIRTLE => [0, 1] }
    OWNED = { :SQUIRTLE => [0] }
    def seen?(species, form = nil); kept?(SEEN, species, form); end
    def owned?(species, form = nil); kept?(OWNED, species, form); end

    # Whether table holds the species in that form, or in any form for none.
    def kept?(table, species, form)
      forms = table[species]
      forms ? (form.nil? || forms.include?(form)) : false
    end
  end

  # A Pokedex whose list lacks every species but Bulbasaur and Squirtle: asked about another, seen? raises, as
  # Rejuvenation's does on the nil its dexList holds for a species missing from it.
  class GapDex < Dex
    def seen?(species, form = nil)
      raise NoMethodError, "undefined method 'seen?' for nil" unless SEEN.key?(species)
      super
    end
  end

  # The player, holding the Pokedex.
  Player = Struct.new(:pokedex)
  # The list's scene, which says whether the list shows a search's results.
  ListScene = Struct.new(:searchResults)
  # A header window already disposed, which raises when its text is read, as RGSS's do.
  DisposedWin = Class.new { def text; raise IOError, "disposed window"; end }
  # The two dexes of the region menu: name, seen, owned and total, as its window and counters paint them.
  REGIONS = { 0 => { :name => "National Dex", :seen => "30", :owned => "10", :total => 400 },
              1 => { :name => "Floria Dex", :seen => "12", :owned => "5", :total => 150 } }

  class << self
    # The profile's list-row reader, kept aside by load_profile.
    attr_reader :rows
  end

  # Evaluates the profile file once, as boot does. Its list-row reader is kept aside, and the core's reader and the
  # lists of profiles and overrides put back, so the other tests of the process keep the core's; with_profile_rows
  # puts the profile's in for a test.
  def self.load_profile
    overrides = PokeAccess::Hooks.overrides.length
    meta = PokeAccess::Menus.singleton_class
    core = meta.instance_method(:dex_list_row)
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "pokedex.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @rows = meta.instance_method(:dex_list_row)
  ensure
    meta.send(:define_method, :dex_list_row, core)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
  load_profile

  test "a list row says its number, from the sixth field, its name, and caught or seen, as drawItem paints it" do
    want = { :BULBASAUR => "1, Bulbasaur, #{t(:dex_seen)}", :IVYSAUR => "2, #{t(:dex_unknown)}",
             :SQUIRTLE => "7, Squirtle, #{t(:dex_caught)}" }
    rows = [row(:BULBASAUR, "Bulbasaur", 1), row(:IVYSAUR, "Ivysaur", 2), row(:SQUIRTLE, "Squirtle", 7)]
    want.each_with_index do |(species, line), i|
      assert_equal line, focused_row(rows, i, 0, false), species.to_s
    end
  end

  test "in the national dex, a form counts as seen or caught when its species is" do
    want = { :BULBASAUR => "1, Bulbasaur, #{t(:dex_seen)}", :SQUIRTLE => "7, Squirtle, #{t(:dex_caught)}" }
    rows = [row(:BULBASAUR, "Bulbasaur", 1, 1), row(:SQUIRTLE, "Squirtle", 7, 1)]
    want.each_with_index do |(species, line), i|
      assert_equal line, focused_row(rows, i, 0, false), "#{species} in its form 1"
    end
  end

  test "in a regional dex or a search, only the row's own form counts" do
    rows = [row(:BULBASAUR, "Bulbasaur", 1, 1), row(:SQUIRTLE, "Squirtle", 7, 1)]
    { "a regional dex" => [2, false], "a search" => [0, true] }.each do |where, (index, search)|
      assert_equal "1, #{t(:dex_unknown)}", focused_row(rows, 0, index, search), "#{where}: seen only in form 0"
      assert_equal "7, Squirtle, #{t(:dex_seen)}", focused_row(rows, 1, index, search), "#{where}: caught only in form 0"
    end
  end

  test "with no dex index or search flag to read, the list counts as the national dex" do
    rows = [row(:BULBASAUR, "Bulbasaur", 1, 1)]
    { "no dex index" => [nil, false], "no list scene" => [0, nil] }.each do |what, (index, search)|
      assert_equal "1, Bulbasaur, #{t(:dex_seen)}", focused_row(rows, 0, index, search), what
    end
  end

  test "a row of another shape keeps the core's reading, its number fifth" do
    { "with the shift flag" => [:SQUIRTLE, "Squirtle", 5, 90, 7, false],
      "without it" => [:SQUIRTLE, "Squirtle", 5, 90, 7] }.each do |what, gen6|
      assert_equal "7, Squirtle, #{t(:dex_caught)}", focused_row([gen6], 0, 0, false), what
    end
  end

  test "a row of another shape, for a player with no Pokedex to ask, is read by the core as unseen" do
    assert_equal "4, #{t(:dex_unknown)}", focused_row([[:CHARMANDER, "Charmander", 6, 85, 4]], 0, 0, false, nil)
  end

  test "a row the Pokedex cannot answer for goes unread, and the rows it can answer for read as usual" do
    rows = [row(:MEW, "Mew", 151), row(:SQUIRTLE, "Squirtle", 7)]
    { "no Pokedex to ask" => nil, "a Pokedex whose list lacks Mew" => GapDex.new }.each do |what, dex|
      assert_nil focused_row(rows, 0, 0, false, dex), what
    end
    assert_equal "7, Squirtle, #{t(:dex_caught)}", focused_row(rows, 1, 0, false, GapDex.new), "Squirtle, in its list"
  end

  test "the header says the dex's name with its seen and owned counts, queued" do
    dex_scene("<ac>Floria Dex</ac>", "Seen:<r>12", "Owned:<r>5").pbRefreshMainMenu(nil)
    assert_equal [[t(:dex_region_counts, :name => "Floria Dex", :seen => "12", :owned => "5"), false]], SpeakCapture.log
  end

  test "a refresh that paints the same header says nothing" do
    scene = dex_scene("<ac>Floria Dex</ac>", "Seen:<r>12", "Owned:<r>5")
    scene.pbRefreshMainMenu(nil)
    SpeakCapture.clear
    scene.pbRefreshMainMenu(false, :full => false)
    assert_nothing_spoken
  end

  test "a search's results are said when the header changes to them, queued" do
    scene = dex_scene("<ac>Floria Dex</ac>", "Seen:<r>12", "Owned:<r>5")
    scene.pbRefreshMainMenu(nil)
    SpeakCapture.clear
    scene.instance_variable_get(:@pokedexSprites)["dexname"].text = "<ac>Search Results - 3</ac>"
    scene.pbRefreshMainMenu(0)
    assert_equal [[t(:dex_region_counts, :name => "Search Results - 3", :seen => "12", :owned => "5"), false]],
                 SpeakCapture.log
  end

  test "a header missing its name or a count says nothing" do
    { "no name" => ["", "Seen:<r>12", "Owned:<r>5"], "no seen count" => ["<ac>Floria Dex</ac>", "Seen:", "Owned:<r>5"],
      "no owned count" => ["<ac>Floria Dex</ac>", "Seen:<r>12", "Owned:"] }.each do |what, texts|
      dex_scene(*texts).pbRefreshMainMenu(nil)
      assert_nothing_spoken what
    end
    scene = PokemonPokedexScene.new
    scene.pbRefreshMainMenu(nil)
    assert_nothing_spoken "no header windows"
  end

  test "a header whose name window is already disposed says nothing" do
    scene = dex_scene("<ac>Floria Dex</ac>", "Seen:<r>12", "Owned:<r>5")
    scene.instance_variable_get(:@pokedexSprites)["dexname"] = DisposedWin.new
    scene.pbRefreshMainMenu(nil)
    assert_nothing_spoken
  end

  test "the region menu says the region it opens on with its counts, queued" do
    region_scene(1).pbStartRegionScene
    assert_equal [[floria, false]], SpeakCapture.log
  end

  test "a turn of the region menu cuts in with the next region" do
    scene = region_scene(1)
    scene.pbStartRegionScene
    SpeakCapture.clear
    scene.instance_variable_set(:@regionMenuIndex, 0)
    scene.pbUpdate
    national = t(:dex_region_counts_tot, :name => "National Dex", :seen => "30", :owned => "10", :tot => 400)
    assert_equal [[national, true]], SpeakCapture.log
  end

  test "the region is not said again while it stays" do
    scene = region_scene(1)
    scene.pbStartRegionScene
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "once the list is up, the region menu is not read" do
    scene = region_scene(1)
    scene.instance_variable_set(:@activeScene, :pokedex)
    scene.instance_variable_set(:@regionMenuIndex, 0)
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "back on the region menu, its region is said again, queued" do
    scene = region_scene(1)
    scene.pbStartRegionScene
    scene.instance_variable_set(:@activeScene, :pokedex)
    SpeakCapture.clear
    scene.pbStartRegionScene
    assert_equal [[floria, false]], SpeakCapture.log
  end

  test "a region index with no region says nothing" do
    region_scene(5).pbStartRegionScene
    assert_nothing_spoken
  end

  test "a region menu with no list of dexes yet says nothing" do
    scene = region_scene(1)
    scene.instance_variable_set(:@list, nil)
    scene.pbStartRegionScene
    assert_nothing_spoken
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Floria's line in the region menu.
  def floria
    t(:dex_region_counts_tot, :name => "Floria Dex", :seen => "12", :owned => "5", :tot => 150)
  end

  # A list row as Rejuvenation builds it: species, name, height, weight, base stats, number, gender, form.
  def row(species, name, number, form = 0)
    [species, name, 7, 69, [45, 49, 49, 65, 65, 45], number, nil, form]
  end

  # What the list says with its cursor on row i, in the dex at index (0 the national one, nil none to read), with its
  # scene showing a search's results or not (nil for no scene), for a player holding dex (nil for none).
  def focused_row(rows, i, index, search, dex = Dex.new)
    win = Window_Pokedex.new(rows)
    win.instance_variable_set(:@scene, ListScene.new(search)) unless search.nil?
    win.index = i
    with_profile_rows { with_player(index, dex) { PokeAccess::Menus.focused_text(win) } }
  end

  # A dex scene whose header windows paint the dex's name and its seen and owned counts.
  def dex_scene(name, seen, owned)
    scene = PokemonPokedexScene.new
    scene.instance_variable_set(:@pokedexSprites, { "dexname" => FakeTextWin.new(name), "seen" => FakeTextWin.new(seen),
                                                    "owned" => FakeTextWin.new(owned) })
    scene
  end

  # A dex scene over the region menu's two dexes, its cursor on index, its list not up yet.
  def region_scene(index)
    scene = PokemonPokedexScene.new
    scene.instance_variable_set(:@list, REGIONS)
    scene.instance_variable_set(:@regionMenuIndex, index)
    scene
  end

  # Runs the block with the profile's list-row reader in place of the one there, put back after.
  def with_profile_rows
    meta = PokeAccess::Menus.singleton_class
    was = meta.instance_method(:dex_list_row)
    meta.send(:define_method, :dex_list_row, self.class.rows)
    yield
  ensure
    meta.send(:define_method, :dex_list_row, was)
  end

  # Runs the block with the player holding dex and the dex the list is on (nil: no index to read), put back after.
  def with_player(index, dex)
    had = $Trainer
    $Trainer = Player.new(dex)
    $PokemonGlobal.define_singleton_method(:pokedexIndex) { index } unless index.nil?
    yield
  ensure
    $Trainer = had
    meta = $PokemonGlobal.singleton_class
    meta.send(:remove_method, :pokedexIndex) if meta.method_defined?(:pokedexIndex, false)
  end
end
