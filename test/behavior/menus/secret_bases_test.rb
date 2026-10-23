# Secret base decorating: whether a decoration fits where the cursor stands, asked tile by tile of the plugin copy's
# own can_place_here?, with the arity that copy declares (the fork's takes the tile's place in the piece).
class SecretBasesTest < PokeAccessTest
  # A decoration's data: its footprint as [width, height].
  Piece = Struct.new(:tile_size)

  # The fork's decorating scene, whose check takes the tile's place in the piece; it records each tile asked and
  # refuses the blocked ones.
  class ForkScene
    attr_reader :calls
    def initialize(blocked = []); @blocked = blocked; @calls = []; end

    def can_place_here?(_data, x, y, pos)
      @calls.push([x, y, pos])
      !@blocked.include?([x, y])
    end
  end

  # The original plugin's decorating scene, whose check takes no place in the piece.
  class PluginScene
    attr_reader :calls
    def initialize(blocked = []); @blocked = blocked; @calls = []; end

    def can_place_here?(_data, x, y)
      @calls.push([x, y])
      !@blocked.include?([x, y])
    end
  end

  # A scene whose check raises, as one asked before its map is built.
  class FailingScene
    def can_place_here?(_data, _x, _y); raise "no map yet"; end
  end

  test "asks the fork's copy about every tile from the bottom right, with each tile's place in the piece" do
    scene = ForkScene.new
    assert_equal true, fits(scene, 2, 2)
    assert_equal [[5, 5, 0], [4, 5, 1], [5, 4, 2], [4, 4, 3]], scene.calls
  end

  test "asks the original plugin's copy about the same tiles in the same order" do
    scene = PluginScene.new
    assert_equal true, fits(scene, 2, 2)
    assert_equal [[5, 5], [4, 5], [5, 4], [4, 4]], scene.calls
  end

  test "one blocked tile blocks the whole piece" do
    assert_equal false, fits(PluginScene.new([[4, 4]]), 2, 2)
  end

  test "walks a piece's own width and height" do
    { [2, 1] => [[5, 5], [4, 5]], [1, 2] => [[5, 5], [5, 4]], [1, 1] => [[5, 5]] }.each do |size, tiles|
      scene = PluginScene.new
      assert_equal true, fits(scene, *size), "a #{size.join('x')} piece fits"
      assert_equal tiles, scene.calls, "the tiles of a #{size.join('x')} piece"
    end
  end

  test "decides nothing for a piece of no width or no height" do
    [[0, 2], [2, 0]].each { |size| assert_nil fits(PluginScene.new, *size), "a #{size.join('x')} piece" }
  end

  test "decides nothing for a decoration whose size it cannot read" do
    [Object.new, Piece.new(nil), Piece.new([2])].each do |data|
      assert_nil PokeAccess::SecretBases.fits?(PluginScene.new, data, 5, 5), "for #{data.inspect}"
    end
  end

  test "decides nothing on a scene without the check" do
    assert_nil fits(Object.new, 2, 2)
  end

  test "decides nothing when the scene's check raises" do
    assert_nil fits(FailingScene.new, 1, 1)
  end

  private

  # Whether a piece of w by h tiles fits on the scene with its bottom right tile at (5, 5).
  def fits(scene, w, h)
    PokeAccess::SecretBases.fits?(scene, Piece.new([w, h]), 5, 5)
  end
end
