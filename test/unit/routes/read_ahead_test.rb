# What walks and searches look up at each step is read before events are lent through (Effects.read_ahead,
# Probe.before_lending): nothing read meanwhile is kept, so each look-up would read every event's page afresh.
class ReadAheadTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  Probe = PokeAccess::World::Probe
  Regions = PokeAccess::Routes::Regions
  Pushes = PokeAccess::Routes::Pushes
  ROOM = ["#########", "#@......#", "#.......#", "#########"].freeze

  test "reads each event's obstacle once however many look-ups a lent walk makes" do
    on_room do
      ev = person(30, 3, 2)
      PokeAccess::World::Events.sync(true)
      reads = counting(Effects, :gate_facet) { Probe.lend_through([ev]) { 5.times { Effects.gate_at(4, 1) } } }
      assert_operator reads[30], :<=, 1
    end
  end

  test "reads its touches and whether the map has warps and ramps the same way" do
    on_room do
      ev = person(30, 3, 2)
      PokeAccess::World::Events.sync(true)
      reads = counting(Effects, :touch_facet) do
        Probe.lend_through([ev]) do
          5.times do
            Effects.touch_at(4, 1, 2, true)
            Effects.warp_map?
            Effects.ramp_map?
          end
        end
      end
      assert_operator reads[30], :<=, 1
    end
  end

  test "reads nothing ahead for a walk that lends nobody, nor again for one lent inside another" do
    on_room do
      ev = person(30, 3, 2)
      PokeAccess::World::Events.sync(true)
      calls = 0
      counter = lambda { |*_a| calls += 1 }
      spying(Effects, :read_ahead, counter) do
        Probe.lend_through([]) { nil }
        assert_equal 0, calls, "no one lent"
        Probe.lend_through([ev]) { Probe.lend_through([ev]) { nil } }
        assert_equal 1, calls, "the outer one only"
      end
    end
  end

  test "reads the action events once in an assisted walk with someone lent" do
    on_room do
      person(30, 6, 2, 1)
      climb(31, 3, 1)
      PokeAccess::World::Events.sync(true)
      PokeAccess::Pathfinder.invalidate_cache(true)
      reads = counting(Effects, :act_facet) { Regions.assisted.status([[7, 2]]) }
      assert_operator reads[31], :<=, 1
    end
  end

  test "reads the action events once in a search that moves a boulder" do
    on_room do
      boulder = TestPage.new(:trigger => 0, :sprite => "boulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"]), TestCmd.new(0, [])])
      rock = TestGameEvent.new(:id => 32, :x => 2, :y => 2, :name => "Boulder", :pages => [boulder])
      rock.blocking = true
      $game_map.events[32] = rock
      climb(31, 3, 1)
      PokeAccess::World::Events.sync(true)
      PokeAccess::Pathfinder.invalidate_cache(true)
      reads = counting(Effects, :act_facet) { Pushes.route(PokeAccess::Routes::Goal.onto(7, 2)) }
      assert_operator reads[31], :<=, 1
    end
  end

  private

  def on_room
    $game_map.load_grid(ROOM)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # A person of id on (x, y) who walks about by themselves if move_type is given.
  def person(id, x, y, move_type = 0)
    page = TestPage.new(:trigger => 0, :sprite => "npc", :move_type => move_type, :list => [TestCmd.new(101, ["Hello"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page])
    ev.blocking = true
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # An action event on (x, y) that carries the player two tiles right, through whatever is there.
  def climb(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "ladder", :list => [World.move_player([37, 3, 3, 38]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Climb", :pages => [page])
  end

  # How many times the block made mod's name read each event's record, by event id.
  def counting(mod, name)
    reads = Hash.new(0)
    spying(mod, name, lambda { |r, *_a| reads[r.id] += 1 }) { yield }
    reads
  end

  def spying(mod, name, spy)
    orig = mod.method(name)
    meta = class << mod; self; end
    meta.send(:define_method, name) do |*args, &blk|
      spy.call(*args)
      orig.call(*args, &blk)
    end
    yield
  ensure
    meta.send(:define_method, name, orig)
  end
end
