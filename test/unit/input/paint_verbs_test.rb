# The verbs a reader of a painted screen uses: on_paint runs the method and hands the block what it painted, its value going
# back to the game and an error in the block staying there; clear_info_on forgets the screen's line as it closes.
class PaintVerbScene
  attr_reader :read
  def draw(a); pbDrawTextPositions(nil, [["Hola", 10, 20, 0, nil, nil]]); "drawn #{a}"; end
  def broken(_a); pbDrawTextPositions(nil, [["Hola", 10, 20, 0, nil, nil]]); "drawn"; end
  def raising; raise ArgumentError, "the game's"; end
  def pbEndScene; end
  def dispose; end
end

class PaintVerbsTest < PokeAccessTest
  ROWS = []

  PokeAccess::Hooks.on_paint("PaintVerbScene", :draw) { |scene, rows, args| ROWS.push([scene.class, rows.map { |r| r[0] }, args]) }
  PokeAccess::Hooks.on_paint("PaintVerbScene", :broken) { |_scene, _rows, _args| raise "the reader's" }
  PokeAccess::Hooks.on_paint("PaintVerbScene", :raising) { |_scene, _rows, _args| ROWS.push(:read) }
  PokeAccess::Hooks.clear_info_on("PaintVerbScene")
  PokeAccess::Hooks.clear_info_on("PaintVerbScene", :dispose)

  def setup
    super
    ROWS.clear
  end

  test "on_paint hands the block what the method painted, with its arguments, and gives the game its value" do
    assert_equal "drawn 7", PaintVerbScene.new.draw(7)
    assert_equal [[PaintVerbScene, ["Hola"], [7]]], ROWS
  end

  test "on_paint keeps an error of the block from the game" do
    assert_equal "drawn", PaintVerbScene.new.broken(1)
  end

  test "on_paint lets the game's own error through, and reads nothing" do
    assert_raises(ArgumentError) { PaintVerbScene.new.raising }
    assert_equal [], ROWS
  end

  test "clear_info_on forgets the screen's line on the method that closes it, by default pbEndScene" do
    [:pbEndScene, :dispose].each do |meth|
      PokeAccess::Info.set_info(:text, "line")
      PaintVerbScene.new.send(meth)
      assert_nil PokeAccess::Info.info_text, meth.to_s
    end
  end

  test "clear_info_on leaves what is not a screen's line" do
    PokeAccess::Info.set_info(:map, nil)
    PaintVerbScene.new.pbEndScene
    assert_equal :map, PokeAccess::Info.instance_variable_get(:@kind)
  ensure
    PokeAccess::Info.set_info(nil, nil)
  end
end
