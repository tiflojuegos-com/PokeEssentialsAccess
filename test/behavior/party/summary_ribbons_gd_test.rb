# The modern summary's ribbon grid: the focused ribbon said from the id vanilla's drawSelectedRibbon gets or from the
# (filter, index, page, maxpage) Improved Mementos passes it, and a ribbon carried in the grid said as it is picked up.
class SummaryRibbonsGdTest < PokeAccessTest
  # A cursor sprite of the grid: the cell it is on and whether it shows.
  Cursor = Struct.new(:index, :visible)
  # The ribbons a paged grid lists, in its order.
  FILTER = [:ALERT, :SHOCK, :DOWNCAST, :CAREFREE]

  test "says the ribbon the vanilla redraw passes, by its name and description, interrupting" do
    PokemonSummary_Scene.new.drawSelectedRibbon(3)
    assert_equal [["Ribbon3. rdesc3", true]], SpeakCapture.log
  end

  test "a cell with no ribbon, or a grid shape it cannot read, is said as empty" do
    { "no ribbon" => [nil], "past the filter's end" => [[], 0, 0, 1], "a filter that is no list" => [:ALERT, 1, 0, 1],
      "a page that is no number" => [FILTER, 1, Object.new, 1] }.each do |what, args|
      SpeakCapture.clear
      PokemonSummary_Scene.new.drawSelectedRibbon(*args)
      assert_equal [[t(:rb_empty), true]], SpeakCapture.log, what
    end
  end

  test "a ribbon the game's data leaves blank is said as an empty cell" do
    with_blank_ribbon(:BLANK) { PokemonSummary_Scene.new.drawSelectedRibbon(:BLANK) }
    assert_equal [[t(:rb_empty), true]], SpeakCapture.log
  end

  test "the paged grid's focused entry is the filter's at page times the page size plus the index" do
    with_page_size(2) { PokemonSummary_Scene.new.drawSelectedRibbon(FILTER, 1, 1, 2) }
    assert_equal [["RibbonCAREFREE. rdescCAREFREE", true]], SpeakCapture.log
  end

  test "without the plugin's page size, the grid's index alone picks the entry" do
    PokemonSummary_Scene.new.drawSelectedRibbon(FILTER, 1, 1, 2)
    assert_equal [["RibbonSHOCK. rdescSHOCK", true]], SpeakCapture.log
  end

  test "a grid passing only the filter and the index picks the entry at the index" do
    PokemonSummary_Scene.new.drawSelectedRibbon(FILTER, 2)
    assert_equal [["RibbonDOWNCAST. rdescDOWNCAST", true]], SpeakCapture.log
  end

  test "a ribbon carried in the grid is read from the scene's frame" do
    scene = PokemonSummary_Scene.new(Poke.build(:name => "Pika"))
    scene.instance_variable_set(:@sprites, { "ribbonsel" => Cursor.new(0, false),
                                             "ribbonpresel" => Cursor.new(0, false) })
    scene.pbUpdate
    scene.instance_variable_get(:@sprites)["ribbonsel"].visible = true
    scene.pbUpdate
    scene.instance_variable_get(:@sprites)["ribbonpresel"].visible = true
    SpeakCapture.clear
    scene.pbUpdate
    assert_equal [["#{t(:rb_picked)}. #{t(:rb_picked_hint)}", true]], SpeakCapture.log
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # Runs the block with GameData::Ribbon giving the ribbon id an empty name and description, the rest as before.
  def with_blank_ribbon(id)
    get = GameData::Ribbon.method(:get)
    blank = Struct.new(:name, :description).new("", "")
    GameData::Ribbon.define_singleton_method(:get) { |asked| asked == id ? blank : get.call(asked) }
    yield
  ensure
    GameData::Ribbon.define_singleton_method(:get, get)
  end

  # Runs the block with the Improved Mementos grid's page size (MementoSprite::PAGE_SIZE) set to size, then puts back
  # whatever MementoSprite was, or nothing.
  def with_page_size(size)
    had = Object.const_defined?(:MementoSprite)
    was = had ? Object.const_get(:MementoSprite) : nil
    Object.send(:remove_const, :MementoSprite) if had
    sprite = Module.new
    sprite.const_set(:PAGE_SIZE, size)
    Object.const_set(:MementoSprite, sprite)
    yield
  ensure
    Object.send(:remove_const, :MementoSprite) if Object.const_defined?(:MementoSprite)
    Object.const_set(:MementoSprite, was) if had
  end
end
