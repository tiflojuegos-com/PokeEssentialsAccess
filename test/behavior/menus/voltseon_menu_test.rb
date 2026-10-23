# Voltseon's Pause Menu, a carousel of icons replacing the field menu (the focused one is only drawn larger): the
# focused entry is said once per move, 1.x's entry objects and 2.x's hashes alike, and the panels painted around the
# carousel once the menu opens, after the entry.

# The menu's 1.x scene, holding the menu in @pauseMenu, as the plugin paints it: the map's name, then the panels'
# rows (empty ones included); opening refreshes, then settles the carousel, which says the entry. Its update is the
# menu's loop, running what the test hands it.
class VoltseonPanelsScene
  attr_accessor :panel_rows, :during
  def initialize(menu); @pauseMenu = menu; end

  def pbRefresh
    pbDrawTextPositions(nil, [["Ruta 5", 0, 12, 1, nil, nil, true]])
    pbDrawTextPositions(nil, (@panel_rows || []).map { |t| [t, 0, 12, 1, nil, nil] })
  end

  def pbStartScene
    pbRefresh
    PokeAccess::VoltseonMenu.read(@pauseMenu)
  end

  def update; @during.call if @during; end
end

# The 2.x carousel: entry hashes under @current_selection, settled by refresh_menu (it has no refreshMenu).
class VoltseonSpecCarousel
  def initialize(entries); @entries = entries; @current_selection = 0; end
  def current_selection=(i); @current_selection = i; end
  def refresh_menu; nil; end
end

# A 1.x entry: an object that names itself.
class VoltseonSpecEntry
  def initialize(name); @name = name; end
  def name; @name; end
end

class VoltseonMenuTest < PokeAccessTest
  PLUGIN = File.join(Harness::ROOT, "plugins", "voltseon_pausemenu.rb")
  MANIFEST = File.join(Harness::ROOT, "plugins", "manifest.rb")

  # Loads the plugin again with these classes standing in under the game's names ({name => class}), so its hooks bind
  # to them, and answers the hooks that load reported missing; the names and the menu-return listeners are put back.
  # param file the name the source is evaluated under; a name of its own keeps the load out of the plugin's coverage
  def self.load_plugin_with(stand_ins, file = PLUGIN)
    verbose = $VERBOSE
    before = PokeAccess::Hooks.missing.dup
    saved = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    stand_ins.each { |n, k| Object.const_set(n, k) }
    listeners = PokeAccess::MenuReturn.instance_variable_get(:@listeners).dup
    $VERBOSE = nil
    eval(Harness.source(PLUGIN), TOPLEVEL_BINDING, file)
    PokeAccess::Hooks.missing - before
  ensure
    $VERBOSE = verbose
    PokeAccess::MenuReturn.instance_variable_set(:@listeners, listeners) if listeners
    stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (saved || []).each { |n, k| Object.const_set(n, k) if k }
  end
  private_class_method :load_plugin_with

  # Both loads run as this file loads, before any test: a class binds once (a second load of the stand-ins would stack
  # their hooks), and the stand-ins' load comes last, as the one the tests drive and coverage counts.
  MISSING_ON_BARE_MENU = load_plugin_with({ :VoltseonsPauseMenu => Class.new, :VoltseonsPauseMenu_Scene => Class.new },
                                          "bare:#{PLUGIN}")
  load_plugin_with(:VoltseonsPauseMenu => VoltseonSpecCarousel, :VoltseonsPauseMenu_Scene => VoltseonPanelsScene)

  test "names the focused entry of a 1.x carousel by the entry's own name" do
    assert_equal "Pokemon", PokeAccess::VoltseonMenu.focused_name(v1_menu(1))
  end

  test "names the focused entry of a 2.x carousel by its hash's name" do
    assert_equal "Bolsa", PokeAccess::VoltseonMenu.focused_name(v2_menu(1))
  end

  test "names nothing past the entries, with no entries or selection, or for a name blank or unreadable" do
    unreadable = Object.new
    def unreadable.to_s; raise "unreadable"; end
    { "a selection past the entries" => v1_menu(9), "no entries at all" => Object.new,
      "entries that are no list" => World.stub_scene(:@entries => { 0 => { :name => "Pokedex" } },
                                                     :@current_selection => 0),
      "no selection" => World.stub_scene(:@entries => [VoltseonSpecEntry.new("Pokedex")]),
      "a blank name" => World.stub_scene(:@entries => [{ :name => "" }], :@current_selection => 0),
      "no name" => World.stub_scene(:@entries => [{ :icon => "a" }], :@current_selection => 0),
      "a name that cannot be read" => World.stub_scene(:@entries => [{ :name => unreadable }], :@current_selection => 0)
    }.each { |what, menu| assert_nil PokeAccess::VoltseonMenu.focused_name(menu), what }
  end

  test "says the focused entry on arrival, queued, and once while it stays" do
    menu = v1_menu(0)
    PokeAccess::VoltseonMenu.read(menu)
    PokeAccess::VoltseonMenu.read(menu)
    assert_equal [["Pokedex", false]], SpeakCapture.log
  end

  test "says each entry the carousel moves to, interrupting" do
    menu = v2_menu(0)
    PokeAccess::VoltseonMenu.read(menu)
    SpeakCapture.clear
    menu.instance_variable_set(:@current_selection, 1)
    PokeAccess::VoltseonMenu.read(menu)
    assert_equal [["Bolsa", true]], SpeakCapture.log
  end

  test "says nothing where the carousel has no entry to name" do
    PokeAccess::VoltseonMenu.read(v1_menu(9))
    assert_nothing_spoken
  end

  test "says the entry named as the player as the trainer card" do
    player = PokeAccess::Engine.player.name
    PokeAccess::VoltseonMenu.read(World.stub_scene(:@entries => [{ :name => player }], :@current_selection => 0))
    assert_equal [["#{player}, #{PokeAccess::I18n.t(:tc_title)}", false]], SpeakCapture.log
  end

  test "a return says a 2.x menu's entry again only while its scene is held" do
    menu = v2_menu(1)
    PokeAccess::VoltseonMenu.read(menu)
    PokeAccess::VoltseonMenu.watch(World.stub_scene(:@pause_menu => menu))
    SpeakCapture.clear
    PokeAccess::VoltseonMenu.returned
    PokeAccess::VoltseonMenu.read(menu)
    assert_equal [["Bolsa", false]], SpeakCapture.log, "held: the refresh after the return says it again"
    PokeAccess::VoltseonMenu.unwatch
    SpeakCapture.clear
    PokeAccess::VoltseonMenu.returned
    PokeAccess::VoltseonMenu.read(menu)
    assert_nothing_spoken "its loop ended: the return changes nothing"
  ensure
    PokeAccess::VoltseonMenu.unwatch
  end

  test "a carousel says the focused entry each time it refreshes on a new one" do
    carousel = VoltseonSpecCarousel.new([{ :name => "Pokedex" }, { :name => "Bolsa" }])
    carousel.refresh_menu
    carousel.current_selection = 1
    carousel.refresh_menu
    carousel.refresh_menu
    assert_equal [["Pokedex", false], ["Bolsa", true]], SpeakCapture.log
  end

  test "a menu without a method it hooks (2.x has no refreshMenu, 1.x no refresh_menu) reports no hook missing" do
    assert_equal [], MISSING_ON_BARE_MENU
  end

  test "while the menu's loop runs, an option's return says the entry again; once it ends, a return says nothing" do
    menu = v1_menu(0)
    scene = VoltseonPanelsScene.new(menu)
    PokeAccess::VoltseonMenu.read(menu)
    SpeakCapture.clear
    scene.during = lambda { option_returns; PokeAccess::VoltseonMenu.read(menu) }
    scene.update
    option_returns
    PokeAccess::VoltseonMenu.read(menu)
    assert_equal [["Pokedex", false]], SpeakCapture.log
  end

  test "once the menu opens, says the panels it paints after the entry, both queued" do
    scene = VoltseonPanelsScene.new(v1_menu(0))
    scene.panel_rows = ["12 Sep 2026", "03:15 PM", "", "You have 1 new quest!"]
    scene.pbStartScene
    assert_equal [["Pokedex", false], ["Ruta 5, 12 Sep 2026, 03:15 PM, You have 1 new quest!", false]], SpeakCapture.log
  end

  test "a later refresh, back from a submenu, says no panels" do
    scene = VoltseonPanelsScene.new(v1_menu(0))
    scene.pbStartScene
    SpeakCapture.clear
    scene.panel_rows = ["03:16 PM"]
    scene.pbRefresh
    assert_nothing_spoken
  ensure
    PokeAccess::VoltseonMenu.instance_variable_set(:@panels, nil)
  end

  test "says the panels of one opening once, and none when nothing was painted" do
    vm = PokeAccess::VoltseonMenu
    vm.capture_panels { pbDrawTextPositions(nil, [["Ruta 5", 0, 12, 1, nil, nil]]) }
    vm.say_panels
    vm.say_panels
    vm.capture_panels {}
    vm.say_panels
    assert_equal [["Ruta 5", false]], SpeakCapture.log
  end

  test "is detected by the class only the plugin defines" do
    assert_equal "VoltseonsPauseMenu", eval(Harness.source(MANIFEST), TOPLEVEL_BINDING, MANIFEST)[:voltseon_pausemenu]
  end

  private

  # A 1.x carousel of entry objects, focused on index.
  def v1_menu(index)
    entries = ["Pokedex", "Pokemon", "Mochila"].map { |n| VoltseonSpecEntry.new(n) }
    World.stub_scene(:@entries => entries, :@currentSelection => index)
  end

  # An option's screen closing back to the menu: the outermost return seam fires its listeners.
  def option_returns
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  end

  # A 2.x carousel of entry hashes, focused on index.
  def v2_menu(index)
    World.stub_scene(:@entries => [{ :icon => "a", :name => "Pokedex" }, { :icon => "b", :name => "Bolsa" }],
                     :@current_selection => index)
  end
end
