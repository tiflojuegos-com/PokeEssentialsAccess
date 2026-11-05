# The doors of Infinite Fusion's shared buildings (games/infinitefusion_common/shared_buildings.rb), gamedata pass: each
# only calls a script, and is listed as a door to what the game's own constants and tables name, or, for the way out,
# as an exit to somewhere only the game knows.
if_shared_buildings = File.join(Harness::ROOT, "games", "infinitefusion_common", "shared_buildings.rb")
eval(Harness.source(if_shared_buildings), TOPLEVEL_BINDING, if_shared_buildings)

class IfSharedBuildingsGdTest < PokeAccessTest
  Loc = PokeAccess::Locator
  OUTDOORS = 901
  MART = 357
  CENTER = 25
  # What each game defines, as its scripts define it.
  KANTO = { :POKEMART_MAP_ID => MART, :POKEMART_DOOR_POS => [12, 12],
            :COMMON_MAPS_KANTO => { :POKEMART => { :id => MART, :position => [12, 12] } } }.freeze
  HOENN = { :POKEMART_MAP_ID => 24, :POKEMART_DOOR_POS => [9, 10],
            :COMMON_MAPS_HOENN => { :POKEMART => { :id => 24, :position => [9, 10] },
                                    :POKEMON_CENTER => { :id => CENTER, :position => [10, 10] },
                                    :CLOTHING_STORE => { :id => 94, :position => [11, 11] },
                                    :CONTEST_HALL => { :id => 110, :position => [11, 37] } } }.freeze

  def setup
    super
    $game_map.map_id = OUTDOORS
    Loc.clear_verdicts
  end

  test "a mart door of Kanto leads where the game's constants say, as an entrance from a town" do
    with_game(KANTO) do
      ev = door("enter_pokemart(:PEWTER)")
      assert_equal [MART, 12, 12], Loc.script_transfer_dest("enter_pokemart(:PEWTER)")
      assert_equal [MART, true, true, :door], door_state(ev)
      assert_equal PokeAccess::I18n.t(:loc_entrance_to, :map => "PokeMart"), in_town { Loc.target_name(ev) }
    end
  end

  test "any town's symbol works, with no list of towns" do
    with_game(KANTO) do
      [:CERULEAN, :CIANWOOD, :SOME_TOWN_TO_COME].each do |town|
        assert_equal MART, Loc.script_transfer_map("enter_pokemart(:#{town})"), town
      end
    end
  end

  test "a building of Hoenn leads where the game's table says, the call read whole over its lines" do
    with_game(HOENN, true) do
      { "enter_common_building(:POKEMART, :SLATEPORT)" => [24, 9, 10],
        "enter_common_building(:CONTEST_HALL, :SLATEPORT)" => [110, 11, 37],
        "enter_pokemon_center(:OLDALE)" => [CENTER, 10, 10] }.each do |call, dest|
        assert_equal dest, Loc.script_transfer_dest(call), call
      end
      shop = World.touch(:id => 41, :x => 4, :y => 4, :name => "Door",
                         :list => [TestCmd.new(355, ["enter_common_building("]), TestCmd.new(655, [":CLOTHING_STORE,"]),
                                   TestCmd.new(655, [":RUSTBORO"]), TestCmd.new(655, [")"])])
      assert_equal 94, Loc.transfer_script_dest(shop)
    end
  end

  test "a building a future Kanto calls the same way reads Kanto's table" do
    with_game(KANTO) do
      assert_equal [MART, 12, 12], Loc.script_transfer_dest("enter_common_building(:POKEMART, :PEWTER)")
    end
  end

  test "the way out of a building is a door with no named map, said as an exit, and a route ends on it" do
    with_game(HOENN, true) do
      ["exit_common_building()", "exit_pokemon_center", "exit_pokemart()"].each_with_index do |call, i|
        ev = door(call, 50 + i)
        assert_equal [nil, true, true, :door], door_state(ev), call
        assert_equal PokeAccess::I18n.t(:loc_exit), Loc.target_name(ev), call
        effect = PokeAccess::Routes::Effects.touch_effect_of(PokeAccess::EventPages.outcome(ev, 2), 2, nil, OUTDOORS)
        assert_equal [:exit], effect, call
      end
    end
  end

  test "a door the game's constants no longer name is still a door, said as an exit" do
    with_game({}) do
      ev = door("enter_pokemart(:PEWTER)")
      assert_equal [nil, true, true, :door], door_state(ev)
      assert_equal PokeAccess::I18n.t(:loc_exit), Loc.target_name(ev)
      assert_equal [nil, nil, nil], Loc.script_transfer_dest("enter_common_building(:GYM, :PEWTER)")
    end
  end

  test "a door on the action button, as Cianwood's, is a door too" do
    with_game(KANTO) do
      assert_equal [MART, true, true, :door], door_state(door("enter_pokemart(:CIANWOOD)", 60, 0))
    end
  end

  test "only a call that starts a line is a door, never one a word or a text mentions" do
    with_game(KANTO) do
      ["pbMessage(\"enter_pokemart(:X)\")", "my_enter_pokemart(:X)", "x = :exit_pokemart", "exit_pokemartish"].each do |s|
        assert_nil Loc.script_transfer_dest(s), s
      end
    end
  end

  test "an autorun or parallel page is no door" do
    with_game(KANTO) do
      assert_equal false, Loc.transfer_event?(door("enter_pokemart(:PEWTER)", 70, 3))
      assert_equal false, Loc.transfer_event?(door("enter_pokemart(:PEWTER)", 71, 4))
    end
  end

  private

  # A sprite-less event on the map whose live page runs one script call.
  def door(call, id = 40, trigger = 1)
    World.touch(:id => id, :x => 4, :y => 4, :trigger => trigger, :list => [TestCmd.new(355, [call])])
  end

  # What the locator and the soundscape make of a door: its map, whether it is a door, among the exits, and its family.
  def door_state(ev)
    [Loc.transfer_script_dest(ev), Loc.transfer_event?(ev), Loc.in_category?(ev, :exits),
     PokeAccess::Sound::Scene.family_of(ev)]
  end

  # The block's value on an outdoor map, with the shared mart named.
  def in_town
    was = PokeAccess::MapNames.get(MART)
    PokeAccess::MapNames.set(MART, "PokeMart")
    md = GameData::MapMetadata
    real = md.singleton_class.instance_method(:try_get)
    row = Struct.new(:outdoor_map)
    md.define_singleton_method(:try_get) { |mid| row.new(mid == OUTDOORS) }
    yield
  ensure
    md.singleton_class.send(:define_method, :try_get, real)
    was ? PokeAccess::MapNames.set(MART, was) : PokeAccess::MapNames.delete(MART)
  end

  # Runs the block with a game's constants defined and, for Hoenn, its Settings::HOENN set.
  def with_game(constants, hoenn = false)
    constants.each { |k, v| Object.const_set(k, v) }
    Settings.const_set(:HOENN, true) if hoenn
    Loc.clear_verdicts
    yield
  ensure
    constants.each_key { |k| Object.send(:remove_const, k) }
    Settings.send(:remove_const, :HOENN) if hoenn
    Loc.clear_verdicts
  end
end
