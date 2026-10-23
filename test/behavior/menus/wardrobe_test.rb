# DarrylBD99's Wardrobe: a row is the outfit's name, "worn" for the one the player has on (the scene's @outfit_current,
# an index into its @outfit_all) and "chosen" for the one the check marks; the focused row is said once per change,
# polled while the wardrobe's main loop runs.

# The outfit list window as the wardrobe keeps it: the rows, the check (@outfit_selected) and the cursor.
class WardrobeSpecList
  attr_accessor :index
  def initialize(outfits, checked, index); @outfits = outfits; @outfit_selected = checked; @index = index; end
end

# A full list that answers as an Array but cannot look an outfit up.
class WardrobeSpecBrokenList < Array
  def index(*_a); raise "unreadable"; end
end

# The wardrobe's scene: its main loop runs the block it was built with, the frames while the wardrobe is up.
class WardrobeSpecScene
  def initialize(&during); @during = during; end
  def pbMain; @during.call(self); end
end

class WardrobeTest < PokeAccessTest
  ROWS = ["Normal", "Classic", "Magma"]
  ALL = ["Normal", "Magma", "Classic"]
  PLUGIN = File.join(Harness::ROOT, "plugins", "wardrobe.rb")

  # Loads the plugin again with these classes standing in under the game's names ({name => class}), so its hooks bind
  # to them, and answers the hooks that load reported missing; the names and the frame's pollers are put back.
  # param file the name the source is evaluated under; a name of its own keeps the load out of the plugin's coverage
  def self.load_plugin_with(stand_ins, file = PLUGIN)
    verbose = $VERBOSE
    before = PokeAccess::Hooks.missing.dup
    saved = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    stand_ins.each { |n, k| Object.const_set(n, k) }
    pollers = PokeAccess::Frame.instance_variable_get(:@pollers).dup
    $VERBOSE = nil
    eval(Harness.source(PLUGIN), TOPLEVEL_BINDING, file)
    PokeAccess::Hooks.missing - before
  ensure
    $VERBOSE = verbose
    PokeAccess::Frame.instance_variable_set(:@pollers, pollers) if pollers
    stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (saved || []).each { |n, k| Object.const_set(n, k) if k }
  end
  private_class_method :load_plugin_with

  # Both loads run as this file loads, before any test: a class binds once, and the stand-ins' load comes last, as
  # the one the tests drive and coverage counts.
  MISSING_WITHOUT_MAIN_LOOP = load_plugin_with({ :WardrobeScene => Class.new }, "bare:#{PLUGIN}")
  load_plugin_with(:Window_Wardrobe => WardrobeSpecList, :WardrobeScene => WardrobeSpecScene)

  test "the outfit the player has on reads as worn, the check sitting on it" do
    assert_equal ["Normal, #{worn}", "Classic", "Magma"], rows(:checked => 0, :current => 0)
  end

  test "the outfit the check moved to reads as chosen, the one on still as worn" do
    assert_equal ["Normal, #{worn}", "Classic, #{chosen}", "Magma"], rows(:checked => 1, :current => 0)
  end

  test "worn follows the outfit's place in the full list, not its row" do
    assert_equal ["Normal", "Classic", "Magma, #{worn}"], rows(:checked => 2, :current => 1)
  end

  test "with no scene to ask, the checked outfit reads as worn" do
    win = WardrobeSpecList.new(ROWS, 1, 0)
    assert_equal ["Normal", "Classic, #{worn}", "Magma"], ROWS.each_index.map { |i| PokeAccess::Wardrobe.text(win, i) }
  end

  test "an outfit reads as worn only when the scene can tell which one is on" do
    { "no outfit on" => [ALL, nil], "no full list" => [nil, 0],
      "a full list that cannot look it up" => [WardrobeSpecBrokenList.new(ALL), 0] }.each do |what, (all, current)|
      win = WardrobeSpecList.new(ROWS, 1, 0)
      scene = World.stub_scene(:@outfit_all => all, :@outfit_current => current)
      got = ROWS.each_index.map { |i| PokeAccess::Wardrobe.text(win, i, scene) }
      assert_equal ["Normal", "Classic, #{chosen}", "Magma"], got, what
    end
  end

  test "a row outside the list, a blank name or no list reads as nothing" do
    { "before the first row" => [ROWS, -1], "past the last row" => [ROWS, 3], "a blank name" => [["  "], 0],
      "no list" => [nil, 0] }.each do |what, (outfits, i)|
      assert_nil PokeAccess::Wardrobe.text(WardrobeSpecList.new(outfits, 0, i), i), what
    end
  end

  test "an outfit whose name cannot be read reads as nothing" do
    bad = Object.new
    def bad.to_s; raise "unreadable"; end
    assert_nil PokeAccess::Wardrobe.text(WardrobeSpecList.new([bad], 0, 0), 0)
  end

  test "says the focused row once while it stays, and each row the cursor moves to" do
    scene = wardrobe_scene(:checked => 0, :current => 0, :index => 1)
    PokeAccess::Wardrobe.announce(scene)
    PokeAccess::Wardrobe.announce(scene)
    PokeAccess.sprite(scene, "outfitlist").index = 0
    PokeAccess::Wardrobe.announce(scene)
    assert_equal [["Classic", true], ["Normal, #{worn}", true]], SpeakCapture.log
  end

  test "says the focused row again when the check moves onto it and when confirming puts it on" do
    scene = wardrobe_scene(:checked => 0, :current => 0, :index => 2)
    PokeAccess::Wardrobe.announce(scene)
    SpeakCapture.clear
    PokeAccess.sprite(scene, "outfitlist").instance_variable_set(:@outfit_selected, 2)
    PokeAccess::Wardrobe.announce(scene)
    scene.instance_variable_set(:@outfit_current, 1)
    PokeAccess::Wardrobe.announce(scene)
    assert_equal [["Magma, #{chosen}", true], ["Magma, #{worn}", true]], SpeakCapture.log
  end

  test "says nothing without the list window, a cursor or a row to read" do
    { "no list window" => World.stub_scene(:@sprites => {}),
      "no cursor" => wardrobe_scene(:checked => 0, :current => 0, :index => nil),
      "a cursor past the rows" => wardrobe_scene(:checked => 0, :current => 0, :index => 5) }.each do |what, scene|
      PokeAccess::Wardrobe.announce(scene)
      assert_nothing_spoken what
    end
  end

  test "a poll reads the wardrobe while its main loop runs, and nothing once the loop returns" do
    scene = main_scene(:checked => 0, :current => 0, :index => 1) { PokeAccess::Wardrobe.poll }
    scene.pbMain
    PokeAccess.sprite(scene, "outfitlist").index = 2
    PokeAccess::Wardrobe.poll
    assert_equal [["Classic", true]], SpeakCapture.log
  ensure
    PokeAccess::Wardrobe.unwatch
  end

  test "stops reading the wardrobe when its main loop ends in an error" do
    scene = main_scene(:checked => 0, :current => 0, :index => 1) { raise "closed" }
    assert_raises(RuntimeError) { scene.pbMain }
    PokeAccess::Wardrobe.poll
    assert_nothing_spoken
  ensure
    PokeAccess::Wardrobe.unwatch
  end

  test "claims its list window as it is built, so the generic reader leaves the rows to it" do
    assert PokeAccess.dedicated?(WardrobeSpecList.new(ROWS, 0, 0))
  end

  test "a game whose wardrobe scene has no main loop reports no hook missing" do
    assert_equal [], MISSING_WITHOUT_MAIN_LOOP
  end

  private

  def worn; PokeAccess::I18n.t(:wardrobe_worn); end

  def chosen; PokeAccess::I18n.t(:wardrobe_chosen); end

  # Every row as read with the check on row :checked and the outfit at :current of the full list on.
  def rows(opts)
    win = WardrobeSpecList.new(ROWS, opts[:checked], 0)
    scene = World.stub_scene(:@outfit_all => ALL, :@outfit_current => opts[:current])
    ROWS.each_index.map { |i| PokeAccess::Wardrobe.text(win, i, scene) }
  end

  # A wardrobe scene with its list window (the check on row :checked, the cursor on row :index) and the outfit at
  # :current of its full list on.
  def wardrobe_scene(opts)
    furnish(Object.new, opts)
  end

  # The same as a scene whose main loop runs the block.
  def main_scene(opts, &during)
    furnish(WardrobeSpecScene.new(&during), opts)
  end

  # Gives scene the list window and the full list of outfits wardrobe_scene describes.
  def furnish(scene, opts)
    list = WardrobeSpecList.new(ROWS, opts[:checked], opts[:index])
    scene.instance_variable_set(:@sprites, { "outfitlist" => list })
    scene.instance_variable_set(:@outfit_all, ALL)
    scene.instance_variable_set(:@outfit_current, opts[:current])
    scene
  end
end
