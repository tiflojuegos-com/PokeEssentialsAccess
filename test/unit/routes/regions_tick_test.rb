# The map frames' walk of the regions (regions_background): none for SETTLE_FRAMES once the regions were dropped, also
# when it is the very frame's own reading of the world that finds the change dropping them; and no dump of the map
# to compare its tiles in a frame that walks nothing.

class RegionsTickTest < PokeAccessTest
  test "walks nothing in the frame whose own reading of the events drops the regions" do
    with_background_regions do |rg|
      rg.foot
      rg.instance_variable_set(:@calm, 0)
      World.event(:kind => :sign, :id => 70, :x => 5, :y => 2)
      rg.tick
      assert_equal 0, rg.foot.instance_variable_get(:@head)
    end
  end

  test "dumps no map in the frames once the regions are walked" do
    with_background_regions do |rg|
      rg.foot
      rg.instance_variable_set(:@calm, 0)
      40.times { World.next_frame; rg.tick }
      assert rg.foot.done?
      assert_equal 0, dumps_over(5) { World.next_frame; rg.tick }
    end
  end

  private

  def with_background_regions
    $game_map.load_grid(["############", "#@.........#", "#..........#", "############"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Config.regions_background = true
    yield PokeAccess::Routes::Regions
  ensure
    PokeAccess::Config.regions_background = false
    World.clear_events
    $game_map.clear_grid
  end

  def dumps_over(frames)
    n = 0
    epoch = PokeAccess::World::Epoch
    epoch.singleton_class.send(:alias_method, :fingerprint_spec, :fingerprint)
    epoch.define_singleton_method(:fingerprint) { n += 1; fingerprint_spec }
    frames.times { yield }
    n
  ensure
    epoch.singleton_class.send(:alias_method, :fingerprint, :fingerprint_spec)
    epoch.singleton_class.send(:remove_method, :fingerprint_spec)
  end
end
