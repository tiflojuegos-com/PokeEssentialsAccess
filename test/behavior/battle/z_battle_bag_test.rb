# Pokemon Z's battle bag (games/pokemon_z/battle_bag.rb): the pocket buttons, a pocket's items under its name and page,
# the item confirmed, and the use/don't-use confirmation: the item's description, then each box by its painted label.

# Z's battle bag (232_Objetos Batalla) as far as the reader goes: useItem? paints two captions on new overlays, moves
# the selection frame a box per polled frame, repaints the last-used button and answers whether the first box was taken.
class NewBattleBag
  PocketText = ["Medicinas", "Pokéballs", "Bayas", "Objeto Batalla"]
  Sprite = Struct.new(:bitmap, :src_rect)
  Rect = Struct.new(:x)

  def initialize(state = {})
    state.each { |k, v| instance_variable_set(k, v) }
    @sprites = { "sel" => Sprite.new(Object.new, Rect.new(0)) }
  end

  def update
    :updated
  end

  def useItem?
    @sprites["overlay2_1"] = Sprite.new(Object.new, Rect.new(0))
    @sprites["overlay2_2"] = Sprite.new(Object.new, Rect.new(0))
    (@captions || ["USAR", "NO USAR"]).each_with_index do |text, i|
      pbDrawOutlineText(@sprites["overlay2_#{i + 1}"].bitmap, 0, 186 + 72 * i, 512, 384, text, nil, nil, 1)
    end
    index = 0
    (@frames || []).each do |box|
      index = box
      @sprites["sel"].src_rect.x = 466 * (index + 2)
      PokeAccess::Frame.run_pollers
    end
    pbDrawOutlineText(Object.new, 0, 16, 356, 60, "Último objeto usado", nil, nil, 1)
    @ret = nil if index > 0
    index == 0
  end
end

# The profile's hooks bind by class name, so its file is evaluated once more over the stand-in.
verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "games", "pokemon_z", "battle_bag.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

class ZBattleBagTest < PokeAccessTest
  # The Medicinas pocket over two pages, six slots to a page: [item id, count] per slot.
  MEDICINE = [[1, 3], [25, 2], [3, 1], [4, 1], [5, 1], [6, 1], [7, 1]]

  # A data provider that gives every item the same description.
  class Descriptions
    def initialize(text); @text = text; end
    def item_description(_id); @text; end
  end

  test "entering a pocket says its name and page, then the item focused and its count" do
    update(pocket_bag)
    assert_equal [["Medicinas, #{page(1, 2)}. Pocion, 3", true]], SpeakCapture.log
  end

  test "the next item on the same page is said alone" do
    bag = pocket_bag
    update(bag)
    SpeakCapture.clear
    update(bag, :@item => 1)
    assert_equal [["Repel, 2", true]], SpeakCapture.log
  end

  test "crossing to another page says the pocket's name and the new page" do
    bag = pocket_bag
    update(bag)
    SpeakCapture.clear
    update(bag, :@item => 6)
    assert_equal [["Medicinas, #{page(2, 2)}. Item7, 1", true]], SpeakCapture.log
  end

  test "an update that leaves the same item focused says nothing" do
    bag = pocket_bag
    update(bag)
    SpeakCapture.clear
    update(bag)
    assert_nothing_spoken
  end

  test "the back button is said alone" do
    bag = pocket_bag
    update(bag)
    SpeakCapture.clear
    update(bag, :@back => true)
    assert_equal [[PokeAccess::I18n.t(:bb_back), true]], SpeakCapture.log
  end

  test "the info key describes the item focused" do
    update(pocket_bag(:@item => 1))
    assert_equal "Repel", PokeAccess::Info.info_text
  end

  test "on the back button, the info key keeps the item focused last" do
    bag = pocket_bag(:@item => 4)
    update(bag)
    update(bag, :@item => 0, :@back => true)
    assert_equal "Item5", PokeAccess::Info.info_text
  end

  test "the pocket's page is a position, said from the medium verbosity up" do
    said = vb_levels do
      SpeakCapture.clear
      update(pocket_bag)
      SpeakCapture.lines
    end
    full = "Medicinas, #{page(1, 2)}. Pocion, 3"
    assert_equal [["Medicinas. Pocion, 3"], [full], [full]], said
  end

  test "a pocket with no name is headed by its page alone" do
    [nil, ""].each do |name|
      SpeakCapture.clear
      update(pocket_bag(:@pname => name))
      assert_equal ["#{page(1, 2)}. Pocion, 3"], SpeakCapture.lines, "named #{name.inspect}"
    end
  end

  test "in brief, a pocket with no name says the item alone" do
    PokeAccess::Config.verbosity = :brief
    update(pocket_bag(:@pname => ""))
    assert_equal ["Pocion, 3"], SpeakCapture.lines
  end

  test "a pocket with no item at the cursor says nothing" do
    { "no pocket" => [nil, 0], "an empty pocket" => [[], 0],
      "a cursor past the last item" => [[[1, 3]], 1] }.each do |what, (pocket, item)|
      SpeakCapture.clear
      update(pocket_bag(:@pocket => pocket, :@item => item))
      assert_nothing_spoken what
    end
  end

  test "the pocket buttons say the game's pocket labels" do
    bag = buttons_bag
    (0..3).each { |i| update(bag, :@index => i) }
    assert_equal NewBattleBag::PocketText.map { |label| [label, true] }, SpeakCapture.log
  end

  test "the last-used button names the item last used, when there is one" do
    last = PokeAccess::I18n.t(:bb_last)
    { 1 => "#{last}, Pocion", 0 => last, nil => last }.each do |used, said|
      SpeakCapture.clear
      update(buttons_bag(:@index => 4, :@lastUsed => used))
      assert_equal [[said, true]], SpeakCapture.log, "last used #{used.inspect}"
    end
  end

  test "the sixth button is said as the back button" do
    update(buttons_bag(:@index => 5))
    assert_equal [[PokeAccess::I18n.t(:bb_back), true]], SpeakCapture.log
  end

  test "a cursor past the six buttons says nothing" do
    update(buttons_bag(:@index => 6))
    assert_nothing_spoken
  end

  test "a button the cursor stays on is said once" do
    bag = buttons_bag(:@index => 2)
    update(bag)
    SpeakCapture.clear
    update(bag)
    assert_nothing_spoken
  end

  test "back in a pocket after the buttons, its name and page are said again" do
    bag = pocket_bag
    update(bag)
    update(bag, :@selPocket => 0)
    SpeakCapture.clear
    update(bag, :@selPocket => 2)
    assert_equal [["Medicinas, #{page(1, 2)}. Pocion, 3", true]], SpeakCapture.log
  end

  test "an update keeps the game's own value" do
    assert_equal :updated, update(pocket_bag)
  end

  test "a state the reader cannot read says nothing, and the next update is read as usual" do
    bag = pocket_bag(:@item => Object.new)
    update(bag)
    assert_nothing_spoken "a cursor that is no number"
    update(bag, :@item => 0)
    assert_equal [["Medicinas, #{page(1, 2)}. Pocion, 3", true]], SpeakCapture.log
  end

  test "an item just confirmed is said by its name instead of the bag's state" do
    { 1 => "Pocion", 25 => "Repel" }.each do |ret, name|
      SpeakCapture.clear
      update(buttons_bag(:@ret => ret))
      assert_equal [[name, true]], SpeakCapture.log, "item #{ret}"
    end
  end

  test "an item confirmed is said once" do
    bag = buttons_bag(:@ret => 25)
    update(bag)
    SpeakCapture.clear
    update(bag)
    assert_nothing_spoken
  end

  test "with no item confirmed, the bag's state is said" do
    [nil, 0].each do |ret|
      SpeakCapture.clear
      update(buttons_bag(:@ret => ret, :@index => 5))
      assert_equal [[PokeAccess::I18n.t(:bb_back), true]], SpeakCapture.log, "ret #{ret.inspect}"
    end
  end

  test "the confirmation says the item's description queued, then each box its frame moves to, the first one queued" do
    with_descriptions { NewBattleBag.new(:@ret => 1, :@frames => [0, 0, 1, 0]).useItem? }
    assert_equal [["msg1", false], ["USAR", false], ["NO USAR", true], ["USAR", true]], SpeakCapture.log
  end

  test "the confirmation answers the box taken" do
    { [0] => true, [1] => false }.each do |frames, taken|
      assert_equal taken, NewBattleBag.new(:@ret => 1, :@frames => frames).useItem?, "frames #{frames.inspect}"
    end
  end

  test "an item without a description goes straight to the boxes" do
    { "none" => nil, "a blank one" => " " }.each do |what, text|
      SpeakCapture.clear
      Harness.with_provider(Descriptions.new(text)) { NewBattleBag.new(:@ret => 1, :@frames => [0]).useItem? }
      assert_equal [["USAR", false]], SpeakCapture.log, what
    end
  end

  test "a box whose caption was not caught is said by the mod's word for it" do
    NewBattleBag.new(:@ret => 1, :@captions => [], :@frames => [0, 1]).useItem?
    assert_equal [PokeAccess::I18n.t(:ura_bag_use), PokeAccess::I18n.t(:ura_bag_dont_use)], SpeakCapture.lines
  end

  test "a frame off both boxes says nothing" do
    NewBattleBag.new(:@ret => 1, :@frames => [-2, 2]).useItem?
    assert_nothing_spoken
  end

  test "once the confirmation closes, the frames say nothing" do
    NewBattleBag.new(:@ret => 1, :@frames => [1]).useItem?
    SpeakCapture.clear
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  test "a second confirmation on the same bag says its first box again, queued" do
    bag = NewBattleBag.new(:@ret => 1, :@frames => [0])
    bag.useItem?
    SpeakCapture.clear
    bag.useItem?
    assert_equal [["USAR", false]], SpeakCapture.log
  end

  private

  # The bag in the Medicinas pocket, on its first item, with state (ivar => value) over that.
  def pocket_bag(state = {})
    NewBattleBag.new({ :@selPocket => 2, :@pname => "Medicinas", :@pages => 2, :@item => 0, :@back => false,
                       :@index => 0, :@pocket => MEDICINE }.merge(state))
  end

  # The bag on its pocket buttons, the first focused, with state (ivar => value) over that.
  def buttons_bag(state = {})
    NewBattleBag.new({ :@selPocket => 0, :@index => 0 }.merge(state))
  end

  # Moves the bag to state (ivar => value), as the game's own update would, and runs its update; answers its value.
  def update(bag, state = {})
    state.each { |k, v| bag.instance_variable_set(k, v) }
    bag.update
  end

  # The page of a pocket as the header says it.
  def page(n, tot)
    PokeAccess::I18n.t(:zbb_page, :n => n, :tot => tot)
  end

  # Runs the block with the gen-6 item descriptions table the game reads them from, taken out again if it was absent.
  def with_descriptions
    made = !MessageTypes.const_defined?(:ItemDescriptions)
    MessageTypes.const_set(:ItemDescriptions, 4) if made
    yield
  ensure
    MessageTypes.send(:remove_const, :ItemDescriptions) if made && MessageTypes.const_defined?(:ItemDescriptions)
  end
end
