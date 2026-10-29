# Dark Horizon on the map (games/darkhorizon/gallops.rb, phantom_path.rb, constants.rb): each crossing cutscene said
# briefly as it starts; the Phantom Path said as the presses that walk it as it lights up, and the presses left on the
# info key on its map; the trainer line naming the Colosseum Points where the badges would go.

# The crossings: pbStartScene runs the whole cutscene; the bike's second argument is whether someone rides along.
class Seagallop_Scene
  def pbStartScene(_mirror); :crossed; end
end

class Bikegallop_Scene
  def pbStartScene(_mirror, _duo); :crossed; end
end

class SubmarineGallop_Scene
  def pbStartScene(_mirror); :crossed; end
end

# The puzzle as the map's events keep it: its tiles in walking order, the map it is on, and its two showings.
class PhantomPath
  PHANTOM_PATHS = [[112, 215, 30]]

  def initialize(tiles); @path_tiles = tiles; end

  def getPathTiles; @path_tiles; end

  def pbShowPathRoute; :shown; end

  def pbShowPathRouteDone; :lit; end
end

%w[gallops phantom_path].each do |name|
  path = File.join(Harness::ROOT, "games", "darkhorizon", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class DarkhorizonFieldGdTest < PokeAccessTest
  # The start of the game's first path: two up from the entrance, then up, right twice, up, with the tile it lists
  # twice.
  TILES = [[9, 15], [9, 14], [10, 14], [11, 14], [11, 14], [11, 13]].freeze
  # The player's place, the map and the game variable the puzzle is kept in.
  PUZZLE_MAP = 112
  PUZZLE_VARIABLE = 90

  # The player of the GameData era, as the trainer line reads it.
  Player = Struct.new(:name, :money, :badges, :pokedex, :battle_points)

  test "each crossing is said briefly as it starts, queued" do
    Seagallop_Scene.new.pbStartScene(false)
    SubmarineGallop_Scene.new.pbStartScene(true)
    Bikegallop_Scene.new.pbStartScene(false, false)
    Bikegallop_Scene.new.pbStartScene(true, true)
    assert_equal [[t(:dh_gallop_sea), false], [t(:dh_gallop_sub), false], [t(:dh_gallop_bike), false],
                  [t(:dh_gallop_bike_duo), false]], SpeakCapture.log
  end

  test "the crossings keep their own returns" do
    assert_equal [:crossed] * 3, [Seagallop_Scene.new.pbStartScene(false), Bikegallop_Scene.new.pbStartScene(false, true),
                                  SubmarineGallop_Scene.new.pbStartScene(false)]
  end

  test "as the path lights up, says the presses that walk it from where the player stands, queued" do
    stand_at(9, 17)
    assert_equal :shown, PhantomPath.new(TILES).pbShowPathRoute
    assert_equal [[t(:dh_phantom_shown, :route => route([3, 8], [2, 6], [1, 8])), false]], SpeakCapture.log
  end

  test "the path kept lit on a later visit is said the same way" do
    stand_at(9, 16)
    PhantomPath.new(TILES).pbShowPathRouteDone
    assert_equal [[t(:dh_phantom_shown, :route => route([2, 8], [2, 6], [1, 8])), false]], SpeakCapture.log
  end

  test "on its map the info key says the presses left from the path tile the player stands on" do
    on_puzzle(TILES) do
      stand_at(10, 14)
      assert_equal t(:dh_phantom_left, :route => route([1, 6], [1, 8])), PokeAccess::Info.map_text
    end
  end

  test "on the path's last tile the info key says it is the end" do
    on_puzzle(TILES) do
      stand_at(11, 13)
      assert_equal t(:dh_phantom_end), PokeAccess::DHPhantomPath.info
    end
  end

  test "off its map, or with no puzzle kept, the info key leaves the path out" do
    on_puzzle(TILES) do
      $game_map.map_id = PUZZLE_MAP + 1
      assert_nil PokeAccess::DHPhantomPath.info
    end
    $game_map.map_id = PUZZLE_MAP
    assert_nil PokeAccess::DHPhantomPath.info
  end

  test "the trainer line says the Colosseum Points where the badges would go" do
    with_parts do
      constants = File.join(Harness::ROOT, "games", "darkhorizon", "constants.rb")
      eval(Harness.source(constants), TOPLEVEL_BINDING, constants)
      assert_equal [:name, :money, :cp, :pokedex, :playtime], PokeAccess::Config.trainer_parts
      assert_equal t(:dh_tr_cp, :n => 7), PokeAccess::Info.trainer_part(:cp, Player.new("Wes", 100, [], nil, 7))
      assert_nil PokeAccess::Info.trainer_part(:cp, Struct.new(:name).new("Wes"))
    end
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The legs as the route says them, each [presses, direction].
  def route(*legs)
    legs.map { |n, d| PokeAccess::Routes::Text.leg(d, n) }.join(", ")
  end

  def stand_at(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # Runs the block on the puzzle's map with the puzzle kept in its game variable.
  def on_puzzle(tiles)
    $game_map.map_id = PUZZLE_MAP
    $game_variables[PUZZLE_VARIABLE] = PhantomPath.new(tiles)
    yield
  ensure
    $game_variables.delete(PUZZLE_VARIABLE)
  end

  # Runs the block with the trainer line's parts and their order put back after.
  def with_parts
    saved = [PokeAccess::Config.trainer_parts.dup, PokeAccess::Info::TRAINER_PARTS.dup]
    yield
  ensure
    PokeAccess::Config.trainer_parts = saved[0]
    PokeAccess::Info::TRAINER_PARTS.replace(saved[1])
  end
end
