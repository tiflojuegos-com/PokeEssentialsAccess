# The region map of the engine Reborn, Rejuvenation and Desolation share (games/rv_common/region_map_rv.rb): a square
# with a roaming Pokemon's icon (one RoamingSpecies entry per roamer, its icon the scene's roaming<i> sprite centred on
# its square) names the roamer after the place.
Harness.load_common("rv_common")

class RegionMapRvTest < PokeAccessTest
  # The roamers the game lists, each drawn as the roaming<i> icon of its index while it is loose.
  ROAMERS = [{ :species => 243 }, { :species => 244 }, { :species => 245 }]
  Pic = Struct.new(:width, :height)
  Shown = Struct.new(:x, :y, :bitmap, :visible)
  # An icon with no visibility of its own.
  Plain = Struct.new(:x, :y, :bitmap)

  # A map scene of that engine: its squares' size and the sprites it draws.
  class Scene
    SQUAREWIDTH = 16
    SQUAREHEIGHT = 16
    def initialize(sprites); @sprites = sprites; end
  end

  test "a square with a roamer's icon names it after the place, whatever the size of the map and of the icon" do
    { [480, 320] => 24, [256, 192] => 64, [512, 384] => 16 }.each do |map, size|
      scene = roaming_map({ 0 => [5, 3, size] }, map)
      assert_equal "Route 1, #{species(243)}", text(scene, 5, 3), "a #{map.join('x')} map, a #{size} pixel icon"
    end
  end

  test "the squares around the icon name no roamer" do
    scene = roaming_map(0 => [5, 3, 24])
    assert_equal ["Route 1"] * 4, [[6, 3], [4, 3], [5, 2], [5, 4]].map { |x, y| text(scene, x, y) }
  end

  test "names every roamer on the square, in the game's order" do
    scene = roaming_map(2 => [5, 3, 24], 1 => [6, 3, 24], 0 => [5, 3, 24])
    assert_equal "Route 1, #{species(243)}, #{species(245)}", text(scene, 5, 3)
  end

  test "skips a roamer the map draws no icon for, and names the next" do
    scene = roaming_map(1 => [5, 3, 24])
    assert_equal "Route 1, #{species(244)}", text(scene, 5, 3)
  end

  test "a hidden icon names no roamer" do
    scene = roaming_map(0 => [5, 3, 24, false])
    assert_equal "Route 1", text(scene, 5, 3)
  end

  test "an icon with no visibility of its own counts as shown" do
    scene = roaming_map(0 => [5, 3, 24, :none])
    assert_equal "Route 1, #{species(243)}", text(scene, 5, 3)
  end

  test "a map with no map picture names no roamer" do
    assert_equal "Route 1", text(Scene.new({}), 5, 3)
  end

  test "a map whose picture has no bitmap yet names no roamer, and still says the place" do
    scene = roaming_map(0 => [5, 3, 24])
    scene.instance_variable_get(:@sprites)["map"].bitmap = nil
    assert_equal "Route 1", text(scene, 5, 3)
  end

  test "a game with no roaming list names no roamer" do
    assert_equal "Route 1", text(roaming_map(0 => [5, 3, 24]), 5, 3, nil)
  end

  test "places the icons on the screen the engine reports" do
    with_screen([640, 480]) do
      assert_equal "Route 1, #{species(243)}", text(roaming_map(0 => [5, 3, 24]), 5, 3)
    end
  end

  test "where the engine cannot report its screen, places the icons on its 512 by 384 one" do
    scene = with_screen([512, 384]) { roaming_map(0 => [5, 3, 24]) }
    with_screen(nil) { assert_equal "Route 1, #{species(243)}", text(scene, 5, 3) }
  end

  private

  # The line the map says for (x, y) of a square whose place is Route 1, with the game listing roamers (nil: no list).
  def text(scene, x, y, roamers = ROAMERS)
    with_roamers(roamers) { PokeAccess::RegionMap.square_text(scene, "Route 1", x, y) }
  end

  def species(id)
    PokeAccess::Data.species_name(id)
  end

  # A scene whose map picture (map, its width and height) is centred on the screen, with an icon for each roamer drawn:
  # icons maps a roamer's index to [x, y, icon size, shown (true, false or :none for no flag)], each placed on its square
  # by the engine's own formula.
  def roaming_map(icons, map = [480, 320])
    w = Scene::SQUAREWIDTH
    h = Scene::SQUAREHEIGHT
    sprites = { "map" => Shown.new(0, 0, Pic.new(map[0], map[1]), true) }
    icons.each do |i, (sx, sy, size, shown)|
      x = w / 2 - size / 2 + sx * w + (Graphics.width - map[0]) / 2
      y = h / 2 - size / 2 + sy * h + (Graphics.height - map[1]) / 2
      pic = Pic.new(size, size)
      sprites["roaming#{i}"] = shown == :none ? Plain.new(x, y, pic) : Shown.new(x, y, pic, shown != false)
    end
    Scene.new(sprites)
  end

  # Runs the block with the game's RoamingSpecies set to list, or undefined for nil, and takes it back after.
  def with_roamers(list)
    had = Object.const_defined?(:RoamingSpecies, false)
    was = had ? Object.send(:remove_const, :RoamingSpecies) : nil
    Object.const_set(:RoamingSpecies, list) if list
    yield
  ensure
    Object.send(:remove_const, :RoamingSpecies) if Object.const_defined?(:RoamingSpecies, false)
    Object.const_set(:RoamingSpecies, was) if had
  end

  # Runs the block with Graphics reporting a screen of size [width, height], or, for nil, raising as an engine with no
  # such query does, and returns the block's value; the stub's own size is put back after.
  def with_screen(size)
    meta = Graphics.singleton_class
    [:width, :height].each { |m| meta.send(:alias_method, :"pa_was_#{m}", m) }
    [[:width, 0], [:height, 1]].each do |m, i|
      Graphics.define_singleton_method(m) { size ? size[i] : raise(NoMethodError, "undefined method #{m} for Graphics") }
    end
    yield
  ensure
    [:width, :height].each do |m|
      meta.send(:alias_method, m, :"pa_was_#{m}")
      meta.send(:remove_method, :"pa_was_#{m}")
    end
  end
end
