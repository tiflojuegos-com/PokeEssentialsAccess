load File.join(Harness::ROOT, "games/infinitefusion/locked_doors.rb")

class InfiniteFusionLockedDoorsGdTest < PokeAccessTest
  def with_singleton(object, name, body)
    previous = object.singleton_methods.include?(name) ? object.method(name) : nil
    object.define_singleton_method(name, &body)
    yield
  ensure
    previous ? object.define_singleton_method(name, previous) : object.singleton_class.send(:remove_method, name)
  end

  Doors = PokeAccess::InfiniteFusionLockedDoors
  Loc = PokeAccess::Locator

  def setup
    super
    PokeAccess::Config.language = :en
  end

  def door(id = 3, key = ':CAPTAINSKEY')
    locked = TestPage.new(:trigger => 1, :list => [
      TestCmd.new(111, [12, "$PokemonBag.pbQuantity(#{key})>0"]),
      TestCmd.new(101, ['You unlocked the door.'], 1),
      TestCmd.new(123, ['A', 0], 1),
      TestCmd.new(0, [], 1),
      TestCmd.new(411),
      TestCmd.new(101, ['The door is locked. You need a key to open it.'], 1),
      TestCmd.new(0, [], 1), TestCmd.new(412), TestCmd.new(0)
    ])
    open = TestPage.new(:trigger => 1, :condition => {:self_switch_valid => true, :self_switch_ch => 'A'},
                       :list => [TestCmd.new(201, [0, 35, 9, 10, 0, 1]), TestCmd.new(0)])
    TestGameEvent.new(:id => id, :x => 31 + id - 3, :y => 2, :tile_id => 1172, :pages => [locked, open])
  end

  def test_both_locked_halves_are_exits_named_by_their_real_destination
    [3, 4].each do |id|
      event = door(id)
      with_singleton(Loc, :map_name, lambda { |map| map == 35 ? "Captain's Room" : nil }) do
        assert_equal 35, Doors.destination(event)
        assert_equal true, Loc.in_category?(event, :exits)
        assert_equal false, Loc.in_category?(event, :extras)
        assert_equal "Locked door to Captain's Room", Loc.target_name(event)
        assert_equal false, Loc.onto?(event)
        refute event.through
      end
    end
  end

  def test_other_keys_dynamic_expressions_and_unrelated_events_keep_core_behavior
    [':OTHERKEY', 'get_key()', ':CAPTAINSKEY); dangerous('].each do |key|
      event = door(3, key)
      assert_nil Doors.destination(event)
      assert_equal false, Loc.transfer_event?(event)
    end
    assert_nil Doors.destination(World.event(:kind => :npc))
  end

  def test_a_person_with_the_same_key_gate_is_not_reclassified_as_a_door
    event = door
    event.character_name = 'trainer_Sailor'
    assert_nil Doors.destination(event)
    assert_equal false, Loc.transfer_event?(event)
    event.character_name = 'WoodDoor'
    assert_equal 35, Doors.destination(event)
  end

  def test_additional_story_conditions_and_mismatched_switches_are_not_exposed
    [:switch1_valid, :switch2_valid, :variable_valid].each do |flag|
      event = door
      event.instance_variable_get(:@event).pages[1].condition.send("#{flag}=", true)
      assert_nil Doors.destination(event)
    end
    event = door
    event.instance_variable_get(:@event).pages[1].condition.self_switch_ch = 'B'
    assert_nil Doors.destination(event)
  end

  def test_ambiguous_or_variable_transfers_do_not_reveal_a_destination
    event = door
    page = event.instance_variable_get(:@event).pages[1]
    page.list << TestCmd.new(201, [0, 36, 1, 1])
    assert_nil Doors.destination(event)
    page.list = [TestCmd.new(201, [1, 35, 9, 10])]
    assert_nil Doors.destination(event)
  end

  def test_open_door_falls_back_to_the_actual_live_transfer
    event = door
    page = event.instance_variable_get(:@event).pages[1]
    event.instance_variable_set(:@active, page)
    event.instance_variable_set(:@list, page.list)
    assert_nil Doors.destination(event)
    assert_equal true, Loc.transfer_event?(event)
  end

  def test_user_name_wins_over_the_profile_label
    event = door
    with_singleton(PokeAccess::Tags, :get, lambda { |*_args| 'My cabin door' }) do
      assert_equal 'My cabin door', Loc.target_name(event)
    end
  end
end
