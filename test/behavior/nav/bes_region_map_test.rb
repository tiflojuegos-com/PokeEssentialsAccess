# Essentials BES's region map (plugins/bes_region_map.rb): the icon it draws for each roaming Pokemon, which comes with
# no text, is said with its place as the map opens and on its square; another engine's roaming sprites are left alone.
class BesRegionMapTest < PokeAccessTest
  T = PokeAccess::I18n
  RM = PokeAccess::RegionMap
  Pic = Struct.new(:width, :height)
  Sprite = Struct.new(:bitmap)
  Icon = Struct.new(:x, :y, :bitmap) do
    def initialize(x, y, bitmap = :picture); super; end
  end
  MAP_LEFT = (Graphics.width - 256) / 2
  MAP_TOP = (Graphics.height - 192) / 2

  # The fork's scene: the stock one, with the method that draws the roamers. Asking it for a place goes through the
  # stock method, which is what the map's reader is hooked on.
  class Scene < PokemonRegionMapScene
    PLACES = { [5, 3] => "Ruta 5", [9, 2] => "<c2=65467BFF>Ruta 9</c2>" }
    def initialize(sprites); @sprites = sprites; end
    def drawRoamingPosition(_mapindex); end
    def pbGetMapLocation(x, y); super; PLACES[[x, y]] || ""; end
  end

  # Another engine's scene, whose roaming sprites are numbered by entry: it has no drawRoamingPosition.
  class OtherEngine < PokemonRegionMapScene
    def initialize(sprites); @sprites = sprites; end
  end

  test "as the map opens each roamer is said with its place, queued and by species" do
    RM.opened(fork_scene(244 => [1, 1], 243 => [5, 3]))
    list = [T.t(:rmap_roamer, :name => "Especie243", :place => "Ruta 5"),
            T.t(:rmap_roamer, :name => "Especie244", :place => T.t(:brm_square, :x => 1, :y => 1))]
    assert_equal [[T.t(:rmap_roamers, :list => list.join(", ")), false]], SpeakCapture.log
  end

  test "a roamer's place is said bare of the tags it is written with" do
    RM.opened(fork_scene(243 => [9, 2]))
    list = T.t(:rmap_roamer, :name => "Especie243", :place => "Ruta 9")
    assert_equal [T.t(:rmap_roamers, :list => list)], SpeakCapture.lines
  end

  test "a map with no roamer opens with nothing more" do
    RM.opened(fork_scene({}))
    assert_nothing_spoken
  end

  test "the player's square is still said ahead of the roamers" do
    scene = fork_scene(243 => [5, 3])
    scene.instance_variable_get(:@sprites)["player"] = Object.new
    RM.announce(scene, "Ruta 9", 9, 2)
    SpeakCapture.clear
    RM.opened(scene)
    assert_equal T.t(:rmap_you), SpeakCapture.lines.first
    assert_equal 2, SpeakCapture.lines.length
  end

  test "a square names the roamers drawn on it, after its place" do
    scene = fork_scene(243 => [5, 3], 245 => [5, 3], 244 => [6, 3])
    assert_equal "Ruta 5, Especie243, Especie245", RM.square_text(scene, "Ruta 5", 5, 3)
    assert_equal "Ruta 9", RM.square_text(scene, "Ruta 9", 9, 2)
  end

  test "the squares around a roamer's icon name nobody" do
    scene = fork_scene(243 => [5, 3])
    assert_equal [[], [], [], []], [[4, 3], [6, 3], [5, 2], [5, 4]].map { |x, y| RM.square_marks(scene, x, y) }
  end

  test "an icon with no picture, which shows nothing, reads nothing" do
    scene = Scene.new("map" => Sprite.new(Pic.new(256, 192)), "roaming243" => Icon.new(*spot(5, 3), nil))
    RM.opened(scene)
    assert_nothing_spoken
    assert_equal [], RM.square_marks(scene, 5, 3)
  end

  test "another engine's roaming sprites read nothing" do
    scene = OtherEngine.new("map" => Sprite.new(Pic.new(256, 192)), "roaming0" => Icon.new(*spot(5, 3)))
    RM.opened(scene)
    assert_nothing_spoken
    assert_equal "Ruta 5", RM.square_text(scene, "Ruta 5", 5, 3)
  end

  test "a map with no bitmap to place the icons by reads nothing" do
    scene = Scene.new("map" => Sprite.new(nil), "roaming243" => Icon.new(*spot(5, 3)))
    RM.opened(scene)
    assert_nothing_spoken
  end

  private

  # The scene with the given roamers (species => square), each icon where drawRoamingPosition puts it.
  def fork_scene(roamers)
    sprites = { "map" => Sprite.new(Pic.new(256, 192)), "cursor" => Object.new }
    roamers.each { |species, (x, y)| sprites["roaming#{species}"] = Icon.new(*spot(x, y)) }
    Scene.new(sprites)
  end

  # Where the game puts an icon's corner for a square: half a square before the square's start.
  def spot(x, y)
    [-8 + x * 16 + MAP_LEFT, -8 + y * 16 + MAP_TOP]
  end
end
