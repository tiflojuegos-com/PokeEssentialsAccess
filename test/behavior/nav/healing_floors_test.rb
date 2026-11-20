# Healing spots (core/nav/healing_floors.rb): an invisible touch page that heals the whole party with nothing else that
# lasts is an object named a healing zone, sounding as one; a route to it ends on it, on the tiles it heals entered
# from, or beside it; a row of them is one target, and a scene that heals on its way is none.
class HealingFloorsTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Scene = PokeAccess::Sound::Scene
  Floors = PokeAccess::HealingFloors
  Planner = PokeAccess::Routes::Planner

  test "a floor that heals stepped on from every side is an object named a healing zone, a route ending on it" do
    ev = floor
    assert_equal [true, PokeAccess::I18n.t(:loc_healing_zone), :objects, true, :object],
                 [Floors.event?(ev), Loc.target_name(ev), Loc.event_category(ev), Loc.onto?(ev), Scene.family_of(ev)]
    assert_includes Loc.candidates(:objects), ev
    assert_includes Loc.candidates(:all), ev
  end

  test "a spot touched from beside that asks first, as a bed or a sofa, heals on yes and is reached beside it" do
    ask = [TestCmd.new(101, ["¿Quieres descansar?"]), TestCmd.new(102, [["Sí", "No"], 2]),
           TestCmd.new(402, [0, "Sí"]), TestCmd.new(314, [0], 1), TestCmd.new(0, [], 1),
           TestCmd.new(402, [1, "No"]), TestCmd.new(0, [], 1), TestCmd.new(404), TestCmd.new(0)]
    ev = floor(:list => ask, :arrival => false)
    assert_equal [true, false, nil], [Floors.event?(ev), Loc.onto?(ev), Floors.entries(ev.x, ev.y)]
  end

  test "a floor that heals entered from one side alone has its route end on the tile it is entered from" do
    one_way = [TestCmd.new(111, [6, -1, 6]), TestCmd.new(101, ["Entered purified, protected zone!"], 1),
               TestCmd.new(314, [0], 1), TestCmd.new(0, [], 1), TestCmd.new(412), TestCmd.new(0)]
    ev = floor(:list => one_way)
    assert_equal [true, false, [[ev.x - 1, ev.y]]], [Floors.event?(ev), Loc.onto?(ev), Floors.entries(ev.x, ev.y)]
    assert_equal [[ev.x - 1, ev.y]], Planner.goal_for(ev.x, ev.y, false).tiles
  end

  test "a scene that heals on its way, or a heal that moves the player elsewhere or fights, is no healing spot" do
    lists = [[TestCmd.new(101, ["Rest now."]), TestCmd.new(314, [0]), TestCmd.new(123, ["A", 0])],
             [TestCmd.new(314, [0]), TestCmd.new(201, [0, 9, 1, 1])],
             [TestCmd.new(314, [0]), TestCmd.new(355, ["pbTrainerBattle(:CAMPER, \"Cam\")"])],
             [TestCmd.new(314, [3])]]
    lists.each_with_index do |list, i|
      World.clear_events
      refute Floors.event?(floor(:list => list)), "list #{i}"
    end
  end

  test "a known healing call standing alone heals; one inside a longer script does not count" do
    assert Floors.event?(floor(:list => [TestCmd.new(355, ["pbHealAll"])]))
    World.clear_events
    refute Floors.event?(floor(:list => [TestCmd.new(355, ["pbHealAll if $game_switches[5]"])]))
  end

  test "someone with a sprite who heals is no healing floor" do
    page = TestPage.new(:trigger => 1, :sprite => "NPC_Nurse", :list => [TestCmd.new(314, [0])])
    ev = TestGameEvent.new(:id => 17, :x => 4, :y => 3, :pages => [page], :active_page => page)
    $game_map.events[17] = ev
    World.next_frame
    refute Floors.event?(ev)
  end

  test "a row of floors running the same page is one object, sounding from its middle tile only" do
    row = (3..7).map { |x| floor(:id => 20 + x, :x => x, :y => 3) }
    assert_equal 1, (Loc.candidates(:objects) & row).length
    assert_equal [nil, nil, :object, nil, nil], row.map { |ev| Scene.family_of(ev) }
  end

  test "a row whose middle tile the player hid sounds from the middle of the rest" do
    row = (3..7).map { |x| floor(:id => 20 + x, :x => x, :y => 3) }
    hidden = row[2]
    original = Loc.method(:tag_hidden?)
    Loc.define_singleton_method(:tag_hidden?) { |ev| ev.equal?(hidden) || original.call(ev) }
    assert_equal [nil, :object, nil, nil], (row - [hidden]).map { |ev| Scene.family_of(ev) }
  ensure
    Loc.define_singleton_method(:tag_hidden?, original) if original
  end

  private

  # An invisible healing floor on (4, 3) unless opts say otherwise, the engine running it on arrival unless :arrival is
  # false: it sets the Pokemon Center and heals everyone.
  def floor(opts = {})
    arrival = opts.key?(:arrival) ? opts.delete(:arrival) : true
    list = [TestCmd.new(355, ["Kernel.pbSetPokemonCenter"]), TestCmd.new(314, [0]), TestCmd.new(0)]
    ev = World.touch({ :id => 17, :x => 4, :y => 3, :list => list }.merge(opts))
    ev.define_singleton_method(:over_trigger?) { arrival }
    World.next_frame
    ev
  end
end
