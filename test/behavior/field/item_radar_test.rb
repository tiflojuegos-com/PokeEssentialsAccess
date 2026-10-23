# Reborn SWM's Item Radar Mod (plugins/item_radar.rb), in both Soulstones: the hidden items near the player marked by
# each aUpdateRadar once the Itemfinder turns it on, and how many and the nearest one, said whenever that set changes.
class ItemRadarTest < PokeAccessTest
  # Each test starts with the radar off, as a game starts it, and no self switch on.
  def setup
    super
    @switches_was = $game_self_switches
    $game_self_switches = {}
    radar.update(screen(false))
  end

  # Puts the game's self switches back.
  def teardown
    $game_self_switches = @switches_was
    super
  end

  test "marks the hidden items less than 8 columns and 6 rows away, either side" do
    $game_player.x = 10
    $game_player.y = 10
    reach = { [17, 15] => [1], [3, 5] => [1], [18, 10] => [], [2, 10] => [], [10, 16] => [], [10, 4] => [] }
    reach.each do |(x, y), want|
      World.clear_events
      World.event(:id => 1, :name => "HiddenItem", :x => x, :y => y)
      assert_equal want, radar.marked.map { |e| e.id }, "an item at (#{x}, #{y})"
    end
  end

  test "marks only the events named HiddenItem" do
    { "HiddenItem" => [1], "Tree" => [], "HiddenItem2" => [], "hiddenitem" => [] }.each do |name, want|
      World.clear_events
      World.event(:id => 1, :name => name, :x => 7, :y => 5)
      assert_equal want, radar.marked.map { |e| e.id }, "an event named #{name.inspect}"
    end
  end

  test "does not mark an item picked up, whichever of its self switches is on" do
    %w[A B C D].each do |switch|
      $game_self_switches = { [1, 1, switch] => true }
      World.clear_events
      World.event(:id => 1, :name => "HiddenItem", :x => 7, :y => 5)
      assert_equal [], radar.marked, "self switch #{switch}"
    end
  end

  test "an item picked up on another map is still marked here" do
    $game_self_switches[[2, 1, "A"]] = true
    World.event(:id => 1, :name => "HiddenItem", :x => 7, :y => 5)
    assert_equal [1], radar.marked.map { |e| e.id }
  end

  test "marks the nearest first by steps, then by event id" do
    { 1 => [2, 5], 2 => [7, 5], 3 => [5, 2], 4 => [5, 7] }.each do |id, (x, y)|
      World.event(:id => id, :name => "HiddenItem", :x => x, :y => y)
    end
    assert_equal [2, 4, 1, 3], radar.marked.map { |e| e.id }, "two steps right and down, then three left and up"
  end

  test "marks the items where the game keeps no self switches" do
    $game_self_switches = nil
    World.event(:id => 1, :name => "HiddenItem", :x => 7, :y => 5)
    assert_equal [1], radar.marked.map { |e| e.id }
  end

  test "says how many it marks and the nearest one, queued behind the game's message" do
    two_items
    radar.update(screen(true))
    assert_equal [["#{t(:irad_marks, :n => 2)}. #{t(:if_direction, :n => 2, :dir => t(:dir_right))}", false]],
                 SpeakCapture.log
  end

  test "a step that leaves the same marks says nothing" do
    two_items
    on = screen(true)
    radar.update(on)
    SpeakCapture.clear
    radar.update(on)
    assert_nothing_spoken
  end

  test "an item picked up changes the marks, said again" do
    two_items
    on = screen(true)
    radar.update(on)
    SpeakCapture.clear
    $game_self_switches[[1, 1, "B"]] = true
    radar.update(on)
    assert_equal [["#{t(:irad_marks, :n => 1)}. #{t(:if_direction, :n => 4, :dir => t(:dir_up))}", false]],
                 SpeakCapture.log
  end

  test "with every item picked up it says it marks none" do
    two_items
    on = screen(true)
    radar.update(on)
    SpeakCapture.clear
    $game_self_switches[[1, 1, "A"]] = true
    $game_self_switches[[1, 2, "D"]] = true
    radar.update(on)
    assert_equal [[t(:irad_none), false]], SpeakCapture.log
  end

  test "says nothing while it is off, and its marks again once it is back on" do
    two_items
    radar.update(screen(true))
    SpeakCapture.clear
    radar.update(screen(false))
    assert_nothing_spoken "off"
    radar.update(screen(true))
    assert_equal [["#{t(:irad_marks, :n => 2)}. #{t(:if_direction, :n => 2, :dir => t(:dir_right))}", false]],
                 SpeakCapture.log
  end

  test "the same marks on another map are said anew" do
    two_items
    radar.update(screen(true))
    SpeakCapture.clear
    $game_map.map_id = 2
    radar.update(screen(true))
    assert_equal [["#{t(:irad_marks, :n => 2)}. #{t(:if_direction, :n => 2, :dir => t(:dir_right))}", false]],
                 SpeakCapture.log
  end

  private

  # The reader under test.
  def radar
    PokeAccess::ItemRadar
  end

  # A spoken text by its key.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The game's screen with the radar shown or hidden (aItemsFoundVisible).
  def screen(visible)
    World.stub_scene(:@aItemsFoundVisible => visible)
  end

  # Two hidden items in reach of the player at (5, 5): event 1 two steps right, event 2 four steps up.
  def two_items
    World.event(:id => 1, :name => "HiddenItem", :x => 7, :y => 5)
    World.event(:id => 2, :name => "HiddenItem", :x => 5, :y => 1)
  end
end
