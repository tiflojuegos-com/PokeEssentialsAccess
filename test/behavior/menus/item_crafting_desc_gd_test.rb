# Item Crafting UI (plugins/item_crafting.rb): each recipe, inline or kept in the game data by the newer copy, and its
# made item's description, said once at the full level and kept for the info key and Ctrl+T.

# The description window.
class CraftDescWindow
  attr_accessor :text, :visible
  def initialize; @text = ""; @visible = true; end
end

# The scene in Soulstones 2's order, which Emerald's copy keeps: opening runs refreshNumbers and then pbRedrawItem; a
# change of recipe redraws the item, whose first step redraws the amounts while the window still holds the last
# item's description. @pantalla is 0 while the list shows, 1 on a recipe. @stock holds inline recipes [item,
# [ingredient, qty...]] or, in Emerald's copy, GameData::Recipe ids; that copy words a category ingredient (a flag
# such as "berry") by FLAG_TO_TEXT. The adapter names items only: a flag is no item, and asking it raises.
class ItemCraft_Scene
  DESCRIPTIONS = { :POTION => "Restaura 20 PS.", :SUPERPOTION => "Restaura 50 PS.", :ORANBERRY => "" }
  FLAG_TO_TEXT = { "berry" => "Cualquier baya" }

  attr_accessor :stock, :switching, :pantalla
  def initialize
    @sprites = {}
    adapter = Object.new
    def adapter.getName(i); raise ArgumentError, "no item #{i}" unless i.is_a?(Symbol); "Item#{i}"; end
    def adapter.getQuantity(_i); 4; end
    @adapter = adapter
  end
  def pbStartScene; @sprites["itemtext"] = CraftDescWindow.new; :started; end
  def refreshNumbers(_index, _volume); :numbers; end
  def pbRedrawItem(index, volume)
    refreshNumbers(index, volume) if @switching
    row = @stock[index]
    @sprites["itemtext"].text = DESCRIPTIONS[row.is_a?(Array) ? row[0] : GameData::Recipe.get(row).item]
    @switching = false
    :item
  end
  def pbEndScene; :ended; end
end

# The reader bound its hooks at boot, before this class existed, so plugins/item_crafting.rb binds them again here,
# its file from the first hook on.
crafting_path = File.join(Harness::ROOT, "plugins", "item_crafting.rb")
crafting_src = Harness.source(crafting_path)
crafting_hooks = crafting_src.index(/^PokeAccess::Hooks\./)
eval(crafting_src[crafting_hooks..-1], TOPLEVEL_BINDING, crafting_path, crafting_src[0, crafting_hooks].count("\n") + 1)

class ItemCraftingDescGdTest < PokeAccessTest
  POTION = "Restaura 20 PS."
  SUPER_POTION = "Restaura 50 PS."
  TWO_RECIPES = [[:POTION, [:ORANBERRY, 2]], [:SUPERPOTION, [:ORANBERRY, 3]]]

  test "on opening the recipe is said, then its item's description, queued" do
    opened
    assert_equal [[recipe(:POTION, 2), true], [POTION, false]], SpeakCapture.log
  end

  test "the info key says the made item with the description its window shows" do
    opened
    assert_match(/\AItemPOTION\. #{Regexp.escape(POTION)}/, PokeAccess::Info.info_text)
  end

  test "Ctrl+T repeats the recipe with its description" do
    opened
    assert_equal "#{recipe(:POTION, 2)}. #{POTION}", PokeAccess::Info.row_text
  end

  test "the frames while the screen is up say nothing of their own, before or after a change of recipe" do
    scene = opened
    SpeakCapture.clear
    2.times { PokeAccess::Frame.run_pollers }
    assert_nothing_spoken "two frames on the opened recipe"
    scene.switching = true
    scene.pbRedrawItem(1, 1)
    SpeakCapture.clear
    2.times { PokeAccess::Frame.run_pollers }
    assert_nothing_spoken "two frames after the change"
  end

  test "a redraw of the same recipe says nothing" do
    scene = opened
    SpeakCapture.clear
    scene.pbRedrawItem(0, 1)
    assert_nothing_spoken
  end

  test "a change of recipe says it at its amount and its own description, never the one the window still held" do
    scene = opened
    SpeakCapture.clear
    scene.switching = true
    scene.pbRedrawItem(1, 2)
    assert_equal [[recipe(:SUPERPOTION, 3, 2), true], [SUPER_POTION, false]], SpeakCapture.log
  end

  test "an amount of none is read as one craft" do
    [nil, 0].each do |volume|
      SpeakCapture.clear
      scene = ItemCraft_Scene.new
      scene.stock = [[:POTION, [:ORANBERRY, 2]]]
      scene.pbStartScene
      scene.pbRedrawItem(0, volume)
      assert_equal [[recipe(:POTION, 2), true], [POTION, false]], SpeakCapture.log, "an amount of #{volume.inspect}"
    end
  end

  test "a change of amount says the amount alone, and Ctrl+T keeps the description" do
    scene = opened
    SpeakCapture.clear
    scene.refreshNumbers(0, 2)
    assert_equal [recipe(:POTION, 2, 2)], SpeakCapture.lines
    assert_equal "#{recipe(:POTION, 2, 2)}. #{POTION}", PokeAccess::Info.row_text
  end

  test "below the full level the description is left to Ctrl+T" do
    scene = opened
    recipes = [1, 0, 1]
    said = vb_levels do
      SpeakCapture.clear
      scene.switching = true
      scene.pbRedrawItem(recipes.shift, 1)
      [SpeakCapture.lines.dup, PokeAccess::Info.row_text]
    end
    superpotion = recipe(:SUPERPOTION, 3)
    potion = recipe(:POTION, 2)
    assert_equal [[[superpotion], "#{superpotion}. #{SUPER_POTION}"], [[potion], "#{potion}. #{POTION}"],
                  [[superpotion, SUPER_POTION], "#{superpotion}. #{SUPER_POTION}"]], said, "brief, medium and full"
  end

  test "with the list showing a redraw says nothing, and the recipe is said afresh after it" do
    scene = opened
    SpeakCapture.clear
    scene.pantalla = 0
    scene.pbRedrawItem(0, 1)
    assert_nothing_spoken "the list's own reader speaks there"
    scene.pantalla = 1
    scene.pbRedrawItem(0, 1)
    assert_equal [[recipe(:POTION, 2), true], [POTION, false]], SpeakCapture.log
  end

  test "an empty description window says nothing and adds nothing to Ctrl+T" do
    opened([[:ORANBERRY, [:POTION, 1]]])
    assert_equal [[recipe(:ORANBERRY, 1, 1, :POTION), true]], SpeakCapture.log
    assert_equal recipe(:ORANBERRY, 1, 1, :POTION), PokeAccess::Info.row_text
  end

  test "a recipe the game data keeps is said with each ingredient it lists, in their order" do
    ings = [ingredient("ItemORANBERRY", 4, 2), ingredient("ItemPECHABERRY", 4, 1)]
    { "as pairs" => [[:ORANBERRY, 2], [:PECHABERRY, 1]], "flat" => [:ORANBERRY, 2, :PECHABERRY, 1] }.each do |what, list|
      SpeakCapture.clear
      with_recipes(:R_POTION => [:POTION, 1, list]) { opened([:R_POTION]) }
      assert_equal [[detail("ItemPOTION", ings), true], [POTION, false]], SpeakCapture.log, what
    end
  end

  test "an ingredient listed without its count is left out" do
    opened([[:POTION, [:ORANBERRY, 2, :PECHABERRY]]])
    assert_equal detail("ItemPOTION", [ingredient("ItemORANBERRY", 4, 2)]), SpeakCapture.lines.first
  end

  test "a redraw for no recipe at that place says nothing" do
    { "before the first" => [TWO_RECIPES, -1], "past the last" => [TWO_RECIPES, 2],
      "an id the game data lacks" => [[:R_GONE], 0] }.each do |what, (stock, index)|
      scene = ItemCraft_Scene.new
      scene.stock = stock
      scene.pbStartScene
      with_recipes({}) { scene.refreshNumbers(index, 1) }
      assert_nothing_spoken what
    end
  end

  test "a recipe that makes several says how many apart from the amount" do
    with_recipes(:R_POTION => [:POTION, 3, [[:ORANBERRY, 2]]]) { opened([:R_POTION], 2) }
    head = t(:craft_yield, :head => t(:craft_amount, :name => "ItemPOTIONs", :n => 2), :n => 3)
    assert_equal [detail(head, [ingredient("ItemORANBERRY", 4, 4)]), POTION], SpeakCapture.lines
  end

  test "a category ingredient is named by the screen's word and counted over every item that carries it" do
    { "berry" => ["Cualquier baya", 8], "Berry" => ["Cualquier baya", 8], "mineral" => ["mineral", 0] }.each do |flag, (name, have)|
      SpeakCapture.clear
      with_items(:ORANBERRY => ["berry"], :PECHABERRY => ["berry"], :POTION => [], :POKEBALL => nil) do
        with_recipes(:R_MIX => [:POTION, 1, [[flag, 2]]]) { opened([:R_MIX]) }
      end
      assert_equal detail("ItemPOTION", [ingredient(name, have, 2)]), SpeakCapture.lines.first, "the flag #{flag.inspect}"
    end
  end

  test "a category no item list can count is said with what it needs alone" do
    with_items(nil) do
      with_recipes(:R_MIX => [:POTION, 1, [["berry", 2]]]) { opened([:R_MIX]) }
    end
    need = t(:craft_ingredient_need, :name => "Cualquier baya", :need => 2)
    assert_equal detail("ItemPOTION", [need]), SpeakCapture.lines.first
  end

  test "an amount above one names the made item in the plural its adapter gives, else the game data's" do
    { "PluralPOTION" => "PluralPOTION", "" => "ItemPOTIONs" }.each do |given, plural|
      SpeakCapture.clear
      scene = ItemCraft_Scene.new
      adapter = scene.instance_variable_get(:@adapter)
      adapter.define_singleton_method(:getNamePlural) { |_i| given }
      scene.stock = [[:POTION, [:ORANBERRY, 2]]]
      scene.pbStartScene
      scene.pbRedrawItem(0, 2)
      head = t(:craft_amount, :name => plural, :n => 2)
      assert_equal detail(head, [ingredient("ItemORANBERRY", 4, 4)]), SpeakCapture.lines.first, "a plural of #{given.inspect}"
    end
  end

  test "with no stock its adapter can report, or no ingredients listed, the recipe is the item alone" do
    namer = Object.new
    def namer.getName(i); "Item#{i}"; end
    uncounted = ItemCraft_Scene.new
    uncounted.instance_variable_set(:@adapter, namer)
    uncounted.stock = [[:POTION, [:ORANBERRY, 2]]]
    uncounted.pbStartScene
    uncounted.pbRedrawItem(0, 1)
    with_recipes(:R_BARE => [:POTION, 1, nil]) { opened([:R_BARE]) }
    assert_equal [["ItemPOTION", true], [POTION, false]] * 2, SpeakCapture.log
  end

  test "an item its adapter leaves unnamed is named by the game data" do
    opened([[:POTION, [:ORANBERRY, 2]]]) { |scene| scene.instance_variable_set(:@adapter, counter("")) }
    assert_equal [[detail("ItemPOTION", [ingredient("ItemORANBERRY", 4, 2)]), true], [POTION, false]], SpeakCapture.log
  end

  test "a recipe whose made item has no name to say leaves its detail unsaid, the description still said" do
    with_items({}, [:POTION]) do
      opened([[:POTION, [:ORANBERRY, 2]]]) { |scene| scene.instance_variable_set(:@adapter, counter("")) }
    end
    assert_equal [[POTION, false]], SpeakCapture.log
  end

  test "binding to a copy without the list's own redraw (pbRedrawMenu) reports nothing missing" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\AItemCraft_Scene#/)
  end

  private

  # The text of an i18n key, as the mod says it.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A detail line: head, then the ingredients' lines in the recipe's order.
  def detail(head, ingredients)
    t(:craft_detail, :head => head, :list => ingredients.join(", "))
  end

  # An ingredient's line: its name, how many there are, how many the amount needs.
  def ingredient(name, have, need)
    t(:craft_ingredient, :name => name, :have => have, :need => need)
  end

  # The detail line of an inline recipe: the made item, or its amount, and one ingredient with the 4 the adapter holds.
  def recipe(item, need, volume = 1, from = :ORANBERRY)
    head = volume > 1 ? t(:craft_amount, :name => "Item#{item}s", :n => volume) : "Item#{item}"
    detail(head, [ingredient("Item#{from}", 4, need * volume)])
  end

  # A crafting screen on stock (two inline recipes by default), opened on the first at volume as Soulstones 2 and
  # Emerald open it, the amounts drawn first; the block, if given, arranges the scene before it opens.
  def opened(stock = TWO_RECIPES, volume = 1)
    scene = ItemCraft_Scene.new
    scene.stock = stock
    yield scene if block_given?
    scene.pbStartScene
    scene.refreshNumbers(0, volume)
    scene.pbRedrawItem(0, volume)
    scene
  end

  # Runs the block with Emerald's recipe data (GameData::Recipe) holding recipes, { id => [item, yield, ingredient
  # pairs] }; it is removed after.
  def with_recipes(recipes)
    row = Struct.new(:item, :yield, :ingredients)
    data = Class.new
    data.define_singleton_method(:get) { |id| row.new(*recipes.fetch(id)) }
    GameData.const_set(:Recipe, data)
    yield
  ensure
    GameData.send(:remove_const, :Recipe) if GameData.const_defined?(:Recipe, false)
  end

  # An adapter that counts 4 of every item and names each one as name.
  def counter(name)
    ad = Object.new
    ad.define_singleton_method(:getName) { |_i| name }
    ad.define_singleton_method(:getQuantity) { |_i| 4 }
    ad
  end

  # Runs the block with the game data's items patched: the item list (GameData::Item.each) holding items, { id =>
  # flags }, each answering has_flag? as the game data does (nil flags: no flag data, so asking raises), or failing
  # when items is nil; and GameData::Item.get failing for a flag (a String, which is no item) and for the ids in
  # unknown. The stub's own methods are put back after.
  def with_items(items, unknown = [])
    data = GameData::Item
    saved = [:each, :get].map { |m| data.respond_to?(m) ? data.method(m) : nil }
    flagged = Struct.new(:id, :flags) do
      def has_flag?(flag); flags.any? { |f| f.downcase == flag.downcase }; end
    end
    get = saved[1]
    data.define_singleton_method(:each) do |&blk|
      raise IOError, "no item list" if items.nil?
      items.each { |id, flags| blk.call(flagged.new(id, flags)) }
    end
    data.define_singleton_method(:get) do |i|
      raise KeyError, "no item #{i}" if i.is_a?(String) || unknown.include?(i)
      get.call(i)
    end
    yield
  ensure
    [:each, :get].zip(saved).each do |m, s|
      s ? data.define_singleton_method(m, s) : data.singleton_class.send(:remove_method, m)
    end
  end
end
