# The Berrydex screens (Royal, Infinite Fusion 2 Hoenn): the list's title and counters, queued in reading order when
# they change, the focused berry's name left to the row; a berry's page read as laid out, each label beside its value.

# The detail screen: drawPage paints the page asked for (its description by drawTextEx, the rest by
# pbDrawTextPositions) on the berry's current subpage.
class BerrydexInfo_Scene
  def initialize(berry, rows, description = nil)
    @berry = berry
    @subpage = 0
    @rows = rows
    @description = description
  end

  def drawPage(_page)
    drawTextEx(nil, 40, 278, 432, 3, @description) if @description
    pbDrawTextPositions(nil, @rows)
    :page_drawn
  end
end

# The list screen: pbRefresh repaints the title and counters, the icon sprite showing the focused berry.
class PokemonBerrydex_Scene
  Icon = Struct.new(:berry)

  def initialize(rows, berry)
    @rows = rows
    @sprites = { "berrydex" => Icon.new(berry) }
  end

  def pbRefresh
    pbDrawTextPositions(nil, @rows)
  end
end

berrydex_path = File.join(Harness::ROOT, "plugins", "berrydex.rb")
berrydex_src = Harness.source(berrydex_path)
berrydex_hooks = berrydex_src.index('PokeAccess::Hooks.around_hook("BerrydexInfo_Scene"')
eval(berrydex_src[berrydex_hooks..-1], TOPLEVEL_BINDING, berrydex_path, berrydex_src[0, berrydex_hooks].count("\n") + 1)

class BerrydexHeaderGdTest < PokeAccessTest
  # The list header as the screen paints it: counters, the focused berry's name and the title, out of reading order.
  HEADER = [["Plantadas: ", 56, 346], ["3", 168, 346], [nil, 189, 314], ["Registradas: ", 56, 314],
            ["ItemORANBERRY", 132, 58], ["BayaDex", 256, 10]]

  # The detail page as drawPage paints it: every label before every value.
  PAGE = [["01  Cheri Berry", 50, 36], ["Size", 64, 188], ["Firm", 64, 220], ["2.0 cm", 220, 188], ["Soft", 244, 220]]

  # A berry as GameData::BerryData keeps it.
  Berry = Struct.new(:flavor, :description)

  test "reads the list's title and counters in reading order, without the focused berry's name, queued" do
    PokeAccess::BerryDex.list_header(list_scene, header("12"))
    assert_equal [["BayaDex, Registradas: 12, Plantadas: 3", false]], SpeakCapture.log
  end

  test "a repaint with the same counters says nothing" do
    scene = list_scene
    PokeAccess::BerryDex.list_header(scene, header("12"))
    SpeakCapture.clear
    PokeAccess::BerryDex.list_header(scene, header("12"))
    assert_nothing_spoken
  end

  test "a changed counter is read again, queued" do
    scene = list_scene
    PokeAccess::BerryDex.list_header(scene, header("12"))
    SpeakCapture.clear
    PokeAccess::BerryDex.list_header(scene, header("13"))
    assert_equal [["BayaDex, Registradas: 13, Plantadas: 3", false]], SpeakCapture.log
  end

  test "keeps every painted row where no berry icon names the focus" do
    PokeAccess::BerryDex.list_header(World.stub_scene(:@sprites => {}), header("12"))
    assert_equal [["BayaDex, ItemORANBERRY, Registradas: 12, Plantadas: 3", false]], SpeakCapture.log
  end

  test "two counters showing the same number are both read where no colon pairs them with their labels" do
    rows = [["Registradas", 56, 314], ["3", 189, 314], ["Plantadas", 56, 346], ["3", 168, 346], ["BayaDex", 256, 10]]
    PokeAccess::BerryDex.list_header(list_scene, paint(rows))
    assert_equal [["BayaDex, Registradas, 3, Plantadas, 3", false]], SpeakCapture.log
  end

  test "a header that paints nothing says nothing" do
    [[], nil, paint([["ItemORANBERRY", 132, 58]])].each { |pairs| PokeAccess::BerryDex.list_header(list_scene, pairs) }
    assert_nothing_spoken
  end

  test "the list screen's refresh reads its header as the game paints it" do
    PokemonBerrydex_Scene.new(HEADER.map { |text, x, y| [text || "12", x, y] }, :ORANBERRY).pbRefresh
    assert_equal [["BayaDex, Registradas: 12, Plantadas: 3", false]], SpeakCapture.log
  end

  test "reads a berry's page as laid out, each label beside the value on its row" do
    PokeAccess::BerryDex.page(page_scene, 1, page_paint)
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_info)}. 01 Cheri Berry. Size 2.0 cm. Firm Soft. A soft berry.",
                   true]], SpeakCapture.log
  end

  test "drawing a page reads the page drawPage was asked for" do
    BerrydexInfo_Scene.new(:CHERIBERRY, PAGE, "A soft berry.").drawPage(1)
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_info)}. 01 Cheri Berry. Size 2.0 cm. Firm Soft. A soft berry.",
                   true]], SpeakCapture.log
  end

  test "drawing a page keeps what the game's drawPage returns" do
    assert_equal :page_drawn, BerrydexInfo_Scene.new(:CHERIBERRY, PAGE, "A soft berry.").drawPage(1)
  end

  test "the same page painted again says nothing" do
    scene = page_scene
    PokeAccess::BerryDex.page(scene, 1, page_paint)
    SpeakCapture.clear
    PokeAccess::BerryDex.page(scene, 1, page_paint)
    assert_nothing_spoken
  end

  test "the same page on another subpage is read again" do
    scene = page_scene
    PokeAccess::BerryDex.page(scene, 2, paint(PAGE.first(1)))
    SpeakCapture.clear
    scene.instance_variable_set(:@subpage, 1)
    PokeAccess::BerryDex.page(scene, 2, paint(PAGE.first(1)))
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_plant)}. 01 Cheri Berry", true]], SpeakCapture.log
  end

  test "leaves the berry's painted name out of its page" do
    pairs = paint(PAGE.first(1) + [["ItemCHERIBERRY", 50, 10]])
    PokeAccess::BerryDex.page(page_scene, 2, pairs)
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_plant)}. 01 Cheri Berry", true]], SpeakCapture.log
  end

  test "reads rows painted without a position after the laid-out ones" do
    pairs = [["Loose", :dtex, nil, nil], ["Top", :positions, 10, 10]]
    PokeAccess::BerryDex.page(page_scene, 2, pairs)
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_plant)}. Top. Loose", true]], SpeakCapture.log
  end

  test "the first page with nothing painted falls back to the berry's description" do
    with_berries(:CHERIBERRY => Berry.new(nil, "A berry that cures paralysis.")) do
      PokeAccess::BerryDex.page(page_scene, 1, [])
    end
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_info)}. A berry that cures paralysis.", true]], SpeakCapture.log
  end

  test "the first page with nothing painted falls back to the item's description where the berry has none" do
    { "a berry the data does not know" => {},
      "a berry with a blank description" => { :CHERIBERRY => Berry.new(nil, "") } }.each do |what, table|
      SpeakCapture.clear
      with_berries(table) { PokeAccess::BerryDex.page(page_scene, 1, nil) }
      assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_info)}. idescCHERIBERRY", true]], SpeakCapture.log, what
    end
  end

  test "a later page with nothing painted says its berry and section alone" do
    with_berries(:CHERIBERRY => Berry.new({ "Spicy" => 10 }, "A berry that cures paralysis.")) do
      PokeAccess::BerryDex.page(page_scene, 2, [])
    end
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_plant)}", true]], SpeakCapture.log
  end

  test "the first page ends with the dominant flavour" do
    with_berries(:CHERIBERRY => Berry.new({ "Spicy" => 10, "Dry" => 0 }, "")) do
      PokeAccess::BerryDex.page(page_scene, 1, paint(PAGE))
    end
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_info)}. 01 Cheri Berry. Size 2.0 cm. Firm Soft. #{spicy}",
                   true]], SpeakCapture.log
  end

  test "a description that closes its own sentence takes no second period before the flavour" do
    with_berries(:CHERIBERRY => Berry.new({ "Spicy" => 10 }, "")) do
      PokeAccess::BerryDex.page(page_scene, 1, page_paint)
    end
    assert_equal [["ItemCHERIBERRY. #{section(:bdx_page_info)}. 01 Cheri Berry. Size 2.0 cm. Firm Soft. " \
                   "A soft berry. #{spicy}", true]], SpeakCapture.log
  end

  test "a page past the sections this copy shows is named by its number" do
    PokeAccess::BerryDex.page(page_scene, 3, [])
    assert_equal [["ItemCHERIBERRY. #{PokeAccess::I18n.t(:bdx_section, :name => 3)}", true]], SpeakCapture.log
  end

  test "a screen with no berry says nothing" do
    PokeAccess::BerryDex.page(World.stub_scene(:@berry => nil, :@subpage => 0), 1, page_paint)
    assert_nothing_spoken
  end

  private

  # The list screen, its icon sprite showing the focused berry.
  def list_scene
    World.stub_scene(:@sprites => { "berrydex" => Struct.new(:berry).new(:ORANBERRY) })
  end

  # The header's capture with registered as the registered count.
  def header(registered)
    paint(HEADER.map { |text, x, y| [text || registered, x, y] })
  end

  # The detail screen on a berry's first subpage.
  def page_scene
    World.stub_scene(:@berry => :CHERIBERRY, :@subpage => 0)
  end

  # The detail page's capture: the description painted by drawTextEx, then the rest by pbDrawTextPositions.
  def page_paint
    PokeAccess::PaintCapture.arm(:bdx_page)
    drawTextEx(nil, 40, 278, 432, 3, "A soft berry.")
    pbDrawTextPositions(nil, PAGE)
    PokeAccess::PaintCapture.take_pairs(:bdx_page)
  end

  # What the screen paints with pbDrawTextPositions, as the capture hands it on.
  def paint(rows)
    PokeAccess::PaintCapture.arm(:bdx_paint)
    pbDrawTextPositions(nil, rows)
    PokeAccess::PaintCapture.take_pairs(:bdx_paint)
  end

  # The page's section line for a section's key.
  def section(key)
    PokeAccess::I18n.t(:bdx_section, :name => PokeAccess::I18n.t(key))
  end

  # The flavour line of a berry whose dominant flavour is spicy.
  def spicy
    PokeAccess::I18n.t(:bdx_flavor, :f => PokeAccess::I18n.t(:bdx_fl_spicy))
  end

  # Runs the block with GameData::BerryData answering try_get from table (berry => its data), whatever stood under the
  # name put back after.
  def with_berries(table)
    held = GameData.const_defined?(:BerryData, false) ? GameData::BerryData : nil
    GameData.send(:remove_const, :BerryData) if held
    data = Class.new
    data.define_singleton_method(:try_get) { |b| table[b] }
    GameData.const_set(:BerryData, data)
    yield
  ensure
    GameData.send(:remove_const, :BerryData) if GameData.const_defined?(:BerryData, false)
    GameData.const_set(:BerryData, held) if held
  end
end
