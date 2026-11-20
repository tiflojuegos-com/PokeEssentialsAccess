# Routes and the Lens of Truth (World::Lens): the marked events read as each copy marks them, the routes taking the lens in
# use as reaching every event they pass, and with the puzzle assist the lens used to cross a HIDE event or meet a SHOW one.
class LensRoutesTest < PokeAccessTest
  include RouteHelpers
  Lens = PokeAccess::World::Lens
  Planner = PokeAccess::Routes::Planner
  Text = PokeAccess::Routes::Text
  Probe = PokeAccess::World::Probe

  def setup
    super
    @scene_was = $scene
    @frames = 0
    @flag = nil
    copy(3)
  end

  def teardown
    $scene = @scene_was
    Lens.declare(nil)
    Object.send(:remove_const, :LensOfTruth) if Object.const_defined?(:LensOfTruth)
    super
  end

  # The script's module with its range, as every copy defines it; with active, Vitro's state too.
  def copy(range, active = nil)
    Object.send(:remove_const, :LensOfTruth) if Object.const_defined?(:LensOfTruth)
    m = Module.new
    m.const_set(:RANGE, range)
    if active
      m.instance_variable_set(:@on, false)
      def m.active?; @on; end
      def m.on=(v); @on = v; end
    end
    Object.const_set(:LensOfTruth, m)
    timer_scene unless active
  end

  # Z's scene: the lens on while frames are left.
  def timer_scene
    test = self
    s = Scene_Map.new
    s.define_singleton_method(:eye_of_truth_time) { test.instance_variable_get(:@frames) }
    $scene = s
  end

  # Edas' and Perseida's scene: the lens on while its flag is up.
  def flag_scene
    test = self
    s = Scene_Map.new
    s.define_singleton_method(:eye_of_truth) { test.instance_variable_get(:@flag) }
    $scene = s
  end

  # A marked event on (x,y), as the game leaves it away from the player: a HIDE one in the way, a SHOW one passed over.
  def marked(id, name, x, y)
    ev = World.touch(:id => id, :name => name, :x => x, :y => y, :trigger => 0, :sprite => "wall")
    ev.blocking = true
    ev.through = name !~ /HIDE/
    PokeAccess::Pathfinder.invalidate_cache(true)
    ev
  end

  # Runs the block with n of every item in the bag.
  def with_bag(n)
    bag = Object.new
    bag.instance_variable_set(:@n, n)
    def bag.pbQuantity(_item); @n; end
    was = $PokemonBag
    $PokemonBag = bag
    yield
  ensure
    $PokemonBag = was
  end

  def corridor(rows = ['#######', '#@....#', '#######'])
    $game_map.load_grid(rows)
  end

  test "reads what each copy marks: HIDE or SHOW in the name, else a comment; #EOT in Z's, EOT in the others" do
    flag_scene
    names = { "#EOT HIDE" => :hide, "#EOTSHOW item" => :show, "EOT HIDE/noShadow" => :hide, "EV010" => nil,
              "#EOT Puerta" => nil, "PIDGEOT" => nil }
    names.each { |n, want| assert_equal want.inspect, Lens.kind(World.event(:name => n, :id => 7)).inspect, n }
    door = World.touch(:id => 8, :name => "#EOT Puerta", :trigger => 1, :list => [TestCmd.new(108, ["showEvent"])])
    assert_nil Lens.kind(door), "Edas' copy reads no comments"
    Lens.declare(:comments => true)
    assert_equal :show, Lens.kind(door), "Perseida's doors: the comment marks them"
    hid = World.touch(:id => 9, :name => "#EOT SHOW", :list => [TestCmd.new(108, ["note"]), TestCmd.new(408, ["hideEvent"])])
    loose = World.touch(:id => 10, :name => "#EOT", :list => [TestCmd.new(108, ["showEvent please"])])
    assert_equal [:hide, nil], [Lens.kind(hid), Lens.kind(loose)], "HIDE first, a continuation line too, the text exact"
    timer_scene
    assert_nil Lens.kind(World.event(:name => "EOT HIDE/noShadow", :id => 11)), "Z's copy wants the hash"
    Object.send(:remove_const, :LensOfTruth)
    assert_equal [nil, :hide], [Lens.kind(World.event(:name => "EOT HIDE", :id => 12)),
                                Lens.kind(World.event(:name => "#EOT HIDE", :id => 13))], "a game without the script"
  end

  test "is in use by each copy's own state, and reaches what lies within its range of the player" do
    assert_equal [false, true], [Lens.on?, Lens.timed?]
    @frames = 40
    assert_equal true, Lens.on?, "Z's timer counting down"
    flag_scene
    @flag = true
    assert_equal [true, false], [Lens.on?, Lens.timed?], "the flag up"
    copy(4, true)
    assert_equal false, Lens.on?
    LensOfTruth.on = true
    assert_equal [true, 4, :DOWSINGMACHINE], [Lens.on?, Lens.range, Lens.item], "Vitro's, worked by the Dowsing Machine"
    $game_player.x = 1
    $game_player.y = 1
    near = World.event(:name => "#EOT SHOW", :id => 7, :x => 3, :y => 4)
    far = World.event(:name => "#EOT SHOW", :id => 8, :x => 5, :y => 4)
    assert_equal [true, false], [Lens.reaches?(near), Lens.reaches?(far)]
  end

  test "with the lens down a HIDE event shuts the way, and in use the route crosses it wherever it lies" do
    corridor
    wall = marked(5, "#EOT HIDE", 3, 1)
    assert_nil walk_route(5, 1), "the lens down"
    assert_equal :none, Planner.plan(5, 1).kind
    @frames = 400
    assert_equal [6, 6, 6], walk_route(5, 1), "the lens in use opens it, out of its reach now"
    assert_equal :walk, Planner.plan(5, 1).kind, "the plan kept with the lens down is not taken"
    assert_equal false, wall.through, "the game's flag is left as it was"
  end

  test "a SHOW event stops a route with the lens in use and is passed over without it" do
    corridor
    marked(5, "#EOT SHOW", 3, 1)
    assert_equal [6, 6, 6], walk_route(5, 1)
    @frames = 400
    assert_nil walk_route(5, 1)
    assert_equal true, Probe.step?(2, 1, 4), "a step away from it is the game's"
  end

  test "with the assist and the lens down, the route stops before a HIDE event to use the lens there" do
    corridor
    wall = marked(5, "#EOT HIDE", 3, 1)
    PokeAccess::Config.puzzle_assist = true
    gate = { :kind => :lens, :label => :loc_lens, :ev => wall, :x => 3, :y => 1, :after => 2 }
    assert_equal [[6], gate], Planner.assisted(5, 1)
    plan = Planner.plan(5, 1)
    assert_equal [:assisted, [6]], [plan.kind, plan.route]
    name = Lens.item_name
    with_bag(1) do
      assert_equal PokeAccess::I18n.t(:loc_lens_here, :item => name), Text.hold(plan.gate, 2, 1)
      assert_equal PokeAccess::I18n.t(:loc_lens_route, :item => name), Text.gate_route(plan.gate)
    end
    assert_equal false, wall.through
  end

  test "a row of HIDE events takes the lens once, and without the assist nothing is offered" do
    corridor(['########', '#@.....#', '########'])
    marked(5, "#EOT HIDE", 3, 1)
    marked(6, "#EOT HIDE", 4, 1)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [nil, true], [Lens.gate_at(4, 1, 6), !Lens.gate_at(3, 1, 6).nil?], "into the second, from the first"
    assert_equal [6], Planner.assisted(6, 1)[0]
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_nil Planner.assisted(6, 1)
    assert_equal :none, Planner.plan(6, 1).kind
  end

  test "names the need of the lens where its item is not in the bag" do
    corridor
    marked(5, "#EOT HIDE", 3, 1)
    PokeAccess::Config.puzzle_assist = true
    gate = Planner.assisted(5, 1)[1]
    with_bag(0) do
      assert_equal PokeAccess::I18n.t(:loc_lens_need_here, :item => Lens.item_name), Text.hold(gate, 2, 1)
      assert_equal PokeAccess::I18n.t(:loc_lens_route_need, :item => Lens.item_name), Text.gate_route(gate)
    end
  end

  test "names a lens no item works as the profile declares it, and tells when the player cannot use it" do
    corridor
    marked(5, "#EOT HIDE", 3, 1)
    PokeAccess::Config.puzzle_assist = true
    gate = Planner.assisted(5, 1)[1]
    able = nil
    Lens.declare(:name => :loc_lens, :usable => lambda { able })
    name = PokeAccess::I18n.t(:loc_lens)
    assert_equal [nil, name, nil], [Lens.item, Lens.item_name, Lens.usable?]
    able = false
    assert_equal PokeAccess::I18n.t(:loc_lens_need_here, :item => name), Text.hold(gate, 2, 1)
    able = true
    assert_equal PokeAccess::I18n.t(:loc_lens_here, :item => name), Text.hold(gate, 2, 1)
  end

  test "crosses a SHOW event before the HIDE one as the lens down leaves it, and uses the lens at the HIDE" do
    corridor
    marked(5, "#EOT SHOW", 3, 1)
    wall = marked(6, "#EOT HIDE", 4, 1)
    PokeAccess::Config.puzzle_assist = true
    got = Planner.assisted(5, 1)
    assert_equal [[6, 6], :lens, wall], [got[0], got[1][:kind], got[1][:ev]], "a SHOW one beside it is no row"
  end

  test "lends a SHOW event solid only where it lays the only ground" do
    corridor(['#######', '#@.~..#', '#######'])
    bridge = marked(5, "#EOT SHOW", 3, 1)
    floor = marked(6, "#EOT SHOW", 4, 1)
    wall = marked(7, "#EOT HIDE", 5, 1)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[bridge, false], [wall, true]], Lens.lent.sort_by { |ev, _t| ev.id }
    assert_equal [true, false, true], [bridge.through, false, floor.through], "the game's flags as they were"
    Lens.forget
    $PokemonGlobal.surfing = true
    assert_equal [true, false], [Lens.bridge?(bridge), Lens.bridge?(floor)], "water is no ground on foot, afloat too"
  ensure
    $PokemonGlobal.surfing = false if $PokemonGlobal
  end

  test "poses an event on both tiles of a step once, and a landing with no way on its own tile" do
    corridor
    wide = marked(5, "#EOT HIDE size(2,1)", 3, 1)
    sign = marked(6, "#EOT SHOW", 5, 1)
    @frames = 400
    inside = Lens.posed(3, 1, 6, nil) { wide.through }
    landing = Lens.posed(5, 1, 0, nil) { sign.through }
    assert_equal [true, false, false, true], [inside, wide.through, landing, sign.through]
  end

  test "uses Z's lens again where its time runs out before the HIDE event" do
    corridor
    wall = marked(5, "#EOT HIDE", 3, 1)
    @frames = 400
    assert_equal :walk, Planner.plan(5, 1).kind, "a fresh lens reaches it"
    @frames = Lens::FRAMES_PER_TILE
    plan = Planner.plan(5, 1)
    assert_equal [:assisted, [6], :lens, wall], [plan.kind, plan.route, plan.gate[:kind], plan.gate[:ev]],
                 "the plan kept with more time left is not taken"
  end

  test "keeps a plan while Z's lens lasts as far as its HIDE event, searching again only once it does not" do
    corridor
    marked(5, "#EOT HIDE", 3, 1)
    made = 0
    orig = Planner.method(:make)
    Planner.define_singleton_method(:make) { |*a| made += 1; orig.call(*a) }
    kinds = [400, 200, 9, 8].map do |left|
      @frames = left
      Planner.plan(5, 1).kind
    end
    assert_equal [[:walk, :walk, :walk, :assisted], 2], [kinds, made], "the player standing still"
  ensure
    Planner.define_singleton_method(:make, orig)
  end

  test "uses Vitro's lens again past an event that runs, which puts it down" do
    copy(3, true)
    LensOfTruth.const_set(:AUTO_DEACTIVATE_ON_EVENTS, true)
    LensOfTruth.on = true
    corridor(['########', '#@.....#', '########'])
    World.touch(:id => 4, :name => "aviso", :x => 2, :y => 1, :trigger => 1, :list => [TestCmd.new(101, ["Hi"])])
    wall = marked(5, "#EOT HIDE", 4, 1)
    plan = Planner.plan(6, 1)
    assert_equal [:assisted, [6, 6], wall], [plan.kind, plan.route, plan.gate[:ev]]
  end

  test "names the lens by the core's word where the game has no item for it" do
    data = PokeAccess::Data
    was = data.method(:item_id)
    data.define_singleton_method(:item_id) { |sym| sym == :LENSOFTRUTH ? [nil, nil] : was.call(sym) }
    flag_scene
    gate = { :kind => :lens, :label => :loc_lens, :x => 3, :y => 1 }
    assert_equal [nil, nil, PokeAccess::I18n.t(:lens_name)], [Lens.item, Lens.usable?, Lens.item_name]
    assert_equal PokeAccess::I18n.t(:loc_lens_here, :item => PokeAccess::I18n.t(:lens_name)), Text.hold(gate, 2, 1)
  ensure
    data.define_singleton_method(:item_id, was)
  end

  test "with the assist and the lens down, a route to a SHOW event ends beside it, the lens to use there" do
    corridor
    sign = marked(5, "#EOT SHOW", 4, 1)
    PokeAccess::Config.puzzle_assist = true
    plan = Planner.plan(4, 1)
    assert_equal [:assisted, [6, 6], :lens, true, sign], [plan.kind, plan.route, plan.gate[:kind], plan.gate[:show], plan.gate[:ev]]
    @frames = 400
    assert_equal :walk, Planner.plan(4, 1).kind, "the lens in use: it is walked to"
  end

  test "keeps the routes of a game without the script as they were" do
    Object.send(:remove_const, :LensOfTruth)
    corridor
    marked(5, "#EOT HIDE", 3, 1)
    PokeAccess::Config.puzzle_assist = true
    @frames = 400
    assert_equal [nil, nil, false], [walk_route(5, 1), Planner.assisted(5, 1), Lens.assisting?]
  end
end
