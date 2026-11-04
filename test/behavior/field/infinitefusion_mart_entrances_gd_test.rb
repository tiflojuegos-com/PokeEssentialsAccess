# Infinite Fusion's shared mart is entered by a Ruby call, not command 201.
# These are the actual call shapes of its city entrances and three interior exits.
class InfinitefusionMartEntrancesGdTest < PokeAccessTest
  Loc = PokeAccess::Locator
  PATH = File.join(Harness::ROOT, "games", "infinitefusion", "mart_entrances.rb")

  def self.load_profile
    return unless File.file?(PATH)
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles) if profiles
  end
  load_profile

  def setup
    super
    @saved_constants = {}
    ["POKEMART_MAP_ID", "POKEMART_DOOR_POS"].each do |name|
      @saved_constants[name] = Object.const_get(name) if Object.const_defined?(name)
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
    Object.const_set("POKEMART_MAP_ID", 357)
    Object.const_set("POKEMART_DOOR_POS", [12, 12])
    Loc.clear_verdicts
  end

  def teardown
    ["POKEMART_MAP_ID", "POKEMART_DOOR_POS"].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
      Object.const_set(name, @saved_constants[name]) if @saved_constants.key?(name)
    end
    Loc.clear_verdicts
    super
  end

  test "the maintained profile module is present" do
    assert File.file?(PATH)
  end

  test "every shared-mart entrance is an exit target and a door cue, independently of the city symbol" do
    %w[PEWTER CERULEAN FUCHSIA VIOLET CRIMSON FUTURE_CITY].each do |city|
      ev = tile("enter_pokemart(:#{city})")
      assert_equal [357, true, true, true, :door],
                   [Loc.transfer_script_dest(ev), Loc.transfer_event?(ev), Loc.in_category?(ev, :exits),
                    Loc.in_category?(ev, :all), PokeAccess::Sound::Scene.family_of(ev)], city
      Loc.clear_verdicts
    end
  end

  test "an entrance uses the game's actual map and landing constants" do
    Object.send(:remove_const, :POKEMART_MAP_ID)
    Object.const_set(:POKEMART_MAP_ID, 901)
    Object.send(:remove_const, :POKEMART_DOOR_POS)
    Object.const_set(:POKEMART_DOOR_POS, [7, 9])
    assert_equal [901, 7, 9], Loc.script_transfer_dest("enter_pokemart(:CERULEAN)")
  end

  test "a call continued on 655 lines is still a mart entrance" do
    list = [TestCmd.new(355, ["enter_pokemart("]), TestCmd.new(655, [" :PEWTER)"])]
    assert_equal 357, Loc.transfer_script_dest(World.touch(:id => 19, :list => list))
  end

  test "an action-button entrance is a door rather than an unnamed shopkeeper" do
    ev = tile("enter_pokemart(:CIANWOOD)", 0)
    assert_equal [true, :door], [Loc.in_category?(ev, :exits), PokeAccess::Sound::Scene.family_of(ev)]
  end

  test "the three anonymous touch exits of the shared interior are visible and named as exits" do
    [1, 8, 26].each do |id|
      ev = tile("exit_pokemart()", 1, id)
      assert_equal [true, true, :door, PokeAccess::I18n.t(:loc_exit)],
                   [Loc.transfer_event?(ev), Loc.in_category?(ev, :exits),
                    PokeAccess::Sound::Scene.family_of(ev), Loc.target_name(ev)]
    end
  end

  test "autorun and parallel mart pages never become navigation targets" do
    [3, 4].each do |trigger|
      ["enter_pokemart(:PEWTER)", "exit_pokemart()"].each do |script|
        assert_equal false, Loc.transfer_event?(tile(script, trigger))
        Loc.clear_verdicts
      end
    end
  end

  test "quoted calls, comments and other shop functions never become mart transfers" do
    ['pbMessage("enter_pokemart(:PEWTER)")', '# enter_pokemart(:PEWTER)',
     '# ignored; enter_pokemart(:PEWTER)', 'pbPokemonMart([:POTION])',
     'other_enter_pokemart(:PEWTER)', 'pbMessage("exit_pokemart()")'].each do |script|
      assert_equal false, Loc.transfer_event?(tile(script)), script
      Loc.clear_verdicts
    end
  end

  test "a game without a valid mart constant keeps its normal transfer handling" do
    Object.send(:remove_const, :POKEMART_MAP_ID)
    Object.const_set(:POKEMART_MAP_ID, "357")
    assert_nil Loc.transfer_script_dest(tile("enter_pokemart(:PEWTER)"))
    Loc.clear_verdicts
    assert_equal false, Loc.transfer_event?(tile("exit_pokemart()"))
    assert_equal [42, 3, 4], Loc.script_transfer_dest("pbTransferPlayer(42,3,4)")
  end

  test "ordinary numeric transfers retain their destinations" do
    assert_equal [81, 6, 11], Loc.transfer_command_dest_xy(
      World.touch(:id => 4, :name => "Door", :list => [TestCmd.new(201, [0, 81, 6, 11])]))
    assert_equal [42, 3, 4], Loc.script_transfer_dest("pbTransferPlayer(42,3,4)")
  end

  test "inactive and erased mart pages never expose their hidden transfer" do
    ["enter_pokemart(:PEWTER)", "exit_pokemart()"].each do |script|
      inactive = TestPage.new(:trigger => 1, :list => [TestCmd.new(355, [script])])
      active = TestPage.new(:trigger => 1, :list => [])
      [false, true].each do |erased|
        ev = TestGameEvent.new(:id => 44, :name => "EV044", :pages => [inactive, active], :active_page => active)
        ev.instance_variable_set(:@page, nil) if erased
        assert_equal false, Loc.transfer_event?(ev)
        Loc.clear_verdicts
      end
    end
  end

  test "a character calling the exit function stays a person rather than a doorway" do
    ev = World.touch(:id => 44, :name => "Clerk", :sprite => "NPC 07", :trigger => 0,
                     :list => [TestCmd.new(355, ["exit_pokemart()"])])
    assert_equal false, Loc.transfer_event?(ev)
  end

  test "missing or invalid landing coordinates never invent a tile" do
    Object.send(:remove_const, :POKEMART_DOOR_POS)
    assert_equal [357, nil, nil], Loc.script_transfer_dest("enter_pokemart(:PEWTER)")
    Object.const_set(:POKEMART_DOOR_POS, [-1, 9])
    assert_equal [357, nil, nil], Loc.script_transfer_dest("enter_pokemart(:PEWTER)")
  end

  test "the confirmed malformed Cianwood return is repaired only inside the shared mart" do
    temp = Struct.new(:player_new_map_id, :player_new_x, :player_new_y).new(709.8, 46, nil)
    PokeAccess::IFMartEntrances.repair_return(temp, 357)
    assert_equal [709, 8, 46], [temp.player_new_map_id, temp.player_new_x, temp.player_new_y]
  end

  test "valid returns and unrelated incomplete transfers keep their exact values" do
    [[357, 709, 8, 46], [357, 709.8, 46, 0], [357, 710.8, 46, nil],
     [99, 709.8, 46, nil], [357, 1, 24, 22]].each do |values|
      map, mid, x, y = values
      temp = Struct.new(:player_new_map_id, :player_new_x, :player_new_y).new(mid, x, y)
      PokeAccess::IFMartEntrances.repair_return(temp, map)
      assert_equal [mid, x, y], [temp.player_new_map_id, temp.player_new_x, temp.player_new_y]
    end
  end

  private

  def tile(script, trigger = 1, id = 18)
    World.touch(:id => id, :name => "EV%03d" % id, :trigger => trigger,
                :list => [TestCmd.new(355, [script])])
  end
end
