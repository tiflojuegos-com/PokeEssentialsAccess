# Secret bases in the gamedata pass: the decoration shops' prompts, money and descriptions, both copies' category and
# decoration lists and the info key they fill, and what the decorating screen's cursor says of its tile.
module GameData
  # The decorations the tests place: a Pikachu cushion (1x1, set on top), a red mat (2x2) and a desk (2x1) from the
  # tileset, a tall doll (1x2) that is an event's sprite, with no tile offset, a box whose size reads as nothing and a
  # piece without a name.
  class SecretBaseDecoration
    ROWS = { :PIKACHUCUSHION => ["Cojín Pikachu", [1, 1], :decor, 12], :REDMAT => ["Alfombra roja", [2, 2], :mat, 40],
             :DESK => ["Escritorio", [2, 1], :floor, 45], :BIGDOLL => ["Muñeco grande", [1, 2], :floor, nil],
             :ODDBOX => ["Caja rara", nil, :floor, 3], :NONAME => ["", [1, 1], :floor, 0] }
    def self.get(id); ROWS[id] ? new(id) : raise(ArgumentError, "no decoration #{id}"); end
    def initialize(id); @id = id; end
    def name; ROWS[@id][0]; end
    def tile_size; ROWS[@id][1]; end
    def permission; ROWS[@id][2]; end
    def tile_offset; ROWS[@id][3]; end
    def description; "#{name}, para la base."; end
  end

  # Royal's wall and floor decorations, a list of their own.
  class SecretBaseDecorationParedSuelo
    def self.get(id); id == :BRICKWALL ? new : raise(ArgumentError, "no wall #{id}"); end
    def name; "Pared de ladrillo"; end
    def description; "Una pared de ladrillo."; end
  end
end unless defined?(GameData::SecretBaseDecoration)

# The base's decoration bag of each copy, as the plugin and Royal's fork name their categories.
module SecretBag
  def self.pocket_count; 2; end
  def self.pocket_names; ["Sillas", ""]; end
end

module SecretBagParedesSuelos
  def self.pocket_count; 1; end
  def self.pocket_names; ["Paredes"]; end
end

# The category and decoration lists of both copies, which the plugin reads by class name.
class Window_BasePocketsList < Window_DrawableCommand
  def initialize(bag); super([]); @bag = bag; end
end

class Window_BasePocketsListParedSuelo < Window_DrawableCommand
  def initialize(bag); super([]); @bag = bag; end
end

class Window_BaseDecorationsList < Window_DrawableCommand
  def initialize(bag, pocket); super([]); @bag = bag; @pocket = pocket; end
end

class Window_BaseDecorationsParedSueloList < Window_DrawableCommand
  def initialize(bag, pocket); super([]); @bag = bag; @pocket = pocket; end
end

# The decorating screen: the cursor's tile, the decoration in hand ([id] while placing, nil while removing) and the
# base; each of its loops runs pbUpdate. This one has no check of its own before placing.
class PlaceDecoration_Scene
  def initialize(x, y, item = nil, base = nil); @cursor_x = x; @cursor_y = y; @item = item; @base = base; end
  def move(x, y); @cursor_x = x; @cursor_y = y; end
  def pbUpdate; :updated; end
end

# The scenes of the two decoration lists, which close with pbEndScene.
class SecretBag_Scene
  def pbEndScene; :closed; end
end

class SecretBagParedSuelo_Scene
  def pbEndScene; :closed; end
end

# No stub has the decorating screen or the list scenes, so the plugin's hooks on them, evaluated at boot, bound nothing:
# those registrations (from the decorating screen's hook to the shop's) are evaluated once more over the classes above.
secret_bases_path = File.join(Harness::ROOT, "plugins", "secret_bases.rb")
secret_bases_src = Harness.source(secret_bases_path)
secret_bases_at = secret_bases_src.index(/^PokeAccess::Hooks\.after_hook\("PlaceDecoration_Scene"/)
eval(secret_bases_src[secret_bases_at...secret_bases_src.index(/^\[:pbDisplay/)], TOPLEVEL_BINDING, secret_bases_path,
     secret_bases_src[0, secret_bases_at].count("\n") + 1)

# Royal's wall and floor shop as the game defines it, with its money window; its profile file is evaluated over it, the
# profile's name taken back after.
class SecretBaseMartParedSuelo_Scene
  attr_reader :sprites
  def initialize; @sprites = { "moneywindow" => FakeTextWin.new("Dinero:\r\n<r>$900") }; end
  def pbStartBuyScene(*_a); :buy; end
  def pbStartSellScene(*_a); :sell; end
  def pbEndBuyScene; :end_buy; end
  def pbEndSellScene; :end_sell; end
  def pbDisplay(msg, _brief = false); msg; end
  def pbDisplayPaused(msg); msg; end
  def pbConfirm(_msg); false; end
end

royal_shop_profiles = PokeAccess::Game.profiles.dup
begin
  royal_shop_path = File.join(Harness::ROOT, "games", "royal", "secret_base_shop.rb")
  eval(Harness.source(royal_shop_path), TOPLEVEL_BINDING, royal_shop_path)
ensure
  PokeAccess::Game.profiles.replace(royal_shop_profiles)
end

class SecretBasesGdTest < PokeAccessTest
  # The base's bag: pockets of [decoration, count] rows, each category's [count, maximum], and the placed slots.
  class BaseBag
    attr_reader :pockets
    def initialize(pockets = {}, sizes = {}, placed = []); @pockets = pockets; @sizes = sizes; @placed = placed; end
    def current_pocket_size(pocket); (@sizes[pocket] || [])[0]; end
    def max_pocket_size(pocket); (@sizes[pocket] || [])[1]; end
    def is_placed?(_pocket, i); @placed.include?(i); end
  end

  # A bag that counts a category's decorations but keeps no maximum for it.
  class UncappedBag
    def current_pocket_size(_pocket); 3; end
  end

  # A bag that lists its decorations but cannot tell which are placed in the base.
  PlainBag = Struct.new(:pockets)

  # The shop's adapter: each decoration's name and the description the buy list shows beside it.
  class ShopAdapter
    ROWS = { :DESK => ["Escritorio", "Un escritorio pequeño."], :CHAIR => ["Silla", "Una silla."],
             :PLANT => ["Planta", ""] }
    def getDisplayName(item); ROWS[item][0]; end
    def getDescription(item); ROWS[item][1]; end
  end

  # The decorating screen of a copy that checks a tile before placing, refusing the blocked ones.
  class CheckingScene < PlaceDecoration_Scene
    def initialize(x, y, item, blocked = []); super(x, y, item); @blocked = blocked; end
    def can_place_here?(_data, x, y); !@blocked.include?([x, y]); end
  end

  Base = Struct.new(:decorations)
  ItemList = Struct.new(:item)
  QUESTION = "¿Así que quieres Cojín Pikachu?\nSerían $300. ¿Te parece bien?"

  test "says the shop's question before its choices, keeping the shop's answer" do
    assert_equal true, SecretBaseMart_Scene.new("$1.500").pbConfirm(QUESTION)
    assert_equal [[PokeAccess.clean(QUESTION), false]], SpeakCapture.log
  end

  test "says the shop's results as it shows them, queued" do
    shop = SecretBaseMart_Scene.new("$1.500")
    shop.pbDisplayPaused("¡Gracias!\nTe lo enviaré al PC de tu casa.")
    shop.pbDisplay("No tienes suficiente dinero.")
    assert_equal [[PokeAccess.clean("¡Gracias!\nTe lo enviaré al PC de tu casa."), false],
                  ["No tienes suficiente dinero.", false]], SpeakCapture.log
  end

  test "says the money on the shop's first frame, queued, and the frame runs as it would" do
    assert_equal :updated, SecretBaseMart_Scene.new("$1.500").update
    assert_equal [[money("$1.500"), false]], SpeakCapture.log
  end

  test "says the money no more while it stays the same" do
    shop = SecretBaseMart_Scene.new("$1.500")
    shop.update
    SpeakCapture.clear
    shop.update
    assert_nothing_spoken
  end

  test "says the money again when a purchase changes it" do
    shop = SecretBaseMart_Scene.new("$1.500")
    shop.update
    shop.sprites["moneywindow"].text = "Dinero:\r\n<r>$1.200"
    SpeakCapture.clear
    shop.update
    assert_equal [[money("$1.200"), false]], SpeakCapture.log
  end

  test "says nothing while the money window is hidden" do
    shop = SecretBaseMart_Scene.new("$1.500")
    shop.update
    shop.sprites["moneywindow"].visible = false
    shop.sprites["moneywindow"].text = "Dinero:\r\n<r>$1.000"
    SpeakCapture.clear
    shop.update
    assert_nothing_spoken
  end

  test "says nothing for a money window that cannot tell whether it shows" do
    shop = SecretBaseMart_Scene.new("$1.500")
    shop.sprites["moneywindow"] = Struct.new(:text).new("Dinero:\r\n<r>$700")
    shop.update
    assert_nothing_spoken
  end

  test "says the focused decoration's description after its row, queued, in full" do
    shop_on(:DESK).update
    assert_equal [["Un escritorio pequeño.", false]], SpeakCapture.log
  end

  test "keeps the decoration's name and description for the info key" do
    shop_on(:DESK).update
    assert_equal "Escritorio. Un escritorio pequeño.", PokeAccess::Info.info_text
  end

  test "adds the description to the row Ctrl+T repeats" do
    PokeAccess::Info.set_info(:item, :DESK, "Escritorio, $45")
    shop_on(:DESK).update
    assert_equal "Escritorio, $45. Un escritorio pequeño.", PokeAccess::Info.row_text
  end

  test "says a decoration's description once while it stays focused" do
    shop = shop_on(:DESK)
    shop.update
    SpeakCapture.clear
    shop.update
    assert_nothing_spoken
  end

  test "says the next decoration's description as the focus moves to it, the info key taking it up" do
    shop = shop_on(:DESK)
    shop.update
    shop.sprites["itemwindow"].item = :CHAIR
    SpeakCapture.clear
    shop.update
    assert_equal [["Una silla.", false]], SpeakCapture.log
    assert_equal "Silla. Una silla.", PokeAccess::Info.info_text
  end

  test "below full, keeps the description for the info key without saying it" do
    PokeAccess::Config.verbosity = :medium
    shop_on(:CHAIR).update
    assert_nothing_spoken
    assert_equal "Silla. Una silla.", PokeAccess::Info.info_text
  end

  test "says nothing for a decoration without a description" do
    shop_on(:PLANT).update
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text
  end

  test "leaves descriptions to the base's own list while selling" do
    shop = shop_on(:DESK)
    shop.instance_variable_set(:@subscene, Object.new)
    shop.update
    assert_nothing_spoken
  end

  test "Royal's wall and floor shop says its question, keeping its answer" do
    assert_equal false, SecretBaseMartParedSuelo_Scene.new.pbConfirm("¿Así que quieres Pared de ladrillo?")
    assert_equal [["¿Así que quieres Pared de ladrillo?", false]], SpeakCapture.log
  end

  test "Royal's wall and floor shop says its money from either opening, queued" do
    keeping_live_scene do
      { :pbStartBuyScene => :buy, :pbStartSellScene => :sell }.each do |opener, value|
        SpeakCapture.clear
        assert_equal value, SecretBaseMartParedSuelo_Scene.new.send(opener, [], nil), "#{opener} runs as it would"
        PokeAccess::InfoWindow.tick
        assert_equal [[money("$900"), false]], SpeakCapture.log, "after #{opener}"
      end
    end
  end

  test "Royal's wall and floor shop says no money once either close runs" do
    keeping_live_scene do
      [[:pbStartBuyScene, :pbEndBuyScene], [:pbStartSellScene, :pbEndSellScene]].each do |opener, closer|
        shop = SecretBaseMartParedSuelo_Scene.new
        shop.send(opener, [], nil)
        PokeAccess::InfoWindow.tick
        shop.send(closer)
        shop.sprites["moneywindow"].text = "Dinero:\r\n<r>$100"
        SpeakCapture.clear
        PokeAccess::InfoWindow.tick
        assert_nothing_spoken "after #{closer}"
      end
    end
  end

  test "a category row says its name and how full the base's bag is" do
    { [3, 10] => "Sillas, #{PokeAccess::I18n.t(:sb_qty, :cur => 3, :max => 10)}",
      [1, 1] => "Sillas, #{PokeAccess::I18n.t(:sb_qty, :cur => 1, :max => 1)}", [3, 0] => "Sillas, 3",
      [nil, 10] => "Sillas" }.each do |(count, max), want|
      list = Window_BasePocketsList.new(BaseBag.new({}, { 1 => [count, max] }))
      assert_equal want, PokeAccess::Menus.focused_text(list), "#{count.inspect} of #{max.inspect}"
    end
  end

  test "a category row says the count alone for a bag that keeps no maximum" do
    assert_equal "Sillas, 3", PokeAccess::Menus.focused_text(Window_BasePocketsList.new(UncappedBag.new))
  end

  test "a category without a name gives no row" do
    list = Window_BasePocketsList.new(BaseBag.new)
    list.index = 1
    assert_nil PokeAccess::Menus.focused_text(list)
  end

  test "the category row past the last is Cancel" do
    list = Window_BasePocketsList.new(BaseBag.new)
    list.index = 2
    assert_equal PokeAccess::I18n.t(:pc_cancel), PokeAccess::Menus.focused_text(list)
  end

  test "a decoration row says its name and the description the list shows beside it, in full" do
    whole = "Cojín Pikachu. Cojín Pikachu, para la base."
    assert_equal whole, decoration_row(0)
    assert_equal [whole, whole], [PokeAccess::Info.info_text, PokeAccess::Info.row_text], "the info key and Ctrl+T"
  end

  test "below full, a decoration row is its name, marked when placed, while the info key keeps its description" do
    PokeAccess::Config.verbosity = :medium
    placed = PokeAccess::I18n.t(:sb_placed, :name => "Alfombra roja")
    assert_equal placed, decoration_row(1)
    assert_equal "#{placed}. Alfombra roja, para la base.", PokeAccess::Info.info_text
  end

  test "a decoration row is nothing for an empty slot, a decoration the data lacks or one without a name" do
    assert_nil decoration_row(2), "an empty slot"
    assert_nil decoration_row(3), "an unknown decoration"
    assert_nil decoration_row(4), "a decoration without a name"
  end

  test "the decoration row past the last is Cancel" do
    assert_equal PokeAccess::I18n.t(:pc_cancel), decoration_row(5)
  end

  test "a decoration row is the plain name in a bag that cannot tell what is placed" do
    list = Window_BaseDecorationsList.new(PlainBag.new({ 1 => [[:REDMAT, 1]] }), 1)
    assert_equal "Alfombra roja. Alfombra roja, para la base.", PokeAccess::Menus.focused_text(list)
  end

  test "a decoration row is nothing for a pocket the bag lacks" do
    list = Window_BaseDecorationsList.new(BaseBag.new({ 1 => [[:DESK, 1]] }), 7)
    assert_nil PokeAccess::Menus.focused_text(list)
  end

  test "reads Royal's wall and floor lists by their own bag and decorations" do
    pockets = Window_BasePocketsListParedSuelo.new(BaseBag.new({}, { 1 => [2, 5] }))
    walls = Window_BaseDecorationsParedSueloList.new(BaseBag.new({ 1 => [[:BRICKWALL, 1]] }), 1)
    assert_equal "Paredes, #{PokeAccess::I18n.t(:sb_qty, :cur => 2, :max => 5)}",
                 PokeAccess::Menus.focused_text(pockets)
    assert_equal "Pared de ladrillo. Una pared de ladrillo.", PokeAccess::Menus.focused_text(walls)
  end

  test "closing either decoration list takes its description off the info key" do
    [SecretBag_Scene, SecretBagParedSuelo_Scene].each do |scene|
      decoration_row(0)
      assert_equal :closed, scene.new.pbEndScene, "#{scene} closes as it would"
      assert_nil PokeAccess::Info.info_text, "after #{scene} closes"
    end
  end

  test "the removing cursor's tile names the cushion on top before the mat beneath, leaving the slots as they are" do
    base = Base.new([[:REDMAT, 5, 5], [:PIKACHUCUSHION, 4, 4]])
    assert_equal ["Cojín Pikachu", "Alfombra roja"], PokeAccess::SecretBases.names_at(base, 4, 4)
    assert_equal [[:REDMAT, 5, 5], [:PIKACHUCUSHION, 4, 4]], base.decorations
  end

  test "finds a piece on every tile of its footprint, anchored at its bottom right, and on none beside it" do
    { [:REDMAT, 5, 5] => [[[4, 4], [5, 4], [4, 5], [5, 5]], [[3, 5], [6, 5], [5, 3], [5, 6], [3, 3]]],
      [:DESK, 9, 2] => [[[8, 2], [9, 2]], [[7, 2], [10, 2], [9, 1], [9, 3]]] }.each do |slot, (inside, outside)|
      base = Base.new([slot])
      name = GameData::SecretBaseDecoration.get(slot[0]).name
      inside.each { |x, y| assert_equal [name], PokeAccess::SecretBases.names_at(base, x, y), "#{name} at #{x}, #{y}" }
      outside.each do |x, y|
        assert_equal [], PokeAccess::SecretBases.names_at(base, x, y), "beside #{name}: #{x}, #{y}"
      end
    end
  end

  test "finds an event's sprite only on its bottom row, as removing does" do
    base = Base.new([[:BIGDOLL, 7, 7]])
    assert_equal [["Muñeco grande"], []], [[7, 7], [7, 6]].map { |x, y| PokeAccess::SecretBases.names_at(base, x, y) }
  end

  test "finds nothing in an empty slot, for a decoration the data lacks, or one whose size it cannot read" do
    base = Base.new([nil, [:GONE, 1, 1], [:ODDBOX, 3, 3]])
    assert_equal [[], []], [[1, 1], [3, 3]].map { |x, y| PokeAccess::SecretBases.names_at(base, x, y) }
  end

  test "finds nothing in a base without its list of decorations" do
    [Base.new(nil), Object.new].each { |base| assert_equal [], PokeAccess::SecretBases.names_at(base, 1, 1) }
  end

  test "the decorating screen's frame says the removing cursor's tile and what it holds, the top one first" do
    scene = PlaceDecoration_Scene.new(4, 4, nil, Base.new([[:REDMAT, 5, 5], [:PIKACHUCUSHION, 4, 4]]))
    assert_equal :updated, scene.pbUpdate, "the frame runs as it would"
    assert_equal [["#{tile(4, 4)}, Cojín Pikachu, Alfombra roja", true]], SpeakCapture.log
  end

  test "the removing cursor says a tile with no decoration as such" do
    PlaceDecoration_Scene.new(3, 3, nil, Base.new([[:DESK, 9, 2]])).pbUpdate
    assert_equal [["#{tile(3, 3)}, #{PokeAccess::I18n.t(:sb_nothing)}", true]], SpeakCapture.log
  end

  test "the removing cursor says what its tile holds at every level" do
    PokeAccess::Config.verbosity = :brief
    PlaceDecoration_Scene.new(8, 2, nil, Base.new([[:DESK, 9, 2]])).pbUpdate
    assert_equal [["#{tile(8, 2)}, Escritorio", true]], SpeakCapture.log
  end

  test "says a tile once until the cursor moves" do
    scene = PlaceDecoration_Scene.new(3, 3, nil, Base.new([]))
    scene.pbUpdate
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken "the same tile"
    scene.move(4, 3)
    scene.pbUpdate
    assert_equal [["#{tile(4, 3)}, #{PokeAccess::I18n.t(:sb_nothing)}", true]], SpeakCapture.log, "the next one"
  end

  test "says nothing for a cursor without a column or a row" do
    [[nil, 3], [3, nil]].each do |x, y|
      PlaceDecoration_Scene.new(x, y, nil, Base.new([])).pbUpdate
      assert_nothing_spoken "at #{x.inspect}, #{y.inspect}"
    end
  end

  test "carrying a decoration, says the tile, its name and that it fits" do
    CheckingScene.new(9, 2, [:DESK]).pbUpdate
    assert_equal [["#{tile(9, 2)}, Escritorio, #{PokeAccess::I18n.t(:sb_can_place)}", true]], SpeakCapture.log
  end

  test "carrying a decoration, says it blocked where a tile of the piece is taken" do
    CheckingScene.new(9, 2, [:DESK], [[8, 2]]).pbUpdate
    assert_equal [["#{tile(9, 2)}, Escritorio, #{PokeAccess::I18n.t(:sb_blocked)}", true]], SpeakCapture.log
  end

  test "at brief, leaves the decoration in hand to the info key" do
    PokeAccess::Config.verbosity = :brief
    CheckingScene.new(9, 2, [:DESK]).pbUpdate
    can = PokeAccess::I18n.t(:sb_can_place)
    assert_equal [["#{tile(9, 2)}, #{can}", true]], SpeakCapture.log
    assert_equal "#{tile(9, 2)}, Escritorio, #{can}", PokeAccess::Info.info_text
  end

  test "says no fit where the screen has no check of its own" do
    PlaceDecoration_Scene.new(9, 2, [:DESK]).pbUpdate
    assert_equal [["#{tile(9, 2)}, Escritorio", true]], SpeakCapture.log
  end

  test "says the tile alone for a decoration in hand the data lacks" do
    CheckingScene.new(9, 2, [:GONE]).pbUpdate
    assert_equal [[tile(9, 2), true]], SpeakCapture.log
  end

  private

  # The money window's text as painted, cleaned as the reader says it.
  def money(amount)
    PokeAccess.clean_fields("Dinero:\r\n<r>#{amount}")
  end

  # The decoration shop focused on item in its buy list, its money window hidden.
  def shop_on(item)
    shop = SecretBaseMart_Scene.new("$1.500")
    shop.instance_variable_set(:@adapter, ShopAdapter.new)
    shop.sprites["itemwindow"] = ItemList.new(item)
    shop.sprites["moneywindow"].visible = false
    shop
  end

  # Row i of a decoration list holding a cushion, a placed mat, an empty slot, a decoration the data lacks and one
  # without a name.
  def decoration_row(i)
    bag = BaseBag.new({ 1 => [[:PIKACHUCUSHION, 1], [:REDMAT, 1], nil, [:GONE, 1], [:NONAME, 1]] }, {}, [1])
    list = Window_BaseDecorationsList.new(bag, 1)
    list.index = i
    PokeAccess::Menus.focused_text(list)
  end

  # How the cursor names a tile.
  def tile(x, y)
    PokeAccess::I18n.t(:mg_rowcol, :row => y, :col => x)
  end

  # Runs the block, putting back after it the scene whose standing windows were watched before it.
  def keeping_live_scene
    held = PokeAccess::InfoWindow.live
    yield
  ensure
    held ? PokeAccess::InfoWindow.enter(held) : PokeAccess::InfoWindow.leave
  end
end
