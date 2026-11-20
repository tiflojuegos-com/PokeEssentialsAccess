# Infinite Fusion's door to the captain's cabin (games/infinitefusion/locked_doors.rb): a door whose first page opens on
# the Captain's Key and whose second page holds the transfer is an exit, named a locked door to the map it leads to;
# any other key, condition or transfer shape keeps the core's reading.
locked_doors_path = File.join(Harness::ROOT, "games", "infinitefusion", "locked_doors.rb")
eval(Harness.source(locked_doors_path), TOPLEVEL_BINDING, locked_doors_path)

class InfiniteFusionLockedDoorsGdTest < PokeAccessTest
  Doors = PokeAccess::InfiniteFusionLockedDoors
  Loc = PokeAccess::Locator

  def setup
    super
    PokeAccess::Config.language = :en
  end

  test "both halves of the locked door are exits named by the map they lead to" do
    [3, 4].each do |id|
      event = door(id)
      with_singleton(Loc, :map_name, lambda { |map| map == 35 ? "Captain's Room" : nil }) do
        assert_equal [35, true, false, "Locked door to Captain's Room", false],
                     [Doors.destination(event), Loc.in_category?(event, :exits), Loc.in_category?(event, :extras),
                      Loc.target_name(event), Loc.onto?(event)], "event #{id}"
        refute event.through
      end
    end
  end

  test "another key, a key check it cannot read whole, or another event keeps the core's reading" do
    [":OTHERKEY", "get_key()", ":CAPTAINSKEY); dangerous("].each do |key|
      event = door(3, key)
      assert_equal [nil, false], [Doors.destination(event), Loc.transfer_event?(event)], key
    end
    assert_nil Doors.destination(World.event(:kind => :npc))
  end

  test "a person behind the same key check is no door; a door's sprite is" do
    event = door
    event.character_name = "trainer_Sailor"
    assert_equal [nil, false], [Doors.destination(event), Loc.transfer_event?(event)]
    Loc.clear_verdicts
    event.character_name = "WoodDoor"
    assert_equal 35, Doors.destination(event)
  end

  test "a second page with a story condition or another self switch is not taken for the door's" do
    [:switch1_valid, :switch2_valid, :variable_valid].each do |flag|
      event = door
      event.instance_variable_get(:@event).pages[1].condition.send("#{flag}=", true)
      assert_nil Doors.destination(event), flag.to_s
    end
    event = door
    event.instance_variable_get(:@event).pages[1].condition.self_switch_ch = "B"
    assert_nil Doors.destination(event)
  end

  test "a second page with two transfers, or one to a map held in a variable, reveals no map" do
    event = door
    event.instance_variable_get(:@event).pages[1].list << TestCmd.new(201, [0, 36, 1, 1])
    assert_nil Doors.destination(event)
    event = door
    event.instance_variable_get(:@event).pages[1].list = [TestCmd.new(201, [1, 35, 9, 10])]
    assert_nil Doors.destination(event)
  end

  test "the door once open is read by its own transfer" do
    event = door
    page = event.instance_variable_get(:@event).pages[1]
    event.instance_variable_set(:@active, page)
    event.instance_variable_set(:@list, page.list)
    assert_equal [nil, true], [Doors.destination(event), Loc.transfer_event?(event)]
  end

  test "the player's own name for the door wins over its reading" do
    with_singleton(PokeAccess::Tags, :get, lambda { |*_args| "My cabin door" }) do
      assert_equal "My cabin door", Loc.target_name(door)
    end
  end

  private

  # The cabin door as the game builds it: a first page that, with the key, says so and sets self switch A, else says
  # the door is locked; a second page, on that switch, with the transfer to map 35.
  def door(id = 3, key = ":CAPTAINSKEY")
    locked = TestPage.new(:trigger => 1, :list => [
      TestCmd.new(111, [12, "$PokemonBag.pbQuantity(#{key})>0"]),
      TestCmd.new(101, ["You unlocked the door."], 1),
      TestCmd.new(123, ["A", 0], 1),
      TestCmd.new(0, [], 1),
      TestCmd.new(411),
      TestCmd.new(101, ["The door is locked. You need a key to open it."], 1),
      TestCmd.new(0, [], 1), TestCmd.new(412), TestCmd.new(0)
    ])
    open = TestPage.new(:trigger => 1, :condition => { :self_switch_valid => true, :self_switch_ch => "A" },
                        :list => [TestCmd.new(201, [0, 35, 9, 10, 0, 1]), TestCmd.new(0)])
    TestGameEvent.new(:id => id, :x => 31 + id - 3, :y => 2, :tile_id => 1172, :pages => [locked, open])
  end

  # Runs the block with the object's singleton method name answering body, put back after.
  def with_singleton(object, name, body)
    previous = object.singleton_methods.map { |m| m.to_sym }.include?(name) ? object.method(name) : nil
    object.define_singleton_method(name, &body)
    yield
  ensure
    previous ? object.define_singleton_method(name, previous) : object.singleton_class.send(:remove_method, name)
  end
end
