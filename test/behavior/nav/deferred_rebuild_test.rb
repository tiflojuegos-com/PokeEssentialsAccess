# A running event's end marks the locator's list stale and forgets what it decided of each event (refresh_on_event_end);
# the list is rebuilt where it is next read (ensure_target), the selected target kept, at its place in the new list.
class DeferredRebuildTest < PokeAccessTest
  Loc = PokeAccess::Locator

  test "marks the list stale when a running event ends, leaving the list as it was" do
    with_locator_kept do
      list_with_b_selected
      listed = targets
      event_ends
      assert_equal [true, true], [targets.equal?(listed), stale?]
    end
  end

  test "marks nothing while the event still runs" do
    with_locator_kept do
      list_with_b_selected
      with_event_running do
        Loc.refresh_on_event_end
        Loc.refresh_on_event_end
      end
      assert_equal false, stale?
    end
  end

  test "decides afresh what an event is once a running event ends, keeping its answer until then" do
    with_locator_kept do
      ev = World.touch(:id => 3, :name => "Cartel", :x => 2, :y => 2, :list => [TestCmd.new(355, ["pbCaveExit"])])
      before = Loc.transfer_event?(ev)
      ev.name = "Salida"
      kept = Loc.transfer_event?(ev)
      event_ends
      assert_equal [false, false, true], [before, kept, Loc.transfer_event?(ev)]
    end
  end

  test "marks no empty list stale" do
    with_locator_kept do
      Loc.clear_targets
      event_ends
      assert_equal false, stale?
    end
  end

  test "drops the stale mark a teleport left along with the list it cleared" do
    with_locator_kept do
      Loc.instance_variable_set(:@targets_stale, true)
      Loc.clear_targets
      assert_equal false, stale?
    end
  end

  test "rebuilds a stale list where it is next read, the selected target kept at its new place" do
    with_locator_kept do
      a, b = list_with_b_selected
      assert_equal [b, a], targets, "the list as first built, from (5, 5)"
      event_ends
      $game_player.x = 3
      $game_player.y = 2
      Loc.ensure_target
      assert_equal [[a, b], b, 1, false], [targets, Loc.target, Loc.instance_variable_get(:@ti), stale?]
    end
  end

  test "drops from the rebuilt list an event the running one took away" do
    with_locator_kept do
      a, b = list_with_b_selected
      event_ends
      take_away(a)
      Loc.ensure_target
      assert_equal [b], targets
    end
  end

  test "leaves a fresh list alone where it is read" do
    with_locator_kept do
      list_with_b_selected
      listed = targets
      World.event(:kind => :npc, :id => 3, :x => 9, :y => 9)
      Loc.ensure_target
      assert_same listed, targets
    end
  end

  test "rebuilds a stale list whose selected target is gone, selecting the one now at its index" do
    with_locator_kept do
      a, b, c = three_in_a_row(1)
      event_ends
      take_away(b)
      Loc.ensure_target
      assert_equal [[a, c], c], [targets, Loc.target]
    end
  end

  test "rebuilds a stale list whose last target is gone, selecting the first" do
    with_locator_kept do
      a, b, c = three_in_a_row(2)
      event_ends
      take_away(c)
      Loc.ensure_target
      assert_equal [[a, b], a], [targets, Loc.target]
    end
  end

  test "selects the first target of the next list once a rebuild has left the list empty" do
    with_locator_kept do
      list_with_b_selected.each { |ev| take_away(ev) }
      event_ends
      Loc.ensure_target
      near = World.event(:kind => :npc, :id => 3, :x => 6, :y => 5)
      far = World.event(:kind => :npc, :id => 4, :x => 8, :y => 5)
      Loc.ensure_target
      assert_equal [[near, far], near], [targets, Loc.target]
    end
  end

  private

  # Two people on the map, a on (3, 1) and b on (6, 1), listed from where the player stands (5, 5), b selected.
  def list_with_b_selected
    a = World.event(:kind => :npc, :id => 1, :x => 3, :y => 1)
    b = World.event(:kind => :npc, :id => 2, :x => 6, :y => 1)
    Loc.rebuild_targets
    Loc.instance_variable_set(:@target, b)
    Loc.instance_variable_set(:@ti, targets.index(b))
    [a, b]
  end

  # Three people in a row east of the player, on (6, 5), (8, 5) and (10, 5), listed nearest first, the sel-th of them
  # selected.
  def three_in_a_row(sel)
    people = [6, 8, 10].each_with_index.map { |x, i| World.event(:kind => :npc, :id => i + 1, :x => x, :y => 5) }
    Loc.rebuild_targets
    Loc.instance_variable_set(:@target, people[sel])
    Loc.instance_variable_set(:@ti, targets.index(people[sel]))
    people
  end

  # The running event takes ev off the map.
  def take_away(ev)
    $game_map.events.delete(ev.id)
    World.next_frame
  end

  # The locator's list.
  def targets
    Loc.instance_variable_get(:@targets)
  end

  # Whether the list is marked to be rebuilt.
  def stale?
    Loc.instance_variable_get(:@targets_stale) ? true : false
  end

  # A running event's end, as the map frames see it: one frame with the interpreter running, the next without.
  def event_ends
    with_event_running { Loc.refresh_on_event_end }
    Loc.refresh_on_event_end
  end

  # Runs the block with the map's interpreter running an event.
  def with_event_running
    i = $game_system.map_interpreter
    was = i.method(:running?)
    i.define_singleton_method(:running?) { true }
    yield
  ensure
    i.define_singleton_method(:running?, was)
  end

  # Runs the block, then settles what the locator keeps between frames and Reset leaves: the interpreter it saw and
  # the stale mark.
  def with_locator_kept
    yield
  ensure
    Loc.refresh_on_event_end
    Loc.instance_variable_set(:@targets_stale, false)
  end
end
