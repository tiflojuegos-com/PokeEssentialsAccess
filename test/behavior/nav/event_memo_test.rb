# The probe's memo and the regions follow the map's events (World::Events.sync, as each search opens and once a frame):
# an event that comes, goes, moves or changes drops what was kept of every tile it covers, and nothing else does.
class EventMemoTest < PokeAccessTest
  Probe = PokeAccess::World::Probe
  Pf = PokeAccess::Pathfinder
  CORRIDOR = ["#########",
              "#@......#",
              "#########"]

  test "closes a way an event comes to stand across, though its steps were kept open" do
    with_sized_events_blocking do
      corridor
      walk_route(5, 1, true)
      rock(7, 3)
      assert_nil walk_route(5, 1, true)
    end
  end

  test "reopens the way once the event across it goes" do
    with_sized_events_blocking do
      corridor
      rock(7, 3)
      walk_route(5, 1, true)
      $game_map.events.delete(7)
      assert_equal [6, 6, 6, 6], walk_route(5, 1, true)
    end
  end

  test "reopens the tile an event moves off and closes the one it moves onto" do
    with_sized_events_blocking do
      corridor
      boulder = rock(7, 3)
      walk_route(5, 1, true)
      boulder.x = 6
      assert_equal [[6, 6, 6, 6], nil], [walk_route(5, 1, true), walk_route(7, 1, true)]
    end
  end

  test "closes the step onto a wide event's second tile once it stops letting the player through" do
    with_sized_events_blocking do
      corridor
      gate = wide_gate
      open = Pf.with_level_kept { Probe.step?(4, 1, 4) }
      gate.through = false
      assert_equal [true, false], [open, Pf.with_level_kept { Probe.step?(4, 1, 4) }]
    end
  end

  test "drops the tiles the regions on foot reached through a wide event once a frame finds it shutting the way" do
    with_sized_events_blocking do
      corridor
      gate = wide_gate
      walked = PokeAccess::Routes::Regions.foot.tiles.sort
      gate.through = false
      World.next_frame
      assert_equal [(1..7).map { |x| [x, 1] }, [[1, 1]]], [walked, PokeAccess::Routes::Regions.foot.tiles.sort]
    end
  end

  test "closes the step onto a sprite-less event once it takes a tile graphic" do
    with_sized_events_blocking do
      corridor
      slab = World.event(:id => 9, :x => 3, :y => 1)
      slab.character_name = ""
      open = Pf.with_level_kept { Probe.step?(2, 1, 6) }
      slab.tile_id = 400
      assert_equal [true, false], [open, Pf.with_level_kept { Probe.step?(2, 1, 6) }]
    end
  end

  test "answers a step asked outside any search as the events stand once a frame finds them" do
    with_sized_events_blocking do
      corridor
      slab = World.event(:id => 9, :x => 3, :y => 1)
      slab.character_name = ""
      open = Probe.step?(2, 1, 6)
      slab.tile_id = 400
      World.next_frame
      assert_equal [true, false], [open, Probe.step?(2, 1, 6)]
    end
  end

  test "asks the engine once for a step while the events stand as they were" do
    with_sized_events_blocking do
      corridor
      World.event(:id => 9, :x => 6, :y => 1, :sprite => "npc")
      2.times { Pf.with_level_kept { Probe.step?(2, 1, 6) } }
      assert_equal 1, $game_player.instance_variable_get(:@pa_spec_asked)
    end
  end

  private

  # The corridor, the routes and the probe's answers dropped.
  def corridor
    $game_map.load_grid(CORRIDOR)
    Pf.invalidate_cache(true)
  end

  # A rock, event id, on (x, 1).
  def rock(id, x)
    ev = World.event(:id => id, :x => x, :y => 1)
    ev.character_name = "rock"
    ev
  end

  # A gate two tiles wide on (2, 1) and (3, 1), event 8, letting the player through.
  def wide_gate
    gate = World.event(:id => 8, :x => 2, :y => 1)
    gate.instance_variable_set(:@width, 2)
    gate.instance_variable_set(:@height, 1)
    gate.through = true
    gate
  end

  # Runs the block with the player's passable? keeping the engine's event rule (v19 Game_Character#passable?,
  # Game_Map#passable?): an event that is not through blocks every tile its size covers, right and up from its own,
  # when it shows a sprite or a tile. The player's @pa_spec_asked counts the answers given.
  def with_sized_events_blocking
    $game_player.instance_variable_set(:@pa_spec_asked, 0)
    class << $game_player
      alias_method :sized_spec_passable?, :passable?
      def passable?(x, y, d)
        @pa_spec_asked += 1
        dd = PokeAccess::DIR_DELTA[d]
        nx = x + dd[0]
        ny = y + dd[1]
        $game_map.events.each_value do |e|
          next if e.through || (e.character_name.to_s.empty? && e.tile_id.to_i <= 0)
          w = e.instance_variable_get(:@width) || 1
          h = e.instance_variable_get(:@height) || 1
          return false if nx >= e.x && nx < e.x + w && ny > e.y - h && ny <= e.y
        end
        sized_spec_passable?(x, y, d)
      end
    end
    yield
  ensure
    class << $game_player; remove_method :passable?, :sized_spec_passable?; end
    $game_player.remove_instance_variable(:@pa_spec_asked)
  end
end
