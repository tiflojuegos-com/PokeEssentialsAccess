# Lens of Truth tiles (events named with #EOT): a :lens category offered where the map holds one (one to get to, while
# hiding), listed under :all too as the hidden area, and the hidden-area notice said once on arriving on one.
class LensCategoryTest < PokeAccessTest
  Locator = PokeAccess::Locator
  Surfaces = PokeAccess::Surfaces

  test "an event named with #EOT is a lens tile, whatever else its name says" do
    broken = Object.new
    def broken.name; raise ArgumentError, "no name"; end
    { "Misterio#EOT_HIDE" => true, "#EOT HIDE" => true, "EV010" => false, "#eot" => false, "" => false }.each do |name, want|
      assert_equal want, Locator.lens_tile?(World.event(:name => name, :id => 5)), "named #{name.inspect}"
    end
    assert_equal false, Locator.lens_tile?(broken), "an event whose name cannot be read"
  end

  test "a lens tile with no sprite falls in :lens and under :all alone, a person in :people and under :all" do
    lens = World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8, :sprite => "")
    person = World.event(:name => "EV010", :id => 6, :x => 3, :y => 3)
    { [lens, :lens] => true, [lens, :all] => true, [lens, :people] => false, [lens, :objects] => false,
      [lens, :extras] => false, [lens, :signs] => false, [lens, :exits] => false,
      [person, :lens] => false, [person, :all] => true, [person, :people] => true }.each do |(ev, cat), want|
      assert_equal want, Locator.in_category?(ev, cat), "#{ev.name} in #{cat}"
    end
  end

  test "the player's category for a lens tile wins over :lens, and keeps it under :all" do
    lens = World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8)
    PokeAccess::Tags.set_category($game_map.map_id, 5, :people)
    assert_equal [false, true, true],
                 [Locator.in_category?(lens, :lens), Locator.in_category?(lens, :people), Locator.in_category?(lens, :all)]
  ensure
    PokeAccess::Tags.delete($game_map.map_id, 5)
  end

  test "a lens tile is said as the hidden area" do
    lens = World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8)
    assert_equal PokeAccess::I18n.t(:loc_lens), Locator.target_name(lens)
  end

  test ":lens is offered only on a map that holds a lens tile, after the configured categories" do
    base = PokeAccess::Config.categories
    assert_equal base, Locator.active_categories, "a map with none"
    World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8)
    assert_equal base + [:lens], Locator.active_categories, "a map with one"
    $game_map.events.delete(5)
    assert_equal base, Locator.active_categories, "the tile gone"
  end

  test "a :lens put among the configured categories is offered only where the map holds a lens tile, and once" do
    with_categories(PokeAccess::Config.categories + [:lens]) do
      assert_equal false, Locator.active_categories.include?(:lens), "a map with none"
      World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8)
      assert_equal 1, Locator.active_categories.count(:lens), "a map with one"
    end
  end

  test "a map with no lens tile holds none, nor does the game before it has a map" do
    World.event(:name => "EV010", :id => 6, :x => 3, :y => 3)
    assert_equal false, Locator.any_lens_tile?, "a map with a person alone"
    without_map { assert_equal false, Locator.any_lens_tile?, "no map" }
  end

  test "a map whose events cannot be read holds no lens tile" do
    World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8)
    unreadable_events { assert_equal false, Locator.any_lens_tile? }
  end

  test "while hiding the targets one cannot interact with, a :lens offered has its tile to list" do
    World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8, :sprite => "")
    PokeAccess::Config.hide_noninteractive = true
    assert_equal false, Locator.active_categories.include?(:lens) && listed(:lens).empty?
  end

  test "while hiding, :lens is left out when its only tiles cannot be got to" do
    sealed_room
    World.event(:name => "#EOT HIDE", :id => 7, :x => 29, :y => 5)
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal false, Locator.active_categories.include?(:lens)
  end

  test "with hiding off, :lens is offered though its tiles cannot be got to" do
    sealed_room
    World.event(:name => "#EOT HIDE", :id => 7, :x => 29, :y => 5)
    assert_equal true, Locator.active_categories.include?(:lens)
  end

  test "while hiding, :lens is offered when one of its tiles can be got to, and lists that one alone" do
    sealed_room
    World.event(:name => "#EOT HIDE", :id => 7, :x => 29, :y => 5)
    World.event(:name => "#EOT HIDE", :id => 8, :x => 10, :y => 5)
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal true, Locator.active_categories.include?(:lens), "offered"
    assert_equal [8], listed(:lens).map { |t| t.id }, "listing only the tile the player can get to"
  end

  test "while hiding, :lens comes at the next frame once the person in the way to its tile leaves the map" do
    hpa_fresh_grid(["##########", "#@.....#.#", "#........#", "##########"])
    World.event(:name => "#EOT HIDE", :id => 7, :x => 8, :y => 1)
    World.event(:kind => :npc, :id => 9, :x => 7, :y => 2).blocking = true
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal false, Locator.active_categories.include?(:lens), "the way to the tile shut"
    $game_map.events.delete(9)
    assert_equal false, Locator.active_categories.include?(:lens), "the same frame"
    World.next_frame
    assert_equal true, Locator.active_categories.include?(:lens), "the next frame"
  end

  test "while hiding, :lens is offered while the regions cannot tell yet" do
    sealed_room
    World.event(:name => "#EOT HIDE", :id => 7, :x => 29, :y => 5)
    PokeAccess::Config.hide_unreachable = :unreachable
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1000
    assert_equal true, Locator.active_categories.include?(:lens), "offered"
    assert_equal false, PokeAccess::Routes::Regions.foot.done?, "the regions' walk being cut short"
  end

  test "while hiding, :lens is offered when asking whether its tiles can be got to fails" do
    sealed_room
    World.event(:name => "#EOT HIDE", :id => 7, :x => 29, :y => 5)
    PokeAccess::Config.hide_unreachable = :unreachable
    failing_reach { assert_equal true, Locator.active_categories.include?(:lens) }
  end

  test "arriving on a lens tile says the hidden area, queued" do
    on_lens_tile
    Surfaces.lens_tile
    assert_equal [[PokeAccess::I18n.t(:lens_tile_here), false]], SpeakCapture.log
  end

  test "the frames that follow on the lens tile say nothing" do
    on_lens_tile
    Surfaces.lens_tile
    SpeakCapture.clear
    3.times { Surfaces.lens_tile }
    assert_nothing_spoken
  end

  test "coming back onto a lens tile says the hidden area again" do
    on_lens_tile
    Surfaces.lens_tile
    $game_player.x += 1
    Surfaces.lens_tile
    $game_player.x -= 1
    SpeakCapture.clear
    Surfaces.lens_tile
    assert_equal [PokeAccess::I18n.t(:lens_tile_here)], SpeakCapture.lines
  end

  test "arriving on a tile whose event is no lens tile says nothing" do
    World.event(:name => "EV010", :id => 5, :x => $game_player.x, :y => $game_player.y)
    Surfaces.reset_map_state
    SpeakCapture.clear
    Surfaces.lens_tile
    assert_nothing_spoken
  end

  test "the hidden-area notice looks at the map's events once per tile entered, not at every frame" do
    on_lens_tile
    counting_looks do |looks|
      4.times { Surfaces.lens_tile }
      $game_player.x += 1
      Surfaces.lens_tile
      $game_player.x -= 1
      Surfaces.lens_tile
      assert_equal 3, looks[0], "one look on arrival, one off the tile, one back on it"
    end
  end

  test "the hidden-area notice says nothing when the map's events cannot be read" do
    on_lens_tile
    failing_looks { Surfaces.lens_tile }
    assert_nothing_spoken
  end

  private

  # A 32x12 map: an open room with the player at (1, 1), and a strip at x 29 and 30 walled off from it.
  def sealed_room
    rows = ["#" * 32, "#@" + "." * 26 + "#..#"]
    9.times { rows.push("#" + "." * 27 + "#..#") }
    rows.push("#" * 32)
    hpa_fresh_grid(rows)
  end

  # A lens tile under the player, nothing said or remembered yet.
  def on_lens_tile
    World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => $game_player.x, :y => $game_player.y)
    Surfaces.reset_map_state
    SpeakCapture.clear
  end

  # The targets the locator lists in category cat, rebuilt now, the category shown put back after.
  def listed(cat)
    was = Locator.instance_variable_get(:@cat_id)
    Locator.instance_variable_set(:@cat_id, cat)
    Locator.rebuild_targets
    Locator.instance_variable_get(:@targets)
  ensure
    Locator.instance_variable_set(:@cat_id, was)
  end

  # Runs the block with the configured categories set to cats, put back after.
  def with_categories(cats)
    was = PokeAccess::Config.categories
    PokeAccess::Config.categories = cats
    yield
  ensure
    PokeAccess::Config.categories = was
  end

  # Runs the block with no map loaded, as before the game has one.
  def without_map
    was = $game_map
    $game_map = nil
    yield
  ensure
    $game_map = was
  end

  # Runs the block with Routes::Planner.reach raising, the real one put back after.
  def failing_reach
    planner = PokeAccess::Routes::Planner
    real = planner.method(:reach)
    planner.define_singleton_method(:reach) { |*_a| raise IOError, "the regions cannot be read" }
    yield
  ensure
    planner.define_singleton_method(:reach, real)
  end

  # Runs the block with the map's events unreadable (nil, as a map not set up yet), the map's own reader put back after.
  def unreadable_events
    $game_map.define_singleton_method(:events) { nil }
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :events)
  end

  # Runs the block with Control.event_at counting its calls in looks[0], the real one put back after.
  def counting_looks
    ctl = PokeAccess::Control
    real = ctl.method(:event_at)
    looks = [0]
    ctl.define_singleton_method(:event_at) { |x, y| looks[0] += 1; real.call(x, y) }
    yield looks
  ensure
    ctl.define_singleton_method(:event_at, real)
  end

  # Runs the block with Control.event_at raising, the real one put back after.
  def failing_looks
    ctl = PokeAccess::Control
    real = ctl.method(:event_at)
    ctl.define_singleton_method(:event_at) { |_x, _y| raise IOError, "the events cannot be read" }
    yield
  ensure
    ctl.define_singleton_method(:event_at, real)
  end
end
