# The registry of per-map resets (core/foundation/caches.rb): every module that remembers the map registers its reset
# (the list is literal on purpose, not derived from the code), and a map change runs them all in order, a failing one
# not stopping the rest; what the surfaces, the radar, the cursor table and the guides remember is then forgotten.
class CachesRegistryTest < PokeAccessTest
  Caches = PokeAccess::Caches
  REGISTERED = [:world, :sound, :pathfinder, :feedback, :surfaces, :cursor_global, :guide, :locator, :verdicts,
                :map_meta, :forced_move, :town_map_open]
  PROBES = [:spec_probe_a, :spec_probe_b, :spec_probe_c]

  test "every module that remembers the map is registered to forget it" do
    assert_equal [], REGISTERED - Caches.names
  end

  test "a map change runs the resets in the order they were registered" do
    ran = []
    with_probes(lambda { ran.push(:a) }, lambda { ran.push(:b) }, lambda { ran.push(:c) }) do
      PokeAccess::Events.emit(:map_changed)
    end
    assert_equal [:a, :b, :c], ran
  end

  test "a reset that raises does not stop the ones after it" do
    ran = []
    with_probes(lambda { ran.push(:a) }, lambda { raise "este reset revienta" }, lambda { ran.push(:c) }) do
      Caches.reset_all
    end
    assert_equal [:a, :c], ran
  end

  test "a reset that keeps raising is written to the diagnostic marker once" do
    Caches.register(:spec_probe_twice) { raise "este reset revienta" }
    before = marker_lines("cache_reset_spec_probe_twice")
    2.times { PokeAccess::Events.emit(:map_changed) }
    assert_equal 1, marker_lines("cache_reset_spec_probe_twice") - before
  ensure
    Caches.register(:spec_probe_twice) { }
  end

  test "registering a name again replaces its reset in its place, listed once" do
    ran = []
    with_probes(lambda { ran.push(:a) }, lambda { ran.push(:b) }, lambda { ran.push(:c) }) do
      Caches.register(:spec_probe_a) { ran.push(:a2) }
      Caches.reset_all
      assert_equal PROBES, Caches.names.select { |n| PROBES.include?(n) }, "each name once, in the first order"
    end
    assert_equal [:a2, :b, :c], ran
  end

  test "after a map change the ground underfoot is said again" do
    PokeAccess::Config.surface_cues = true
    said = with_tile_world(["#####", "#g@.#", "#####"]) do
      $game_player.x = 1
      surfaces = PokeAccess::Surfaces
      surfaces.reset_map_state
      2.times { surfaces.surfaces }
      Caches.reset_all
      surfaces.surfaces
      SpeakCapture.lines
    end
    grass = PokeAccess::I18n.t(:surf_tallgrass)
    assert_equal [grass, grass], said, "on arrival, not while standing, and again after the change"
  ensure
    PokeAccess::Surfaces.reset_map_state
  end

  test "after a map change the hidden-area notice is said again on the same tile" do
    World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => $game_player.x, :y => $game_player.y)
    surfaces = PokeAccess::Surfaces
    surfaces.reset_map_state
    surfaces.lens_tile
    surfaces.lens_tile
    Caches.reset_all
    surfaces.lens_tile
    notice = PokeAccess::I18n.t(:lens_tile_here)
    assert_equal [notice, notice], SpeakCapture.lines, "on arrival, not while standing, and again after the change"
  ensure
    World.clear_events
    PokeAccess::Surfaces.reset_map_state
  end

  test "after a map change the radar ticks again for what stands in front" do
    PokeAccess::Config.proximity_radar = true
    World.event(:kind => :sign, :id => 6, :x => $game_player.x, :y => $game_player.y + 1)
    feedback = PokeAccess::Sound::Feedback
    feedback.reset_map_state
    ticks = 0
    with_cue_log do |log|
      feedback.radar
      feedback.radar
      Caches.reset_all
      feedback.radar
      ticks = log.count { |entry| cue_name(entry).include?("pa_guide_c") }
    end
    assert_equal 2, ticks, "once on facing it, and again after the change"
  ensure
    World.clear_events
    PokeAccess::Sound::Feedback.reset_map_state
  end

  test "after a map change a reader with no holder says its line again" do
    3.times do |i|
      Caches.reset_all if i == 2
      PokeAccess::Cursor.announce(nil, :spec_slot, 1, true) { "primero" }
    end
    assert_equal [["primero", true], ["primero", true]], SpeakCapture.log, "once, then again after the change"
  end

  test "a map change turns the guides off in silence and drops their route" do
    g = PokeAccess::Guide
    g.switch(:cane, true)
    g.switch(:steps, true)
    g.instance_variable_set(:@plan, PokeAccess::Routes::Plan.new(:none))
    g.instance_variable_set(:@verdict, [nil, nil, [1, 2, 0], 0])
    g.instance_variable_set(:@goal, [3, 4])
    Caches.reset_all
    assert_equal [false, false, false], [g.on?(:cane), g.on?(:steps), g.on?], "both guides off, so none is left on"
    assert_equal [nil, nil, nil], [g.instance_variable_get(:@plan), g.instance_variable_get(:@verdict),
                                   g.instance_variable_get(:@goal)], "the plan, the no-way verdict and its goal dropped"
    assert_nothing_spoken
  end

  private

  # The lines of the diagnostic marker file that name key.
  def marker_lines(key)
    File.exist?(PokeAccess.marker_file) ? File.binread(PokeAccess.marker_file).lines.count { |l| l.include?(key) } : 0
  end

  # Runs the block with the three resets registered under PROBES, in that order; emptied after.
  def with_probes(a, b, c)
    PROBES.zip([a, b, c]).each { |name, blk| Caches.register(name, &blk) }
    yield
  ensure
    PROBES.each { |n| Caches.register(n) { } }
  end
end
