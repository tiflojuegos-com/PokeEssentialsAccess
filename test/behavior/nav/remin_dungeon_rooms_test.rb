# Reminiscencia's dungeon rooms (dungeon_rooms.rb): their exits are the borders whose room the game set, but the one
# the party came in by, and only on the maps the game runs as dungeons.
class ReminDungeonRoomsTest < PokeAccessTest
  Loc = PokeAccess::Locator
  PATH = File.join(Harness::ROOT, "games", "reminiscencia", "dungeon_rooms.rb")
  Global = Struct.new(:leftMap, :rightMap, :topMap, :bottomMap, :lastDir)
  ROOM = ["####.####", "#.......#", "#.......#", "..@......", "#.......#", "#.......#", "####.####"]

  test "a room lists the sides the game set, less the way back and the sides set to -1" do
    with_room(Global.new(7, 7, -1, 7, 6), [7]) do
      assert_equal [[7, 3, -3, t(:loc_exit_out, :out => t(:loc_out_right))],
                    [4, 5, -2, t(:loc_exit_out, :out => t(:loc_out_down))]],
                   Loc.connection_targets.map { |e| [e.x, e.y, e.ref, Loc.target_name(e)] }
    end
  end

  test "the first room, come in by no side, lists every side the game set" do
    with_room(Global.new(7, 7, 7, 7, 0), [7]) do
      assert_equal [-4, -3, -2, -1], Loc.connection_targets.map { |e| e.ref }
    end
  end

  test "each side's way back is the one the party came in moving away from" do
    { 4 => -3, 6 => -1, 2 => -4, 8 => -2 }.each do |last, gone|
      with_room(Global.new(7, 7, 7, 7, last), [7]) do
        assert_equal [-4, -3, -2, -1] - [gone], Loc.connection_targets.map { |e| e.ref }, "came in moving #{last}"
      end
    end
  end

  test "a map the game does not run as a dungeon lists no border exit" do
    with_room(Global.new(7, 7, 7, 7, 0), [84]) do
      assert_equal [], Loc.connection_targets
    end
  end

  private

  # A text of the mod's.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block on ROOM as map 7 with the profile's declaration loaded, the game's room state global and its
  # dungeon list dungeons, all taken back after with the profiles the declaration registers.
  def with_room(global, dungeons)
    saved = Loc::SCRIPT_EDGES.dup
    profiles = PokeAccess::Game.profiles.dup
    Loc::SCRIPT_EDGES.clear
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    was_global = $PokemonGlobal
    was_dungeons = $dungeon_maps
    was_id = $game_map.map_id
    $PokemonGlobal = global
    $dungeon_maps = dungeons
    $game_map.load_grid(ROOM)
    $game_map.map_id = 7
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    $game_map.map_id = was_id
    $PokemonGlobal = was_global
    $dungeon_maps = was_dungeons
    Loc::SCRIPT_EDGES.replace(saved)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
